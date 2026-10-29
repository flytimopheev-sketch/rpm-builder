/*
 *  RPM Builder — сборочный конвейер rpmbuild через QProcess
 */
#include "rpmbuildengine.h"
#include "engine_p.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QDateTime>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QDesktopServices>
#include <QRegularExpression>
#include <QUrl>

QString RpmBuilderEngine::workspaceRoot() const
{
    // Путь БЕЗ ПРОБЕЛОВ обязателен: rpm не каверяет пути в своих
    // макросах (%mkbuilddir, rpm-tmp-скрипты), и каталог вида
    // «…/RPM Builder/workspace» ломал каждую сборку на реальных
    // системах («Bad exit status from rpm-tmp», «No such file»).
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
         + QStringLiteral("/rpm-builder/workspace");
}

int RpmBuilderEngine::elapsedSec() const
{
    if (!m_building)
        return 0;
    return m_elapsedSec;
}

void RpmBuilderEngine::tickElapsed()
{
    ++m_elapsedSec;
    emit buildingChanged();
}

// ---------------------------------------------------------------------------
void RpmBuilderEngine::setOutputDir(const QString &v)
{
    const QString p = EB::expandTilde(v);
    if (p == m_outputDir)
        return;
    m_outputDir = p;
    emit outputDirChanged();
    scheduleDraftSave();
}

void RpmBuilderEngine::setDarkTheme(bool v)
{
    if (v == m_darkTheme)
        return;
    m_darkTheme = v;
    emit darkThemeChanged();
    persist();
}

void RpmBuilderEngine::openInFileManager(const QString &pathIn)
{
    QString p = EB::expandTilde(pathIn);
    QFileInfo fi(p);
    if (!fi.exists())
        return;
    if (fi.isFile())
        p = fi.absolutePath();          // открыть каталог, содержащий файл
    QDesktopServices::openUrl(QUrl::fromLocalFile(p));
}

bool RpmBuilderEngine::saveSpec(const QString &pathIn)
{
    QString p = EB::expandTilde(pathIn);
    if (p.isEmpty() || !QDir().mkpath(QFileInfo(p).absolutePath()))
        return false;
    QFile f(p);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    f.write(specText().toUtf8());
    f.close();
    return true;
}

// ---------------------------------------------------------------------------
static QStringList collectRpms(const QString &rpmsDir)
{
    QStringList found;
    QDirIterator it(rpmsDir, {QStringLiteral("*.rpm")}, QDir::Files,
                    QDirIterator::Subdirectories);
    while (it.hasNext())
        found << it.next();
    return found;
}

