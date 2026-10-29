/*
 *  RPM Builder — RpmBuilderEngine: файлы проекта, история, валидация,
 *  генерация .spec, сохранение конфигурации
 */
#include "rpmbuildengine.h"
#include "engine_p.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QDateTime>
#include <QRegularExpression>
#include <QSaveFile>

// ===========================================================================
//                              ФАЙЛЫ
// ===========================================================================
static bool alreadyContains(const QVariantList &files, const QString &src)
{
    for (const QVariant &v : files)
        if (v.toMap().value(QStringLiteral("src")).toString() == src)
            return true;
    return false;
}

void RpmBuilderEngine::addFiles(const QStringList &paths)
{
    bool changed = false;
    for (const QString &raw : paths) {
        const QString p = EB::expandTilde(raw);
        if (p.isEmpty() || alreadyContains(m_files, p))
            continue;
        QVariantMap entry;
        entry.insert(QStringLiteral("src"), p);
        entry.insert(QStringLiteral("dst"), suggestDest(p));
        m_files.append(entry);
        changed = true;
    }
    if (!changed)
        return;
    emit fileListChanged();
    emit projectChanged();
    scheduleDraftSave();
}

void RpmBuilderEngine::addDirectory(const QString &path)
{
    addFiles(QStringList{path});
}

void RpmBuilderEngine::removeFile(int index)
{
    if (index < 0 || index >= m_files.size())
        return;
    m_files.removeAt(index);
    emit fileListChanged();
    emit projectChanged();
    scheduleDraftSave();
}

void RpmBuilderEngine::clearFiles()
{
    if (m_files.isEmpty())
        return;
    m_files.clear();
    emit fileListChanged();
    emit projectChanged();
    scheduleDraftSave();
}

void RpmBuilderEngine::setFileDest(int index, const QString &dest)
{
    if (index < 0 || index >= m_files.size())
        return;
    auto map = m_files.at(index).toMap();
    if (map.value(QStringLiteral("dst")).toString() == dest)
        return;
    map.insert(QStringLiteral("dst"), dest);
    m_files.replace(index, map);
    emit fileListChanged();
    emit projectChanged();
    scheduleDraftSave();
}

// ===========================================================================
//                          ПРОЕКТЫ / ИСТОРИЯ
// ===========================================================================
QString RpmBuilderEngine::projectName() const
{
    return QStringLiteral("%1-%2-%3")
        .arg(sanitizeFileName(m_name),
             m_version.isEmpty() ? QStringLiteral("1.0") : m_version,
             m_release.isEmpty() ? QStringLiteral("1") : m_release);
}

void RpmBuilderEngine::upsertRecent(const QVariantMap &snapIn)
{
    QVariantMap snap = snapIn;
    snap.insert(QStringLiteral("savedAt"),
                QDateTime::currentDateTime().toString(Qt::ISODate));

    const QString key = projectName().toLower();
    for (int i = 0; i < m_recentProjects.size(); ++i) {
        const QVariantMap r = m_recentProjects.at(i).toMap();
        if (QStringLiteral("%1-%2-%3").arg(r.value("name").toString(),
                                           r.value("version").toString(),
                                           r.value("release").toString())
                .toLower() == key) {
            // сохранить статус прошлой сборки проекта
            snap.insert(QStringLiteral("lastStatus"),
                        r.value(QStringLiteral("lastStatus")));
            snap.insert(QStringLiteral("artifacts"),
                        r.value(QStringLiteral("artifacts")));
            m_recentProjects.removeAt(i);
            break;
        }
    }
    m_recentProjects.prepend(snap);
    while (m_recentProjects.size() > 12)
        m_recentProjects.removeLast();
    emit historyChanged();
}

void RpmBuilderEngine::saveCurrentProject()
{
    upsertRecent(snapshot());
    persist();
}

void RpmBuilderEngine::loadProject(int index)
{
    if (index < 0 || index >= m_recentProjects.size())
        return;
    fillFromSnapshot(m_recentProjects.at(index).toMap(), true);
    persist();
}

void RpmBuilderEngine::deleteProject(int index)
{
    if (index < 0 || index >= m_recentProjects.size())
        return;
    m_recentProjects.removeAt(index);
    emit historyChanged();
    persist();
}

void RpmBuilderEngine::clearHistory()
{
    m_recentProjects.clear();
    emit historyChanged();
    persist();
}

