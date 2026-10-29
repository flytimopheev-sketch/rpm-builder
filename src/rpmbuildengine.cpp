/*
 *  RPM Builder — RpmBuilderEngine: состояние, spec-генератор, валидация,
 *  проекты/история/статистика (сборочный конвейер — в rpmbuild.cpp)
 */
#include "rpmbuildengine.h"
#include "engine_p.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QRegularExpression>
#include <QStandardPaths>

// ---------------------------------------------------------------------------
//                              утилиты
// ---------------------------------------------------------------------------
static QString configPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
         + QStringLiteral("/config.json");
}

QString RpmBuilderEngine::sanitizeFileName(const QString &base)
{
    static const QRegularExpression bad(QStringLiteral("[^A-Za-z0-9._+-]"));
    QString s = base.simplified().replace(u' ', u'-');
    s.remove(bad);
    if (s.isEmpty()) s = QStringLiteral("package");
    return s;
}

QStringList RpmBuilderEngine::splitDepTokens(const QString &text)
{
    QStringList out;
    const QStringList parts = text.split(QRegularExpression(QStringLiteral("[,;]")),
                                         Qt::SkipEmptyParts);
    for (const QString &raw : parts) {
        const QString t = raw.trimmed();
        if (!t.isEmpty())
            out << t;
    }
    out.removeAll(QString());
    out.removeDuplicates();
    return out;
}

QString RpmBuilderEngine::changelogDateNow()
{
    const QDate d = QDateTime::currentDateTimeUtc().date();
    static const char *wd[] = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"};
    static const char *mo[] = {"","Jan","Feb","Mar","Apr","May","Jun",
                               "Jul","Aug","Sep","Oct","Nov","Dec"};
    return QStringLiteral("%1 %2 %3 %4")
        .arg(QLatin1String(wd[d.dayOfWeek() - 1]),
             QLatin1String(mo[d.month()]), QString::number(d.day()),
             QString::number(d.year()));
}

bool RpmBuilderEngine::copyRecursively(const QString &src, const QString &dst) const
{
    const QFileInfo fi(src);
    if (!fi.exists())
        return false;
    if (fi.isFile()) {
        QFile::remove(dst);
        return QDir().mkpath(QFileInfo(dst).absolutePath()) &&
               QFile::copy(src, dst);
    }
    QDir dstDir(dst);
    if (!dstDir.mkpath(QStringLiteral(".")))
        return false;
    QDirIterator it(src, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot |
                             QDir::Hidden | QDir::NoSymLinks);
    bool ok = true;
    while (it.hasNext() && ok) {
        const QString child = it.next();
        ok = copyRecursively(child, dst + u'/' + QFileInfo(child).fileName());
    }
    return ok;
}

// ---------------------------------------------------------------------------
//                        время жизни / сохранение
// ---------------------------------------------------------------------------
RpmBuilderEngine::RpmBuilderEngine(QObject *parent)
    : QObject(parent)
{
    m_scripts.insert(QStringLiteral("pre"),    QString());
    m_scripts.insert(QStringLiteral("post"),   QString());
    m_scripts.insert(QStringLiteral("preun"),  QString());
    m_scripts.insert(QStringLiteral("postun"), QString());
    m_scripts.insert(QStringLiteral("build"),  QString());
    m_scripts.insert(QStringLiteral("install"), QString());
    m_scripts.insert(QStringLiteral("files"),  QString());

    m_rpmbuildPath = QStandardPaths::findExecutable(QStringLiteral("rpmbuild"));
    m_outputDir = QDir::homePath() + QStringLiteral("/rpmbuilder-output");

    connect(&m_buildProc, &QProcess::readyReadStandardOutput,
            this, &RpmBuilderEngine::onBuildOutput);
    connect(&m_buildProc, &QProcess::finished,
            this, &RpmBuilderEngine::onBuildFinished);
    connect(&m_buildProc, &QProcess::errorOccurred,
            this, &RpmBuilderEngine::onBuildProcessError);

    m_elapsedTicker.setInterval(1000);
    connect(&m_elapsedTicker, &QTimer::timeout, this, &RpmBuilderEngine::tickElapsed);

    m_draftSaver.setSingleShot(true);
    m_draftSaver.setInterval(600);
    connect(&m_draftSaver, &QTimer::timeout, this, &RpmBuilderEngine::persist);

    restore();
}

RpmBuilderEngine::~RpmBuilderEngine()
{
    if (m_buildProc.state() != QProcess::NotRunning)
        m_buildProc.kill();
    persist();
}

void RpmBuilderEngine::scheduleDraftSave()
{
    if (!m_draftSaver.isActive())
        m_draftSaver.start();
}

QVariantMap RpmBuilderEngine::ensureStatsMap() const { return m_stats; }