void RpmBuilderEngine::startBuild()
{
    if (m_building)
        return;

    // rpmbuild могли установить уже после запуска приложения —
    // перепроверяем PATH при каждой сборке
    recheckRpmbuild();

    // сброс итогов предыдущей сборки
    m_cancelRequested    = false;
    m_lastBuildCancelled = false;
    m_lastBuildErrors.clear();
    m_outputTail.clear();
    emit buildOutcomeChanged();

    // --- предстартовая валидация ------------------------------------------
    for (const QVariant &v : validationIssues()) {
        const QVariantMap issue = v.toMap();
        emit appendLog(issue.value(QStringLiteral("level")).toString() ==
                               QLatin1String("error")
                           ? QStringLiteral("✗ ОШИБКА: %1")
                                 .arg(issue.value(QStringLiteral("message")).toString())
                           : QStringLiteral("! Внимание: %1")
                                 .arg(issue.value(QStringLiteral("message")).toString()));
    }
    if (hasBlockingErrors()) {
        emit appendLog(QString());
        emit appendLog(QStringLiteral("Сборка прервана: исправьте ошибки выше."));
        emit buildFinished(false);
        return;
    }

    const QString top = workspaceRoot();
    const QString src = top + QStringLiteral("/SOURCES");
    const QString specs = top + QStringLiteral("/SPECS");
    const QString rpms = top + QStringLiteral("/RPMS");

    emit lastArtifactsChanged();

    // [1/6] окружение
    emit appendLog(QStringLiteral("── ── ── ── ── ── ── ── ── ── ── ── ──"));
    emit appendLog(QStringLiteral("[1/6] Подготовка окружения: %1").arg(top));
    for (const QLatin1String &sub : {QLatin1String("BUILD"),
                                    QLatin1String("BUILDROOT"),
                                    QLatin1String("RPMS"),   QLatin1String("SRPMS"),
                                    QLatin1String("SOURCES"), QLatin1String("SPECS"),
                                    QLatin1String("tmp")}) {
        QDir(top + u'/' + sub).removeRecursively();
        QDir().mkpath(top + u'/' + sub);
    }

    // [2/6] копирование источников
    emit appendLog(QStringLiteral("[2/6] Копирование исходных файлов…"));
    bool okAll = true;
    for (const QVariant &v : std::as_const(m_files)) {
        const QVariantMap f = v.toMap();
        const QFileInfo from(f.value(QStringLiteral("src")).toString());
        const QString to = src + u'/' + from.fileName();
        emit appendLog(QStringLiteral("      • %1").arg(from.fileName()));
        if (!copyRecursively(from.absoluteFilePath(), to))
            okAll = false;
    }
    if (!okAll) {
        emit appendLog(QStringLiteral("✗ Не удалось скопировать источники — проверьте пути."));
        emit buildFinished(false);
        return;
    }

    // [3/6] spec
    emit appendLog(QStringLiteral("[3/6] Генерация SPEC-файла"));
    const QString specBase = sanitizeFileName(m_name) + QStringLiteral(".spec");
    QFile specFile(specs + u'/' + specBase);
    if (!specFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        emit appendLog(QStringLiteral("✗ Не удалось записать %1").arg(specFile.fileName()));
        emit buildFinished(false);
        return;
    }
    specFile.write(specText().toUtf8());
    specFile.close();

    // [4/6] запуск
    m_lastArtifacts.clear();
    emit lastArtifactsChanged();
    m_elapsedSec = 0;
    m_building = true;
    emit buildingChanged();
    m_buildClock.start();
    m_elapsedTicker.start();

    QStringList args{QStringLiteral("-bb"),
                     QStringLiteral("--define"), QStringLiteral("_topdir ") + top,
                     QStringLiteral("--define"), QStringLiteral("_tmppath ") + top
                                                    + QStringLiteral("/tmp"),
                     QStringLiteral("--define"), QStringLiteral("_sourcedir ") + src,
                     QStringLiteral("--define"), QStringLiteral("_specdir ") + specs,
                     QStringLiteral("--define"), QStringLiteral("_builddir ") + top
                                                    + QStringLiteral("/BUILD"),
                     QStringLiteral("--define"), QStringLiteral("_buildrootdir ") + top
                                                    + QStringLiteral("/BUILDROOT"),
                     QStringLiteral("--define"), QStringLiteral("_rpmdir ") + rpms,
                     QStringLiteral("--define"), QStringLiteral("_srcrpmdir ") + top
                                                    + QStringLiteral("/SRPMS"),
                     QStringLiteral("--define"), QStringLiteral("_disable_source_fetch 1"),
                     specFile.fileName()};
    emit appendLog(QStringLiteral("[4/6] Запуск: rpmbuild -bb %1").arg(specBase));

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("LC_ALL"), QStringLiteral("C.UTF-8"));
    env.insert(QStringLiteral("LANG"),   QStringLiteral("C.UTF-8"));
    m_buildProc.setProcessEnvironment(env);
    // rpmbuild пишет ВСЕ ошибки в stderr — без слияния каналов пользователь
    // увидел бы только «ошибка сборки» без причины
    m_buildProc.setProcessChannelMode(QProcess::MergedChannels);
    m_buildProc.setWorkingDirectory(top);
    // ВАЖНО: абсолютный путь — rpmbuild ищет spec относительно CWD,
    // а не _specdir, и молча завершался «No such file or directory»
    m_buildProc.start(m_rpmbuildPath, args);
}