void RpmBuilderEngine::resetProject()
{
    m_name.clear();     m_version   = QStringLiteral("1.0.0");
    m_license = QStringLiteral("MIT");
    m_arch    = QStringLiteral("x86_64");
    m_summary.clear();  m_description.clear();
    m_url.clear();      m_packager.clear(); m_vendor.clear();
    m_files.clear();    m_requires.clear();
    m_buildRequires.clear();  m_provides.clear();

    const QStringList secs{QStringLiteral("pre"),  QStringLiteral("post"),
                           QStringLiteral("preun"),QStringLiteral("postun")};
    for (const QString &k : secs)
        m_scripts.insert(k, QString());

    emit projectChanged();
    emit fileListChanged();
    emit depsChanged();
    for (const QString &k : secs)
        emit scriptChanged(k);
    persist();
}

// ===========================================================================
//                            СОХРАНЕНИЕ КОНФИГА
// ===========================================================================
void RpmBuilderEngine::persist()
{
    QJsonObject root;
    root.insert(QStringLiteral("darkTheme"), m_darkTheme);

    QJsonObject stats;
    stats.insert(QStringLiteral("totalBuilds"),  totalBuilds());
    stats.insert(QStringLiteral("lastSeconds"),  lastBuildSeconds());
    stats.insert(QStringLiteral("lastRpmBytes"), double(lastRpmBytes()));
    stats.insert(QStringLiteral("lastAt"),       lastBuildAt());
    stats.insert(QStringLiteral("lastOk"),       lastBuildOk());
    root.insert(QStringLiteral("stats"), stats);

    QJsonArray recent;
    for (const QVariant &v : std::as_const(m_recentProjects))
        recent.append(QJsonObject::fromVariantMap(v.toMap()));
    root.insert(QStringLiteral("recent"), recent);

    root.insert(QStringLiteral("draft"),
                QJsonObject::fromVariantMap(snapshot()));

    QDir().mkpath(QStandardPaths::writableLocation(
                      QStandardPaths::AppConfigLocation));
    // Атомарная запись: сбой питания/падение не оставит битый конфиг
    // (раньше обрыв записи означал потерю черновика при старте).
    QSaveFile f(EB::configPath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
        f.commit();
    }
}

void RpmBuilderEngine::restore()
{
    QFile f(EB::configPath());
    if (!f.exists() || !f.open(QIODevice::ReadOnly))
        return;
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject()) {
        // битый конфиг (например, после сбоя) — НЕ применяем пустоту,
        // а оставляем значения по умолчанию и не затираем файл.
        qWarning("rpm-builder: config is corrupted (%s), starting clean "
                 "without overwriting it", qPrintable(perr.errorString()));
        return;
    }
    const QJsonObject root = doc.object();

    m_darkTheme = root.value(QStringLiteral("darkTheme")).toBool(true);
    emit darkThemeChanged();

    m_stats = root.value(QStringLiteral("stats")).toObject().toVariantMap();
    emit statsChanged();

    QVariantList recents;
    const QJsonArray arr = root.value(QStringLiteral("recent")).toArray();
    for (const QJsonValue &rv : arr)
        recents.append(rv.toObject().toVariantMap());
    m_recentProjects = recents;
    emit historyChanged();

    fillFromSnapshot(root.value(QStringLiteral("draft")).toObject()
                         .toVariantMap(), true);
}

// ===========================================================================
//                     ЗАВИСИМОСТИ: мост из QML
// ===========================================================================
void RpmBuilderEngine::setDepList(const QString &which, const QStringList &list)
{
    applyDeps(which, list);
}

// ===========================================================================
//                              ВАЛИДАЦИЯ
// ===========================================================================
static void addIssue(QVariantList &out, const char *level, const char *page,
                     const QString &field, const QString &msg)
{
    QVariantMap m;
    m.insert(QStringLiteral("level"), QLatin1String(level));
    m.insert(QStringLiteral("page"),  QLatin1String(page));
    m.insert(QStringLiteral("field"), field);
    m.insert(QStringLiteral("message"), msg);
    out.append(m);
}