// ---------------------------------------------------------------------------
//                         снапшот проекта (JSON-карта)
// ---------------------------------------------------------------------------
QVariantMap RpmBuilderEngine::snapshot() const
{
    QVariantMap s;
    s[QStringLiteral("name")]        = m_name;
    s[QStringLiteral("version")]     = m_version;
    s[QStringLiteral("release")]     = m_release;
    s[QStringLiteral("license")]     = m_license;
    s[QStringLiteral("arch")]        = m_arch;
    s[QStringLiteral("summary")]     = m_summary;
    s[QStringLiteral("description")] = m_description;
    s[QStringLiteral("url")]         = m_url;
    s[QStringLiteral("packager")]    = m_packager;
    s[QStringLiteral("vendor")]      = m_vendor;
    s[QStringLiteral("files")]       = m_files;
    s[QStringLiteral("requires")]    = m_requires;
    s[QStringLiteral("buildRequires")] = m_buildRequires;
    s[QStringLiteral("provides")]    = m_provides;
    s[QStringLiteral("scripts")]     = m_scripts;
    return s;
}

void RpmBuilderEngine::fillFromSnapshot(const QVariantMap &s, bool emitSignals)
{
    m_name        = s.value(QStringLiteral("name")).toString();
    m_version     = s.value(QStringLiteral("version"), QStringLiteral("1.0.0")).toString();
    m_release     = s.value(QStringLiteral("release"), QStringLiteral("1%{?dist}")).toString();
    m_license     = s.value(QStringLiteral("license"), QStringLiteral("MIT")).toString();
    m_arch        = s.value(QStringLiteral("arch"), QStringLiteral("x86_64")).toString();
    m_summary     = s.value(QStringLiteral("summary")).toString();
    m_description = s.value(QStringLiteral("description")).toString();
    m_url         = s.value(QStringLiteral("url")).toString();
    m_packager    = s.value(QStringLiteral("packager")).toString();
    m_vendor      = s.value(QStringLiteral("vendor")).toString();

    // ВАЖНО: заменяем список, а не дополняем — повторное открытие
    // проекта из истории раньше дублировало все файлы.
    m_files.clear();
    QVariantList files = s.value(QStringLiteral("files")).toList();
    for (const QVariant &v : files) {
        QVariantMap f = v.toMap();
        // шаблоны (*.rpmb.json) переносимы: «~/...» раскрывается на машине,
        // где шаблон загружают
        const QString src =
            EB::expandTilde(f.value(QStringLiteral("src")).toString());
        if (!src.isEmpty()) {
            f.insert(QStringLiteral("src"), src);
            m_files.append(f);
        }
    }

    m_requires = s.value(QStringLiteral("requires")).toStringList();
    m_requires.removeAll(QString()); m_requires.removeDuplicates();
    m_buildRequires = s.value(QStringLiteral("buildRequires")).toStringList();
    m_buildRequires.removeAll(QString()); m_buildRequires.removeDuplicates();
    m_provides      = s.value(QStringLiteral("provides")).toStringList();
    m_provides.removeAll(QString()); m_provides.removeDuplicates();

    const QVariantMap sc = s.value(QStringLiteral("scripts")).toMap();
    const QStringList secs{QStringLiteral("pre"), QStringLiteral("post"),
                           QStringLiteral("preun"), QStringLiteral("postun"),
                           QStringLiteral("build"), QStringLiteral("install"),
                           QStringLiteral("files")};
    for (const QString &k : secs)
        m_scripts.insert(k, sc.value(k).toString());

    if (emitSignals) {
        emit projectChanged();
        emit fileListChanged();
        emit depsChanged();
        for (const QString &k : secs)
            emit scriptChanged(k);
    }
}

// ---------------------------------------------------------------------------
//                    ввод метаданных: зависимости и скрипты
// ---------------------------------------------------------------------------
void RpmBuilderEngine::applyDeps(const QString &which, const QStringList &list)
{
    QStringList clean;
    for (const QString &t : list) {
        const QString trimmed = t.trimmed();
        if (!trimmed.isEmpty() && !clean.contains(trimmed))
            clean << trimmed;
    }
    if (which == QLatin1String("requires"))       m_requires      = clean;
    else if (which == QLatin1String("buildRequires")) m_buildRequires = clean;
    else if (which == QLatin1String("provides"))  m_provides      = clean;
    emit depsChanged();
    emit projectChanged();
    scheduleDraftSave();
}

void RpmBuilderEngine::setScript(const QString &section, const QString &body)
{
    const QString key = section.toLower();
    // пропускать только если значение НЕ ИЗМЕНИЛОСЬ (ключ может быть новым!)
    if (m_scripts.contains(key) && m_scripts.value(key).toString() == body)
        return;
    m_scripts.insert(key, body);
    emit scriptChanged(key);
    emit projectChanged();
    scheduleDraftSave();
}