void RpmBuilderEngine::recheckRpmbuild()
{
    const QString p = QStandardPaths::findExecutable(QStringLiteral("rpmbuild"));
    if (p == m_rpmbuildPath)
        return;
    m_rpmbuildPath = p;
    emit rpmbuildPathChanged();
}

void RpmBuilderEngine::onBuildProcessError(QProcess::ProcessError err)
{
    // Crashed/CrashExit приходят вместе с finished() и обрабатываются
    // в onBuildFinished; отдельно интересен только случай, когда процесс
    // вообще не смог стартовать (finished() тогда НЕ придёт — иначе
    // индикатор крутится вечно и «Отменить» выглядит мёртвой).
    if (err != QProcess::FailedToStart)
        return;
    m_elapsedTicker.stop();
    m_building = false;
    emit buildingChanged();
    emit appendLog(QStringLiteral("✗ rpmbuild не удалось запустить%1")
                       .arg(m_rpmbuildPath.isEmpty()
                                ? QStringLiteral(" — не найден в PATH")
                                : QStringLiteral(": %1").arg(m_rpmbuildPath)));
    emit appendLog(QStringLiteral("  Установите rpm-build и соберите заново:"));
    emit appendLog(QStringLiteral(
        "    • РЕД ОС / РЕД АДМ / RHEL / CentOS:  sudo dnf install rpm-build"));
    emit appendLog(QStringLiteral(
        "    • Astra / Debian / Ubuntu:  sudo apt install rpm"));
    m_lastBuildErrors.append(
        QStringLiteral("rpmbuild не найден или не может быть запущен"));
    emit buildOutcomeChanged();
    emit buildFinished(false);
}

void RpmBuilderEngine::cancelBuild()
{
    if (!m_building)
        return;
    m_cancelRequested = true;
    emit appendLog(QStringLiteral("!! Отмена: завершаем rpmbuild…"));
    if (m_buildProc.state() == QProcess::Running)
        m_buildProc.terminate();
    // страховка: если через 2.5 с rpmbuild не завершился — SIGKILL
    QTimer::singleShot(2500, this, [this]() {
        if (m_building && m_buildProc.state() == QProcess::Running) {
            emit appendLog(QStringLiteral(
                "!! rpmbuild не отреагировал — принудительное завершение."));
            m_buildProc.kill();
        }
    });
}

void RpmBuilderEngine::captureErrorLine(const QString &line)
{
    static const QRegularExpression errRe(
        QStringLiteral("(error:|FAILED|No such file or directory|"
                       "File not found|Installed \\(but unpackaged\\\)|"
                       "cannot stat|Permission denied|Failed build dependencies|"
                       "Directory not found|File must begin with|Bad file|"
                       "не удалось|отказано в доступе|Нет такого файла|"
                       "Сборка прервана|ошибк)"),
        QRegularExpression::CaseInsensitiveOption);
    const QString t = line.trimmed();
    if (t.isEmpty() || t.length() > 300)
        return;
    if (!errRe.match(t).hasMatch())
        return;
    for (const QVariant &e : std::as_const(m_lastBuildErrors))
        if (e.toString() == t)
            return;                       // без повторов
    if (m_lastBuildErrors.size() >= 12)
        return;
    m_lastBuildErrors.append(t);
}

void RpmBuilderEngine::onBuildOutput()
{
    const QByteArray chunk = m_buildProc.readAllStandardOutput();
    const QString text = QString::fromUtf8(chunk);
    emit appendLog(text);

    // разбор построчно (хвост без перевода строки ждём продолжения)
    m_outputTail += text;
    int nl;
    while ((nl = m_outputTail.indexOf(QLatin1Char('\n'))) >= 0) {
        captureErrorLine(m_outputTail.left(nl));
        m_outputTail.remove(0, nl + 1);
    }
}