QVariantList RpmBuilderEngine::validationIssues()
{
    QVariantList out;
    static const QRegularExpression nameRx(
        QStringLiteral("^[a-z0-9][a-z0-9._+-]*$"));
    static const QRegularExpression verRx(
        QStringLiteral("^[0-9][A-Za-z0-9.+~]*$"));

    if (m_name.isEmpty())
        addIssue(out, "error", "meta", "name", QStringLiteral("Укажите имя пакета"));
    else if (!nameRx.match(m_name).hasMatch())
        addIssue(out, "error", "meta", "name",
                 QStringLiteral("Имя: строчные латинские буквы, цифры и «. _ + -»"));

    if (m_version.isEmpty())
        addIssue(out, "error", "meta", "version",
                 QStringLiteral("Укажите версию пакета"));
    else if (!verRx.match(m_version).hasMatch())
        addIssue(out, "error", "meta", "version",
                 QStringLiteral("Версия должна начинаться с цифры"));

    if (m_release.trimmed().isEmpty())
        addIssue(out, "error", "meta", "release", QStringLiteral("Укажите релиз"));
    if (m_license.trimmed().isEmpty())
        addIssue(out, "error", "meta", "license", QStringLiteral("Укажите лицензию"));

    if (m_summary.trimmed().isEmpty())
        addIssue(out, "error", "meta", "summary",
                 QStringLiteral("Краткое описание обязательно для RPM"));
    else if (m_summary.length() > 80)
        addIssue(out, "warn", "meta", "summary",
                 QStringLiteral("Сводка длиннее 80 символов — rpm предупредит"));

    if (m_description.trimmed().isEmpty())
        addIssue(out, "error", "meta", "description",
                 QStringLiteral("Добавьте подробное описание"));

    // при собственном %install каталог установки из списка файлов не нужен
    const QString installOverride =
        m_scripts.value(QLatin1String("install")).toString().trimmed();

    if (m_files.isEmpty()) {
        addIssue(out, "error", "files", "files",
                 QStringLiteral("Добавьте хотя бы один файл или папку"));
    } else {
        for (int i = 0; i < m_files.size(); ++i) {
            const QVariantMap f = m_files.at(i).toMap();
            const QString src = f.value(QStringLiteral("src")).toString();
            const QString dst = f.value(QStringLiteral("dst")).toString().trimmed();
            if (!QFileInfo::exists(src))
                addIssue(out, "error", "files", "files",
                         QStringLiteral("%1 — файл не найден на диске")
                             .arg(QFileInfo(src).fileName()));
            if ((dst.isEmpty() || dst == QChar(u'/')) && installOverride.isEmpty())
                addIssue(out, "error", "files", "files",
                         QStringLiteral("Задайте каталог установки для %1")
                             .arg(QFileInfo(src).fileName()));
        }
    }

    if (m_rpmbuildPath.isEmpty())
        addIssue(out, "error", "build", "rpmbuild",
                 QStringLiteral("rpmbuild не найден. Установите: dnf install rpm-build / apt install rpm"));

    return out;
}

bool RpmBuilderEngine::hasBlockingErrors()
{
    for (const QVariant &v : validationIssues())
        if (v.toMap().value(QStringLiteral("level")).toString() == QLatin1String("error"))
            return true;
    return false;
}

