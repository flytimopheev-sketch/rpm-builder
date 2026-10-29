/*
 *  RPM Builder — визуальный конструктор RPM-пакетов
 *  Copyright (c) 2026
 *  Лицензия: MIT
 *
 *  RpmBuilderEngine — центральный C++ объект, доступный из QML как `Engine`.
 *  Хранит состояние проекта, генерирует .spec, валидирует форму,
 *  запускает rpmbuild через QProcess и ведёт историю сборок.
 */
#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QElapsedTimer>
#include <QCoreApplication>

class RpmBuilderEngine : public QObject
{
    Q_OBJECT

public:
    /// Версия приложения (окно «О программе», шаблоны проектов)
    static QString appVersion() { return QCoreApplication::applicationVersion(); }

    // --- метаданные пакета -------------------------------------------------
    Q_PROPERTY(QString appVersion  READ appVersion   CONSTANT)
    Q_PROPERTY(QString name        READ name        WRITE setName        NOTIFY projectChanged)
    Q_PROPERTY(QString version     READ version     WRITE setVersion     NOTIFY projectChanged)
    Q_PROPERTY(QString release     READ release     WRITE setRelease     NOTIFY projectChanged)
    Q_PROPERTY(QString license     READ license     WRITE setLicense     NOTIFY projectChanged)
    Q_PROPERTY(QString arch        READ arch        WRITE setArch        NOTIFY projectChanged)
    Q_PROPERTY(QString summary     READ summary     WRITE setSummary     NOTIFY projectChanged)
    Q_PROPERTY(QString description READ description WRITE setDescription NOTIFY projectChanged)
    Q_PROPERTY(QString url         READ url         WRITE setUrl         NOTIFY projectChanged)
    Q_PROPERTY(QString packager    READ packager    WRITE setPackager    NOTIFY projectChanged)
    Q_PROPERTY(QString vendor      READ vendor      WRITE setVendor      NOTIFY projectChanged)

    // --- производимые данные ----------------------------------------------
    Q_PROPERTY(QString specText READ specText NOTIFY projectChanged)
    Q_PROPERTY(QVariantList fileList READ files NOTIFY fileListChanged)
    Q_PROPERTY(QVariantList validationIssues READ validationIssues NOTIFY projectChanged)
    Q_PROPERTY(bool hasBlockingErrors READ hasBlockingErrors NOTIFY projectChanged)

    // --- сборка --------------------------------------------------------------
    Q_PROPERTY(bool   building       READ building       NOTIFY buildingChanged)
    Q_PROPERTY(int    elapsedSec     READ elapsedSec     NOTIFY buildingChanged)
    Q_PROPERTY(QString outputDir     READ outputDir     WRITE setOutputDir   NOTIFY outputDirChanged)
    Q_PROPERTY(QString rpmbuildPath  READ rpmbuildPath  NOTIFY rpmbuildPathChanged)
    Q_PROPERTY(QVariantList lastArtifacts READ lastArtifacts NOTIFY lastArtifactsChanged)
    // строки с ошибками, выуженные из журнала последней сборки
    Q_PROPERTY(QVariantList lastBuildErrors READ lastBuildErrors NOTIFY buildOutcomeChanged)
    Q_PROPERTY(bool lastBuildCancelled READ lastBuildCancelled NOTIFY buildOutcomeChanged)

    // --- история / статистика ------------------------------------------------
    Q_PROPERTY(QVariantList recentProjects  READ recentProjects  NOTIFY historyChanged)
    Q_PROPERTY(int        totalBuilds       READ totalBuilds     NOTIFY statsChanged)
    Q_PROPERTY(double     lastBuildSeconds  READ lastBuildSeconds NOTIFY statsChanged)
    Q_PROPERTY(qint64     lastRpmBytes      READ lastRpmBytes    NOTIFY statsChanged)
    Q_PROPERTY(QString    lastBuildAt       READ lastBuildAt     NOTIFY statsChanged)
    Q_PROPERTY(bool       lastBuildOk       READ lastBuildOk     NOTIFY statsChanged)

    // --- оформление ------------------------------------------------------------
    Q_PROPERTY(bool darkTheme READ darkTheme WRITE setDarkTheme NOTIFY darkThemeChanged)

public:
    explicit RpmBuilderEngine(QObject *parent = nullptr);
    ~RpmBuilderEngine() override;