void RpmBuilderEngine::onBuildFinished(int exitCode, QProcess::ExitStatus status)
{
    m_elapsedTicker.stop();
    m_building = false;
    const double secs = m_buildClock.elapsed() / 1000.0;

    const bool exitOk = (exitCode == 0 && status == QProcess::NormalExit);
    if (!m_outputTail.isEmpty()) {          // хвост без перевода строки
        captureErrorLine(m_outputTail);
        m_outputTail.clear();
    }
    emit appendLog(secs > 0
                       ? QStringLiteral("[5/6] rpmbuild завершился за %1 с (код %2)")
                             .arg(QString::number(secs, 'f', 1),
                                  QString::number(exitCode))
                       : QStringLiteral("[5/6] rpmbuild завершён (код %1)")
                             .arg(QString::number(exitCode)));

    bool success = false;
    QList<QPair<QString, qint64>> collected;

    if (exitOk) {
        const QStringList rpmPaths =
            collectRpms(workspaceRoot() + QStringLiteral("/RPMS"));
        if (!rpmPaths.isEmpty())
            success = true;

        QDir outDir(m_outputDir);
        outDir.mkpath(QStringLiteral("."));

        for (const QString &p : rpmPaths) {
            const qint64 sz = QFileInfo(p).size();
            const QString dst = outDir.filePath(QFileInfo(p).fileName());
            QFile::remove(dst);
            QFile::copy(p, dst);
            collected.append({dst, sz});
            emit appendLog(QStringLiteral("      ✔ %1 (%2)")
                               .arg(dst, EB::humanSize(sz)));
        }
    }

    // [6/6] итог
    m_stats.insert(QStringLiteral("totalBuilds"), totalBuilds() + (success ? 1 : 0));
    m_stats.insert(QStringLiteral("lastSeconds"), secs);
    m_stats.insert(QStringLiteral("lastAt"),
                   QDateTime::currentDateTime().toString(Qt::ISODate));
    if (success) {
        qint64 sum = 0;
        for (const auto &c : collected) sum += c.second;
        m_stats.insert(QStringLiteral("lastRpmBytes"), double(sum));
        m_stats.insert(QStringLiteral("lastOk"), true);
    } else {
        m_stats.insert(QStringLiteral("lastOk"), false);
    }

    QVariantList arts;
    for (const auto &c : collected) {
        QVariantMap a;
        a.insert(QStringLiteral("path"), c.first);
        a.insert(QStringLiteral("size"), double(c.second));
        a.insert(QStringLiteral("human"), EB::humanSize(c.second));
        arts.append(a);
    }
    m_lastArtifacts = arts;
    emit lastArtifactsChanged();
    emit statsChanged();

    // история: обновить статус проекта, если он там уже есть / добавить его
    QVariantMap snap = snapshot();
    snap.insert(QStringLiteral("savedAt"),
                QDateTime::currentDateTime().toString(Qt::ISODate));
    snap.insert(QStringLiteral("lastOk"), success);
    snap.insert(QStringLiteral("artifacts"), arts);
    const QString key = projectName().toLower();
    int hit = -1;
    for (int i = 0; i < m_recentProjects.size(); ++i) {
        const QVariantMap r = m_recentProjects.at(i).toMap();
        const QString k = QStringLiteral("%1-%2-%3")
                              .arg(r.value("name").toString(),
                                   r.value("version").toString(),
                                   r.value("release").toString())
                              .toLower();
        if (k == key) { hit = i; break; }
    }
    if (hit >= 0) {
        m_recentProjects.replace(hit, snap);
        emit historyChanged();
    } else if (success) {
        upsertRecent(snap);
    }
    persist();

    emit appendLog(success
                       ? QStringLiteral("[6/6] Готово! Пакет(ы) скопированы в %1")
                             .arg(m_outputDir)
                       : QStringLiteral("[6/6] Ошибка сборки — см. разбор выше."));

    // итог по отмене: SIGKILL от нас → CrashExit; аварийный выход без
    // запроса на отмену считаем ошибкой, а не отменой
    m_lastBuildCancelled = m_cancelRequested && !success;
    emit buildOutcomeChanged();

    emit appendLog(m_lastBuildCancelled
                       ? QStringLiteral("(сборка была отменена)") : QString());
    emit buildFinished(success);
}