// ===========================================================================
//                         ГЕНЕРАТОР SPEC-ФАЙЛА
// ===========================================================================
QString RpmBuilderEngine::specText()
{
    QStringList L;
    const auto push = [&L](const QString &s) { L << s; };

    push(QStringLiteral("Name:           %1").arg(sanitizeFileName(m_name)));
    push(QStringLiteral("Version:        %1").arg(m_version.isEmpty()
                                               ? QStringLiteral("1.0") : m_version));
    push(QStringLiteral("Release:        %1%2")
             .arg(m_release.isEmpty() ? QStringLiteral("1") : m_release,
                  m_release.contains(QLatin1String("%{?dist}")) ? QString() :
                                                                  QStringLiteral("%{?dist}")));
    if (!m_summary.isEmpty())
        push(QStringLiteral("Summary:        %1").arg(m_summary));
    push(QString());

    push(QStringLiteral("License:        %1").arg(m_license));
    if (!m_url.isEmpty())
        push(QStringLiteral("URL:            %1").arg(m_url));
    if (!m_vendor.isEmpty())
        push(QStringLiteral("Vendor:         %1").arg(m_vendor));
    if (!m_packager.isEmpty())
        push(QStringLiteral("Packager:       %1").arg(m_packager));
    if (m_arch == QLatin1String("noarch"))
        push(QStringLiteral("BuildArch:      noarch"));

    int idx = 0;
    for (const QVariant &v : std::as_const(m_files)) {
        const QString src = v.toMap().value(QStringLiteral("src")).toString();
        push(QStringLiteral("Source%1:        %2")
                 .arg(idx).arg(QFileInfo(src).fileName()));
        ++idx;
    }

    if (!m_buildRequires.isEmpty()) {
        push(QString());
        for (const QString &dep : std::as_const(m_buildRequires))
            push(QStringLiteral("BuildRequires:  %1").arg(dep));
    }
    if (!m_requires.isEmpty()) {
        push(QString());
        for (const QString &dep : std::as_const(m_requires))
            push(QStringLiteral("Requires:       %1").arg(dep));
    }
    if (!m_provides.isEmpty()) {
        push(QString());
        for (const QString &prov : std::as_const(m_provides))
            push(QStringLiteral("Provides:       %1").arg(prov));
    }

    push(QString()); push(QStringLiteral("%description"));
    if (!m_description.isEmpty())
        for (const QString &line : m_description.split(u'\n'))
            push(line);
    else
        push(m_summary.isEmpty() ? QStringLiteral("(описание не задано)")
                                 : m_summary);
    push(QString());

    // --- сборка из исходников (продвинутый режим) ---
    const QString buildScript =
        m_scripts.value(QLatin1String("build")).toString().trimmed();
    const QString installScript =
        m_scripts.value(QLatin1String("install")).toString().trimmed();
    const QString filesOverride =
        m_scripts.value(QLatin1String("files")).toString().trimmed();

    if (buildScript.isEmpty() && installScript.isEmpty()) {
        push(QStringLiteral("# Простая упаковка готовых файлов без пересборки исходников"));
        push(QStringLiteral("%prep"));
        push(QString());
        push(QStringLiteral("%install"));
        push(QStringLiteral("rm -rf %{buildroot}"));
        idx = 0;
        for (const QVariant &v : std::as_const(m_files)) {
            const QVariantMap f = v.toMap();
            const QFileInfo src(f.value(QStringLiteral("src")).toString());
            QString destDir = f.value(QStringLiteral("dst")).toString().trimmed();
            if (destDir.endsWith(u'/') && destDir != QChar(u'/'))
                destDir.chop(1);
            const QString target = destDir + u'/' + src.fileName();
            push(QStringLiteral("mkdir -p %{buildroot}%1").arg(destDir));
            push(QStringLiteral("cp -r %{_sourcedir}/%1 %{buildroot}%2")
                     .arg(src.fileName(), target));
            push(QString());
            ++idx;
        }
        push(QString());
    } else {
        push(QStringLiteral("# Сборка из исходников: команды заданы на странице «Скрипты и сборка»"));
        push(QStringLiteral("# Источники добавленных файлов лежат в %{_sourcedir}"));
        push(QStringLiteral("%prep"));
        push(QString());
        if (!buildScript.isEmpty()) {
            push(QStringLiteral("%build"));
            for (const QString &ln : buildScript.split(u'\n'))
                push(ln);
            push(QString());
        }
        push(QStringLiteral("%install"));
        push(QStringLiteral("rm -rf %{buildroot}"));
        if (!installScript.isEmpty()) {
            for (const QString &ln : installScript.split(u'\n'))
                push(ln);
        } else {
            idx = 0;
            for (const QVariant &v : std::as_const(m_files)) {
                const QVariantMap f = v.toMap();
                const QFileInfo src(f.value(QStringLiteral("src")).toString());
                QString destDir = f.value(QStringLiteral("dst")).toString().trimmed();
                if (destDir.endsWith(u'/') && destDir != QChar(u'/'))
                    destDir.chop(1);
                const QString target = destDir + u'/' + src.fileName();
                push(QStringLiteral("mkdir -p %{buildroot}%1").arg(destDir));
                push(QStringLiteral("cp -r %{_sourcedir}/%1 %{buildroot}%2")
                         .arg(src.fileName(), target));
                push(QString());
                ++idx;
            }
        }
        push(QString());
    }
    push(QStringLiteral("%clean"));
    push(QStringLiteral("rm -rf %{buildroot}"));
    push(QString());

    const auto appendScript = [&](const char *tag, const char *key) {
        const QString body =
            m_scripts.value(QLatin1String(key)).toString().trimmed();
        if (body.isEmpty())
            return;
        push(QLatin1String(tag));
        for (const QString &ln : body.split(u'\n'))
            push(ln);
        push(QString());
    };
    appendScript("%pre",    "pre");
    appendScript("%post",   "post");
    appendScript("%preun",  "preun");
    appendScript("%postun", "postun");

    push(QStringLiteral("%files"));
    if (!filesOverride.isEmpty()) {
        for (const QString &ln : filesOverride.split(u'\n'))
            push(ln);
    } else {
        for (const QVariant &v : std::as_const(m_files)) {
            const QVariantMap f = v.toMap();
            const QFileInfo src(f.value(QStringLiteral("src")).toString());
            QString destDir = f.value(QStringLiteral("dst")).toString().trimmed();
            if (destDir.endsWith(u'/') && destDir != QChar(u'/'))
                destDir.chop(1);
            push(QStringLiteral("%1/%2").arg(destDir, src.fileName()));
        }
    }
    push(QString());

    push(QStringLiteral("%changelog"));
    push(QStringLiteral("* %1 RPM Builder <builder@localhost> %2-%3-%4")
             .arg(changelogDateNow(), sanitizeFileName(m_name),
                  m_version.isEmpty() ? QStringLiteral("1.0") : m_version,
                  m_release.isEmpty() ? QStringLiteral("1") : m_release));
    push(QStringLiteral("- Пакет собран в визуальном конструкторе RPM Builder."));

    return L.join(QChar(u'\n')) + QChar(u'\n');
}
#include <QUrl>