    // ---- getters ----
    QString name() const        { return m_name; }
    QString version() const     { return m_version; }
    QString release() const     { return m_release; }
    QString license() const     { return m_license; }
    QString arch() const        { return m_arch; }
    QString summary() const     { return m_summary; }
    QString description() const { return m_description; }
    QString url() const         { return m_url; }
    QString packager() const    { return m_packager; }
    QString vendor() const      { return m_vendor; }

    bool     building() const { return m_building; }
    int      elapsedSec() const;
    QString  outputDir() const { return m_outputDir; }
    QString  rpmbuildPath() const { return m_rpmbuildPath; }
    QVariantList lastArtifacts() const { return m_lastArtifacts; }

    QVariantList lastBuildErrors() const { return m_lastBuildErrors; }
    bool         lastBuildCancelled() const { return m_lastBuildCancelled; }

    QVariantList recentProjects() const { return m_recentProjects; }
    int          totalBuilds() const      { return m_stats.value(QStringLiteral("totalBuilds"), 0).toInt(); }
    double       lastBuildSeconds() const { return m_stats.value(QStringLiteral("lastSeconds"), 0.0).toDouble(); }
    qint64       lastRpmBytes() const     { return static_cast<qint64>(m_stats.value(QStringLiteral("lastRpmBytes")).toLongLong()); }
    QString      lastBuildAt() const      { return m_stats.value(QStringLiteral("lastAt")).toString(); }
    bool         lastBuildOk() const      { return m_stats.value(QStringLiteral("lastOk"), false).toBool(); }

    bool darkTheme() const { return m_darkTheme; }

    // ---- генерация и валидация ----
    Q_INVOKABLE QString specText();
    Q_INVOKABLE QVariantList validationIssues();
    Q_INVOKABLE bool hasBlockingErrors();

    // ---- файлы проекта ----
    Q_INVOKABLE void addFiles(const QStringList &paths);
    Q_INVOKABLE void addDirectory(const QString &path);
    Q_INVOKABLE void removeFile(int index);
    Q_INVOKABLE void clearFiles();
    Q_INVOKABLE void setFileDest(int index, const QString &dest);
    Q_INVOKABLE QString suggestDest(const QString &path) const;
    Q_INVOKABLE QVariantList files() const { return m_files; }

    // ---- зависимости ----
    Q_INVOKABLE QStringList requiresList() const { return m_requires; }
    Q_INVOKABLE QStringList buildRequiresList() const { return m_buildRequires; }
    Q_INVOKABLE QStringList providesList() const { return m_provides; }
    Q_INVOKABLE void setDepList(const QString &which, const QStringList &list);

    // ---- скрипты ----
    Q_INVOKABLE QString script(const QString &section) const
        { return m_scripts.value(section.toLower()).toString(); }
    Q_INVOKABLE void setScript(const QString &section, const QString &body);

    // ---- проекты / история ----
    Q_INVOKABLE void loadProject(int index);            // из истории
    Q_INVOKABLE void resetProject();                    // чистый лист
    Q_INVOKABLE void saveCurrentProject();              // текущее состояние -> история
    Q_INVOKABLE void deleteProject(int index);
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE QString projectName() const;            // "name-version-release"

    // ---- JSON-шаблоны проектов (*.rpmb.json) ----
    // Принимают как обычный путь, так и file://-URL из QML FileDialog.
    Q_INVOKABLE bool saveProjectToFile(const QVariant &path);
    Q_INVOKABLE bool loadProjectFromFile(const QVariant &path);
    Q_INVOKABLE QString lastProjectError() const { return m_lastProjectError; }

    // ---- сборка ----
    Q_INVOKABLE void startBuild();
    Q_INVOKABLE void cancelBuild();
    Q_INVOKABLE void recheckRpmbuild();   // перепроверить наличие rpmbuild в PATH
    Q_INVOKABLE void openInFileManager(const QString &path);
    Q_INVOKABLE bool saveSpec(const QString &path);

    // подсказки для интерфейса
    Q_INVOKABLE QStringList licenseSuggestions() const;
    Q_INVOKABLE QStringList archSuggestions() const;
    Q_INVOKABLE QStringList destDirSuggestions() const;