// ---------------------------------------------------------------------------
//                              подсказки UI
// ---------------------------------------------------------------------------
QStringList RpmBuilderEngine::licenseSuggestions() const
{
    return {QStringLiteral("MIT"),           QStringLiteral("Apache-2.0"),
            QStringLiteral("GPL-2.0-only"),  QStringLiteral("GPL-3.0-only"),
            QStringLiteral("LGPL-2.1-only"), QStringLiteral("LGPL-3.0-only"),
            QStringLiteral("BSD-2-Clause"),  QStringLiteral("BSD-3-Clause"),
            QStringLiteral("MPL-2.0"),       QStringLiteral("Zlib"),
            QStringLiteral("Unlicense"),     QStringLiteral("Proprietary")};
}

QStringList RpmBuilderEngine::archSuggestions() const
{
    return {QStringLiteral("x86_64"), QStringLiteral("aarch64"),
            QStringLiteral("noarch"), QStringLiteral("i686"),
            QStringLiteral("armv7hl"), QStringLiteral("riscv64"),
            QStringLiteral("ppc64le"), QStringLiteral("s390x")};
}

QStringList RpmBuilderEngine::destDirSuggestions() const
{
    return {QStringLiteral("%{_bindir}"),        QStringLiteral("%{_unitdir}"),
            QStringLiteral("%{_libdir}"),        QStringLiteral("%{_libexecdir}"),
            QStringLiteral("/usr/share/applications"),
            QStringLiteral("/usr/share/icons/hicolor/scalable/apps"),
            QStringLiteral("/usr/share/icons/hicolor/48x48/apps"),
            QStringLiteral("/usr/share/doc/%{name}"),
            QStringLiteral("/etc/%{name}"),
            QStringLiteral("/usr/share/%{name}")};
}

// ---------------------------------------------------------------------------
// Встроенный выбор файлов: данные для собственного диалога (FilePicker.qml)
// ---------------------------------------------------------------------------
QVariantList RpmBuilderEngine::listDir(const QString &pathIn,
                                       bool showHidden) const
{
    QVariantList out;
    const QString path = EB::expandTilde(pathIn);
    QDir d(path);
    if (path.isEmpty() || !d.exists())
        return out;

    QDir::Filters filters = QDir::AllEntries | QDir::NoDotAndDotDot
                            | QDir::System;
    if (showHidden)
        filters |= QDir::Hidden;

    const QFileInfoList entries = d.entryInfoList(
        filters, QDir::DirsFirst | QDir::Name | QDir::LocaleAware);

    for (const QFileInfo &fi : entries) {
        QVariantMap m;
        m.insert(QStringLiteral("name"), fi.fileName());
        m.insert(QStringLiteral("isDir"), fi.isDir());
        m.insert(QStringLiteral("size"), double(fi.size()));
        m.insert(QStringLiteral("symlink"), fi.isSymLink());
        out.append(m);
    }
    return out;
}

QString RpmBuilderEngine::homeDir() const
{
    return QDir::homePath();
}

bool RpmBuilderEngine::pathExists(const QString &pathIn) const
{
    return QFileInfo::exists(EB::expandTilde(pathIn));
}

bool RpmBuilderEngine::isDirPath(const QString &pathIn) const
{
    return QFileInfo(EB::expandTilde(pathIn)).isDir();
}

QString RpmBuilderEngine::specFileName() const
{
    const QString n = m_name.trimmed();
    return n.isEmpty()
               ? QStringLiteral("package.spec")
               : sanitizeFileName(n) + QStringLiteral(".spec");
}

QString RpmBuilderEngine::suggestDest(const QString &path) const
{
    const QFileInfo fi(path);
    const QString name = fi.fileName().toLower();
    const QString ext  = fi.suffix().toLower();

    if (fi.isDir())
        return QStringLiteral("/usr/share/") + sanitizeFileName(name);

    if (ext == QLatin1String("service") || ext == QLatin1String("timer"))
        return QStringLiteral("%{_unitdir}");
    if (ext == QLatin1String("desktop"))
        return QStringLiteral("/usr/share/applications");
    if (ext == QLatin1String("svg"))
        return QStringLiteral("/usr/share/icons/hicolor/scalable/apps");
    if (ext == QLatin1String("png"))
        return QStringLiteral("/usr/share/icons/hicolor/48x48/apps");
    if (ext == QLatin1String("sh") || ext == QLatin1String("py") ||
        ext == QLatin1String("pl") || ext == QLatin1String("rb"))
        return QStringLiteral("%{_bindir}");
    if (name.startsWith(QStringLiteral("lib")) ||
        ext == QLatin1String("so") || ext == QLatin1String("so.1") ||
        ext == QLatin1String("a"))
        return QStringLiteral("%{_libdir}");
    if (ext == QLatin1String("conf") || ext == QLatin1String("cfg"))
        return QStringLiteral("/etc/");
    if (ext == QLatin1String("md") || ext == QLatin1String("txt") ||
        name.startsWith(QStringLiteral("readme")) ||
        name.startsWith(QStringLiteral("license")) ||
        name.startsWith(QStringLiteral("copying")))
        return QStringLiteral("/usr/share/doc/%{name}");
    return QStringLiteral("/usr/share/%{name}");
}
#include <QUrl>
