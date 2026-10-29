/*
 *  RPM Builder — JSON-шаблоны проектов (*.rpmb.json)
 *
 *  Полное состояние проекта (метаданные, файлы, зависимости, скрипты)
 *  сериализуется в переносимый JSON-файл. Формат:
 *
 *      {
 *        "magic":         "rpm-builder-project",
 *        "formatVersion": 1,
 *        "application":   "RPM Builder",
 *        "appVersion":    "1.2.0",
 *        "savedAt":       "2026-09-01T12:00:00",
 *        "project":       { ...тот же словарь, что snapshot()... }
 *      }
 *
 *  Шаблон можно перенести на другую машину: при загрузке пути к файлам
 *  проверяются валидатором, отсутствующие легко заменить перетаскиванием.
 */
#include "rpmbuildengine.h"
#include "engine_p.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QUrl>

static const char *kMagic         = "rpm-builder-project";
static const int   kFormatVersion = 1;

// Путь из QML: принимаем file://-URL (FileDialog), обычный путь и ~/...
static QString resolveProjectPath(const QVariant &pathIn, QString *err)
{
    const QString raw = pathIn.toString();
    QString p = raw;
    if (raw.startsWith(QStringLiteral("file:")))
        p = QUrl(raw).toLocalFile();
    p = EB::expandTilde(p.trimmed());
    if (p.isEmpty()) {
        if (err)
            *err = QStringLiteral("Не указан путь к файлу шаблона.");
        return QString();
    }
    return p;
}

bool RpmBuilderEngine::saveProjectToFile(const QVariant &pathIn)
{
    m_lastProjectError.clear();

    QString err;
    const QString base = resolveProjectPath(pathIn, &err);
    if (base.isEmpty()) {
        m_lastProjectError = err;
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    QString path = base;
    if (!path.endsWith(QStringLiteral(".rpmb.json"), Qt::CaseInsensitive))
        path += QStringLiteral(".rpmb.json");

    QJsonObject root;
    root.insert(QStringLiteral("magic"),         QLatin1String(kMagic));
    root.insert(QStringLiteral("formatVersion"), kFormatVersion);
    root.insert(QStringLiteral("application"),   QStringLiteral("RPM Builder"));
    root.insert(QStringLiteral("appVersion"),    RpmBuilderEngine::appVersion());
    root.insert(QStringLiteral("savedAt"),
                QDateTime::currentDateTime().toString(Qt::ISODate));
    root.insert(QStringLiteral("project"),
                QJsonObject::fromVariantMap(snapshot()));

    const QFileInfo fi(path);
    if (!QDir().mkpath(fi.absolutePath())) {
        m_lastProjectError =
            QStringLiteral("Не удалось создать каталог: %1").arg(fi.absolutePath());
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        m_lastProjectError =
            QStringLiteral("Не удалось открыть файл на запись: %1").arg(path);
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }
    const QByteArray payload =
        QJsonDocument(root).toJson(QJsonDocument::Indented);
    const bool ok = (f.write(payload) == payload.size());
    f.close();

    if (!ok) {
        m_lastProjectError =
            QStringLiteral("Файл записан не полностью: %1").arg(path);
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    emit projectIoDone(true, QStringLiteral("Шаблон сохранён: %1").arg(fi.fileName()));
    return true;
}

bool RpmBuilderEngine::loadProjectFromFile(const QVariant &pathIn)
{
    m_lastProjectError.clear();

    QString err;
    const QString path = resolveProjectPath(pathIn, &err);
    if (path.isEmpty()) {
        m_lastProjectError = err;
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        m_lastProjectError =
            QStringLiteral("Не удалось открыть файл: %1").arg(path);
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    QJsonParseError parseError{};
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &parseError);
    f.close();

    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        m_lastProjectError = QStringLiteral("Не удалось разобрать JSON (%1): %2")
                                 .arg(QFileInfo(path).fileName(),
                                      parseError.errorString());
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    const QJsonObject root = doc.object();
    if (root.value(QStringLiteral("magic")).toString()
            != QLatin1String(kMagic)) {
        m_lastProjectError = QStringLiteral("Это не шаблон RPM Builder "
                                            "(*.rpmb.json): %1")
                                 .arg(QFileInfo(path).fileName());
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    QJsonObject project = root.value(QStringLiteral("project")).toObject();
    if (project.isEmpty()) {
        m_lastProjectError = QStringLiteral("В шаблоне нет данных проекта: %1")
                                 .arg(QFileInfo(path).fileName());
        emit projectIoDone(false, m_lastProjectError);
        return false;
    }

    // Переносимость шаблонов (важно для примеров из docs/examples):
    // файл из шаблона может лежать прямо рядом с самим *.rpmb.json.
    // Если путь из шаблона на диске не найден, но файл-тёзка есть в папке
    // шаблона — подставляем его автоматически, чтобы примеры собирались
    // сразу после открытия, без ручного копирования в домашний каталог.
    QStringList fixedSiblings;
    const QString templateDir = QFileInfo(path).absolutePath();
    QJsonArray filesArr = project.value(QLatin1String("files")).toArray();
    for (int i = 0; i < filesArr.size(); ++i) {
        QJsonObject f = filesArr.at(i).toObject();
        const QString src =
            EB::expandTilde(f.value(QLatin1String("src")).toString());
        if (src.isEmpty() || QFileInfo::exists(src))
            continue;
        const QFileInfo candidate(templateDir, QFileInfo(src).fileName());
        if (candidate.exists()) {
            f.insert(QLatin1String("src"), candidate.absoluteFilePath());
            filesArr.replace(i, f);
            fixedSiblings << QFileInfo(src).fileName();
        }
    }
    if (!fixedSiblings.isEmpty())
        project.insert(QLatin1String("files"), filesArr);

    // чистый лист -> заполнение из шаблона -> сохранение в черновик
    resetProject();
    fillFromSnapshot(project.toVariantMap(), true);
    persist();

    const QString msg = fixedSiblings.isEmpty()
        ? QStringLiteral("Проект загружен: %1").arg(projectName())
        : QStringLiteral("Проект загружен: %1 (файлы взяты из папки шаблона: %2)")
              .arg(projectName(), fixedSiblings.join(QLatin1String(", ")));
    emit projectIoDone(true, msg);
    return true;
}