    // ---- файловая система для встроенного выбора файлов ----
    // (собственные диалоги вместо системных — работают в любой среде,
    // включая Wayland/порталы, где системные диалоги могут не открываться)
    Q_INVOKABLE QVariantList listDir(const QString &path, bool showHidden = false) const;
    Q_INVOKABLE QString homeDir() const;
    Q_INVOKABLE bool    pathExists(const QString &path) const;
    Q_INVOKABLE bool    isDirPath(const QString &path) const;
    Q_INVOKABLE QString specFileName() const;   // "<имя>.spec" текущего проекта

signals:
    void projectChanged();
    void fileListChanged();
    void depsChanged();
    void scriptChanged(const QString &section);
    void historyChanged();
    void statsChanged();
    void outputDirChanged();
    void darkThemeChanged();
    void buildingChanged();
    void lastArtifactsChanged();
    void buildOutcomeChanged();
    void rpmbuildPathChanged();
    void appendLog(const QString &line);
    void buildFinished(bool ok);
    void projectIoDone(bool ok, const QString &message);

private slots:
    void onBuildOutput();
    void onBuildFinished(int exitCode, QProcess::ExitStatus status);
    void onBuildProcessError(QProcess::ProcessError err);
    void tickElapsed();

private:
    // внутренние сеттеры (публичные сгенерированы moc по PROPERTY WRITE)
public:
    void setName(const QString &v)        { if (m_name == v) return; m_name = v; emit projectChanged(); scheduleDraftSave(); }
    void setVersion(const QString &v)     { if (m_version == v) return; m_version = v; emit projectChanged(); scheduleDraftSave(); }
    void setRelease(const QString &v)     { if (m_release == v) return; m_release = v; emit projectChanged(); scheduleDraftSave(); }
    void setLicense(const QString &v)     { if (m_license == v) return; m_license = v; emit projectChanged(); scheduleDraftSave(); }
    void setArch(const QString &v)        { if (m_arch == v) return; m_arch = v; emit projectChanged(); scheduleDraftSave(); }
    void setSummary(const QString &v)     { if (m_summary == v) return; m_summary = v; emit projectChanged(); scheduleDraftSave(); }
    void setDescription(const QString &v) { if (m_description == v) return; m_description = v; emit projectChanged(); scheduleDraftSave(); }
    void setUrl(const QString &v)         { if (m_url == v) return; m_url = v; emit projectChanged(); scheduleDraftSave(); }
    void setPackager(const QString &v)    { if (m_packager == v) return; m_packager = v; emit projectChanged(); scheduleDraftSave(); }
    void setVendor(const QString &v)      { if (m_vendor == v) return; m_vendor = v; emit projectChanged(); scheduleDraftSave(); }
    void setDarkTheme(bool v);
    void setOutputDir(const QString &v);

private:
    // утилиты внутренней кухни
    void applyDeps(const QString &which, const QStringList &list);
    void persist();
    void restore();
    QVariantMap snapshot() const;
    void fillFromSnapshot(const QVariantMap &snap, bool emitSignals);
    QVariantMap ensureStatsMap() const;
    void scheduleDraftSave();
    void upsertRecent(const QVariantMap &snap);
    QString workspaceRoot() const;
    bool copyRecursively(const QString &src, const QString &dst) const;
    void captureErrorLine(const QString &line);
    static QStringList splitDepTokens(const QString &text);
    static QString sanitizeFileName(const QString &base);
    static QString changelogDateNow();

private:
    // метаданные
    QString m_name, m_version = QStringLiteral("1.0.0"),
            m_release = QStringLiteral("1%{?dist}"),
            m_license = QStringLiteral("MIT"),
            m_arch    = QStringLiteral("x86_64"),
            m_summary, m_description, m_url,
            m_packager, m_vendor;

    QVariantList m_files;            // [{src,dst}]
    QStringList  m_requires, m_buildRequires, m_provides;
    QVariantMap  m_scripts;          // pre/post/preun/postun -> body

    bool     m_darkTheme = true;
    bool     m_building  = false;
    int      m_elapsedSec = 0;

    QString       m_outputDir;
    QString       m_rpmbuildPath;
    QVariantList  m_lastArtifacts;
    QVariantList  m_recentProjects;
    QVariantMap   m_stats;
    QString       m_lastProjectError;

    QVariantList  m_lastBuildErrors;     // строки ошибок последней сборки
    bool          m_lastBuildCancelled = false;
    bool          m_cancelRequested  = false;
    QString       m_outputTail;         // незавершённая строка вывода rpmbuild

    QProcess      m_buildProc;
    QElapsedTimer m_buildClock;
    QTimer        m_elapsedTicker;
    QTimer        m_draftSaver;
};
