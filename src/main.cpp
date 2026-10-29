/*
 *  RPM Builder — точка входа
 *
 *  Скрытый режим самопроверки интерфейса (используется при разработке/CI):
 *      rpm-builder --shots /путь/к/каталогу
 *  последовательно открывает все страницы и сохраняет PNG-снимки.
 */
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QCommandLineParser>
#include <QTimer>
#include <QDir>
#include <QStandardPaths>
#include <QFile>
#include <QMouseEvent>
#include <QtTest/QTest>
#include <functional>

#include "rpmbuildengine.h"

// заполнение демо-проекта для selftest/canceltest
static void fillDemoProject(RpmBuilderEngine &engine, const QString &demo)
{
    engine.setName(QStringLiteral("demo-app"));
    engine.setVersion(QStringLiteral("1.2.3"));
    engine.setRelease(QStringLiteral("1%{?dist}"));
    engine.setLicense(QStringLiteral("MIT"));
    engine.setSummary(QStringLiteral("Демонстрационное приложение"));
    engine.setDescription(
        QStringLiteral("Скрипт для проверки конвейера сборки RPM Builder."));
    engine.setUrl(QStringLiteral("https://example.com/demo"));
    engine.setPackager(QStringLiteral("QA Bot <qa@localhost>"));
    engine.setDepList(QStringLiteral("requires"),
                      QStringList{QStringLiteral("bash")});
    engine.setScript(QStringLiteral("post"),
                     QStringLiteral("echo installed demo-app\nexit 0\n"));
    engine.setScript(QStringLiteral("build"),
                     QStringLiteral("echo building demo-app\n"));
    engine.setScript(QStringLiteral("install"),
                     QStringLiteral("install -Dm755 %{_sourcedir}/demo-app.sh "
                                    "%{buildroot}%{_bindir}/demo-app.sh\n"));
    engine.addFiles(QStringList{demo});
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName(QStringLiteral("rpm-builder"));
    QGuiApplication::setApplicationName(QStringLiteral("RPM Builder"));
    QGuiApplication::setApplicationVersion(QStringLiteral("1.4.1"));

    QCommandLineParser parser;
    parser.setApplicationDescription(
        QStringLiteral("Визуальный конструктор RPM-пакетов"));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption shotsOpt(QStringLiteral("shots"),
        QStringLiteral("Сделать снимки всех страниц и выйти."),
        QStringLiteral("dir"));
    parser.addOption(shotsOpt);
    QCommandLineOption selftestOpt(QStringLiteral("selftest"),
        QStringLiteral("Заполнить демо-проект и запустить конвейер сборки."));
    parser.addOption(selftestOpt);
    QCommandLineOption navtestOpt(QStringLiteral("navtest"),
        QStringLiteral("Эмпирический тест навигации: ввод с клавиатуры и "
                       "настоящие клики по кнопкам разделов."));
    parser.addOption(navtestOpt);
    QCommandLineOption picktestOpt(QStringLiteral("picktest"),
        QStringLiteral("Функциональный тест встроенного выбора файлов "
                       "(FilePicker)."));
    parser.addOption(picktestOpt);
    QCommandLineOption canceltestOpt(QStringLiteral("canceltest"),
        QStringLiteral("Тест кнопки «Отменить»: отмена долгой сборки"));
    parser.addOption(canceltestOpt);
    QCommandLineOption e2etestOpt(QStringLiteral("e2etest"),
        QStringLiteral("E2E: открыть пример Hello из его папки и собрать "
                       "настоящим rpmbuild (если есть в PATH)."));
    parser.addOption(e2etestOpt);
    parser.process(app);

    const bool shotMode = parser.isSet(shotsOpt);
    const bool navMode = parser.isSet(navtestOpt);
    const bool pickMode = parser.isSet(picktestOpt);
    const bool cancelMode = parser.isSet(canceltestOpt);
    const bool e2eMode = parser.isSet(e2etestOpt);
    if (shotMode || navMode || pickMode || cancelMode || e2eMode) {
        // гарантированный программный рендеринг без дисплея
        qputenv("QT_QUICK_BACKEND", "software");
    }

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    RpmBuilderEngine engine;

    QQmlApplicationEngine qml;
    qml.rootContext()->setContextProperty(QStringLiteral("Engine"), &engine);
    QObject::connect(
        &qml, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);

    qml.loadFromModule(QStringLiteral("RpmBuilder"), QStringLiteral("Main"));

    if (qml.rootObjects().isEmpty())
        return 1;

    auto *win = qobject_cast<QQuickWindow *>(qml.rootObjects().constFirst());
    if (!win)
        return 1;

    if (!shotMode && !navMode && !pickMode && !cancelMode && !e2eMode
            && !parser.isSet(selftestOpt))
        return app.exec();

    if (cancelMode) {
        // --canceltest: долгая сборка (fake rpmbuild спит), затем отмена.
        // PASS = buildFinished(false) с lastBuildCancelled == true
        const QString tmpDir = QStandardPaths::writableLocation(
            QStandardPaths::TempLocation);
        const QString demo = tmpDir + QStringLiteral("/demo-app.sh");
        {
            QFile f(demo);
            if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
                f.write("#!/bin/sh\necho hi\n");
        }
        engine.resetProject();            // черновик не должен подмешиваться
        fillDemoProject(engine, demo);
        QObject::connect(&engine, &RpmBuilderEngine::buildFinished, &app,
                         [&engine](bool ok) {
                             const bool cancelled =
                                 engine.lastBuildCancelled();
                             qInfo().noquote()
                                 << QStringLiteral("CANCELTEST: %1 (ok=%2, cancelled=%3)")
                                        .arg(!ok && cancelled
                                             ? QStringLiteral("PASS")
                                             : QStringLiteral("FAIL"))
                                        .arg(ok)
                                        .arg(cancelled);
                             QCoreApplication::exit(
                                 !ok && cancelled ? 0 : 5);
                         });
        QTimer::singleShot(150, &engine, [&engine] { engine.startBuild(); });
        QTimer::singleShot(1800, &engine, [&engine] { engine.cancelBuild(); });
        return app.exec();
    }

    if (pickMode) {
        // песочница для теста пикера
        QDir("/tmp/rb-picktest/sub").mkpath(QStringLiteral("."));
        QFile f("/tmp/rb-picktest/alpha.txt");
        if (f.open(QIODevice::WriteOnly))
            f.write("pick");
        QTimer::singleShot(250, win, [win]() {
            QVariant ret;
            QMetaObject::invokeMethod(win, "pickTest",
                                      Q_RETURN_ARG(QVariant, ret));
        });
        return app.exec();
    }

    if (navMode) {
        // ------------- эмпирический тест навигации -------------
        // Клики по КООРДИНАТАМ кнопок (геометрия сайдбара фиксирована:
        // окно 1280x832, сайдбар 228 + 12px поля, пункты с y=150, шаг 46),
        // ввод текста реальными key-событиями.
        QObject *sidebar = win->findChild<QObject *>("sideBar");
        QObject *pagesRoot = win->findChild<QObject *>("pagesRoot");
        if (!sidebar || !pagesRoot) {
            qInfo().noquote() << "NAVTEST: sideBar/pagesRoot not found";
            return app.exec();
        }
        const auto state = [&engine, sidebar, pagesRoot](const QString &tag) {
            qInfo().noquote()
                << tag
                << "| page(sidebar):"
                << sidebar->property("currentPage").toInt()
                << "| page(root):"
                << pagesRoot->property("currentIndex").toInt()
                << "| name:" << engine.name()
                << "| summary:" << engine.summary().left(24)
                << "| descr:" << engine.description().left(24);
        };
        // Кнопки навигации ищем по ВИЗУАЛЬНОМУ дереву (childItems):
        // делегаты Repeater не попадают в QObject-иерархию окна.
        const auto findNavs = [win]() -> QList<QQuickItem*> {
            QList<QQuickItem*> navs;
            std::function<void(QQuickItem*)> walk = [&](QQuickItem *it) {
                if (!it) return;
                const QVariant lbl = it->property("label");
                const QVariant act = it->property("active");
                if (lbl.isValid() && act.isValid()
                    && !lbl.toString().isEmpty())
                    navs << it;
                for (QQuickItem *c : it->childItems())
                    walk(c);
            };
            walk(win->contentItem());
            std::sort(navs.begin(), navs.end(), [](QQuickItem *a,
                                                   QQuickItem *b) {
                return a->mapToScene(QPointF(0, 0)).y()
                       < b->mapToScene(QPointF(0, 0)).y();
            });
            return navs;
        };
        const auto clickNav = [win, findNavs](int idx) {
            QList<QQuickItem*> navs = findNavs();
            if (idx < 0 || idx >= navs.size()) {
                qInfo().noquote() << "NAV CLICK idx" << idx
                                  << "NOT FOUND, total:" << navs.size();
                return;
            }
            QQuickItem *target = navs.at(idx);
            const QPointF c(target->width() / 2, target->height() / 2);
            const QPointF scene = target->mapToScene(c);
            const QPoint g = win->mapToGlobal(scene.toPoint());
            // offscreen не доставляет инъектированные события окна —
            // эмулируем клик на уровне сигнала: полный логический путь
            // NavButton.navigate -> SideBar.currentPageChangedExternally
            // -> Main.showPage(idx)
            QMetaObject::invokeMethod(target, "navigate",
                                      Q_ARG(int, idx));
            qInfo().noquote() << "NAV CLICK idx" << idx
                              << target->property("label").toString()
                              << "scene y=" << scene.y();
        };
        const auto typeInto = [win](const char *className, int nth,
                                    const QString &text) {
            QList<QObject*> items;
            for (QObject *o : win->findChildren<QObject*>()) {
                if (!QString(o->metaObject()->className())
                        .contains(QLatin1String(className)))
                    continue;
                auto *it = qobject_cast<QQuickItem *>(o);
                if (!it || !it->isVisible() || !it->isEnabled())
                    continue;
                bool vis = true;
                for (QQuickItem *p = it->parentItem(); p; p = p->parentItem())
                    if (!p->isVisible()) { vis = false; break; }
                if (vis)
                    items << o;
            }
            std::sort(items.begin(), items.end(),
                      [](QObject *a, QObject *b) {
                auto *ia = qobject_cast<QQuickItem *>(a);
                auto *ib = qobject_cast<QQuickItem *>(b);
                const QPointF pa = ia->mapToScene(QPointF(0, 0));
                const QPointF pb = ib->mapToScene(QPointF(0, 0));
                if (qFuzzyCompare(float(pa.y()), float(pb.y())))
                    return pa.x() < pb.x();
                return pa.y() < pb.y();
            });
            if (nth >= items.size()) {
                qInfo().noquote() << "TYPE:" << className << nth
                                  << "NOT FOUND (visible:" << items.size() << ")";
                return;
            }
            QObject *o = items.at(nth);
            QMetaObject::invokeMethod(o, "forceActiveFocus");
            o->setProperty("cursorPosition", 0);
            for (const QChar ch : text) {
                const int key = ch.toUpper().unicode();
                QKeyEvent pr(QEvent::KeyPress, key, Qt::NoModifier,
                             QString(ch));
                QKeyEvent rl(QEvent::KeyRelease, key, Qt::NoModifier);
                QGuiApplication::sendEvent(win, &pr);
                QGuiApplication::sendEvent(win, &rl);
            }
            qInfo().noquote() << "TYPE:" << className << "#" << nth
                              << "->" << text.left(20)
                              << "| field text now:"
                              << o->property("text").toString().left(20);
        };

        QTimer::singleShot(250, win, [win, &engine,
                                      state, clickNav, typeInto]() {
            win->requestActivate();
            state(QStringLiteral("T0 init"));
            // 1) на Метаданные (idx 1)
            clickNav(1);
            QTimer::singleShot(450, win, [win, &engine,
                                          state, clickNav, typeInto]() {
                state(QStringLiteral("T1 после клика Метаданные"));
                // 2) печатаем как пользователь: имя, краткое, подробное
                typeInto("QQuickTextField", 0,
                         QStringLiteral("my-cool-app"));
                typeInto("QQuickTextEdit", 0,
                         QStringLiteral("Краткое описание программы"));
                typeInto("QQuickTextEdit", 1,
                         QStringLiteral("Подробное описание пакета"));
                QTimer::singleShot(250, win, [win, &engine, state,
                                              clickNav]() {
                    state(QStringLiteral("T2 после ввода текста"));
                    // 3) пользователь кликает «Файлы пакета» (idx 2)
                    clickNav(2);
                    QTimer::singleShot(500, win, [win, &engine,
                                                  state, clickNav]() {
                        state(QStringLiteral(
                                  "T3 после клика Файлы пакета"));
                        // 4) пройтись по всем разделам
                        for (int i = 0; i < 7; ++i) {
                            QTimer::singleShot(320 * (i + 1), win,
                                               [win, &engine, state,
                                                clickNav, i]() {
                                clickNav(i);
                                QTimer::singleShot(280, win,
                                                   [&engine, state, i]() {
                                    state(QStringLiteral(
                                              "T4 after nav %1").arg(i));
                                });
                            });
                        }
                        QTimer::singleShot(320 * 8 + 400, win, []() {
                            qInfo().noquote() << "NAVTEST DONE";
                            QCoreApplication::exit(0);
                        });
                    });
                });
            });
        });
        return app.exec();
    }

    if (parser.isSet(selftestOpt)) {
        QObject::connect(&engine, &RpmBuilderEngine::appendLog,
                         [](const QString &line) {
                             if (!line.isEmpty())
                                 qInfo().noquote() << line;
                         });
        QObject::connect(&engine, &RpmBuilderEngine::buildFinished,
                         &app, [&app](bool ok) {
                             qInfo().noquote()
                                 << QStringLiteral("SELFTEST RESULT: %1")
                                        .arg(ok ? QStringLiteral("OK")
                                                : QStringLiteral("FAIL"));
                             QCoreApplication::exit(ok ? 0 : 3);
                         });

        const QString tmpDir = QStandardPaths::writableLocation(
            QStandardPaths::TempLocation);
        const QString demo = tmpDir + QStringLiteral("/demo-app.sh");
        {
            QFile f(demo);
            if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                f.write("#!/bin/sh\necho hello from demo package\n");
                f.setPermissions(QFile::ExeUser | QFile::ReadUser |
                                 QFile::ExeOther | QFile::ReadOther);
            }
        }
        engine.resetProject();            // черновик не должен подмешиваться
        fillDemoProject(engine, demo);

        // --- секции сборки из исходников в сгенерированном spec ---
        const QString spec = engine.specText();
        const bool buildOk = spec.contains(QLatin1String("%build"))
                             && spec.contains(QLatin1String("install -Dm755"))
                             && !spec.contains(
                                 QLatin1String("cp -r %{_sourcedir}"));
        qInfo().noquote() << QStringLiteral("BUILD SECTIONS: %1")
                             .arg(buildOk ? QStringLiteral("PASS")
                                          : QStringLiteral("FAIL"));

        // --- проверка JSON-шаблонов (*.rpmb.json): сохранить и загрузить ---
        const QString tmplPath = tmpDir + QStringLiteral("/demo-template.rpmb.json");
        const bool jsonSaved = engine.saveProjectToFile(tmplPath);
        const bool jsonLoaded = jsonSaved && engine.loadProjectFromFile(tmplPath);
        const bool jsonOk = jsonLoaded
                            && engine.name() == QLatin1String("demo-app")
                            && engine.files().size() == 1
                            && engine.script(QStringLiteral("build"))
                                       == QLatin1String("echo building demo-app\n")
                            && engine.script(QStringLiteral("install"))
                                       .startsWith(QLatin1String("install -Dm755"));
        qInfo().noquote() << QStringLiteral("JSON ROUNDTRIP: %1")
                             .arg(jsonOk ? QStringLiteral("PASS")
                                         : QStringLiteral("FAIL"));
        if (!jsonOk)
            qInfo().noquote() << QStringLiteral("  причина: %1")
                                     .arg(engine.lastProjectError());

        // --- встроенный выбор файлов: данные для FilePicker.qml ---
        // проверяем на детерминированной песочнице
        const QString lsDir = tmpDir + QStringLiteral("/listdir-test");
        QDir(lsDir + QStringLiteral("/sub")).mkpath(QStringLiteral("."));
        { QFile f(lsDir + QStringLiteral("/alpha.txt"));
          if (f.open(QIODevice::WriteOnly)) f.write("a"); }
        { QFile f(lsDir + QStringLiteral("/.hidden"));
          if (f.open(QIODevice::WriteOnly)) f.write("h"); }
        const QVariantList ls = engine.listDir(lsDir, false);
        const QVariantList lsHid = engine.listDir(lsDir, true);
        bool lsOk = ls.size() == 2 && lsHid.size() == 3;
        bool sawDir = false;
        for (const QVariant &e : ls) {
            const QVariantMap m = e.toMap();
            if (m.value(QStringLiteral("isDir")).toBool()) sawDir = true;
            if (!m.contains(QStringLiteral("name"))
                    || !m.contains(QStringLiteral("size")))
                lsOk = false;
        }
        lsOk = lsOk && sawDir
               && engine.isDirPath(lsDir)
               && engine.pathExists(lsDir)
               && !engine.isDirPath(demo)        // файл — не каталог
               && engine.specFileName()
                      == QLatin1String("demo-app.spec");
        qInfo().noquote() << QStringLiteral("LISTDIR: %1")
                             .arg(lsOk ? QStringLiteral("PASS")
                                       : QStringLiteral("FAIL"));
        if (!lsOk)
            qInfo().noquote()
                << QStringLiteral("  list=%1 hidden=%2 sawDir=%3 specName=%4")
                       .arg(ls.size()).arg(lsHid.size()).arg(sawDir)
                       .arg(engine.specFileName());

        QTimer::singleShot(150, &engine, [&engine] { engine.startBuild(); });
        return app.exec();
    }

    if (e2eMode) {
        // --e2etest: сценарий пользователя «открыл пример из папки и собрал».
        // 1) loadProjectFromFile(docs/examples/hello/hello.rpmb.json) —
        //    файл hello.sh должен подхватиться из папки шаблона;
        // 2) startBuild() настоящим rpmbuild из PATH;
        // 3) PASS = в каталоге результатов появился .rpm.
        QObject::connect(&engine, &RpmBuilderEngine::appendLog,
                         [](const QString &line) {
                             if (!line.isEmpty())
                                 qInfo().noquote() << line;
                         });
        // тестовый каталог результатов, чтобы не трогать черновик пользователя
        const QString tmpDir = QStandardPaths::writableLocation(
            QStandardPaths::TempLocation);
        engine.setOutputDir(tmpDir + QStringLiteral("/e2e-out"));

        QString exampleJson = parser.positionalArguments().value(0);
        const QStringList hints{
            exampleJson,
            QCoreApplication::applicationDirPath()
                + QStringLiteral("/../docs/examples/hello/hello.rpmb.json"),
            QStringLiteral("/opt/rpm-builder/docs/examples/hello/hello.rpmb.json"),
            QStringLiteral("/home/z/my-project/download/rpm-builder/docs/examples/hello/hello.rpmb.json")};
        for (const QString &h : hints)
            if (QFileInfo::exists(h)) { exampleJson = h; break; }

        if (exampleJson.isEmpty()) {
            qInfo().noquote() << "E2E SETUP: FAIL (пример hello не найден)";
            return 2;
        }
        qInfo().noquote() << QStringLiteral("E2E TEMPLATE: %1").arg(exampleJson);

        // HOME временно переопределяем, чтобы путь ~/hello.sh из шаблона
        // точно НЕ существовал — проверяем именно авто-подстановку соседа
        const bool loaded = engine.loadProjectFromFile(exampleJson);
        bool resolvedOk = false;
        const QString tplDir =
            QFileInfo(exampleJson).absolutePath();
        for (const QVariant &f : engine.files()) {
            const QString src = f.toMap().value(QStringLiteral("src")).toString();
            qInfo().noquote() << QStringLiteral("E2E FILE SRC: %1").arg(src);
            resolvedOk = resolvedOk
                         || (QFileInfo(src).absolutePath() == tplDir
                             && QFileInfo::exists(src));
        }
        qInfo().noquote() << QStringLiteral("SIBLING RESOLVE: %1")
                             .arg(resolvedOk && loaded
                                      ? QStringLiteral("PASS")
                                      : QStringLiteral("FAIL"));
        if (!resolvedOk || !loaded) {
            qInfo().noquote() << QStringLiteral("  lastError: %1")
                                     .arg(engine.lastProjectError());
            return 2;
        }
        if (engine.rpmbuildPath().isEmpty()) {
            qInfo().noquote()
                << "RPMBUILD: NOT FOUND — E2E BUILD SKIPPED (только SIBLING)";
            return resolvedOk ? 0 : 2;
        }
        qInfo().noquote() << QStringLiteral("RPMBUILD: %1")
                             .arg(engine.rpmbuildPath());

        QObject::connect(&engine, &RpmBuilderEngine::buildFinished, &app,
                         [&engine](bool ok) {
                             if (!ok) {
                                 qInfo().noquote()
                                     << "E2E BUILD: FAIL";
                                 QCoreApplication::exit(3);
                                 return;
                             }
                             // артефакты копируются в outputDir
                             qInfo().noquote()
                                 << QStringLiteral("E2E BUILD: OK (%1 rpm)")
                                        .arg(engine.lastArtifacts().size());
                             QCoreApplication::exit(0);
                         });
        QTimer::singleShot(150, &engine, [&engine] { engine.startBuild(); });
        return app.exec();
    }

    // ------------------------- режим скриншотов ---------------------------
    const QString outDir = parser.value(shotsOpt);
    QDir().mkpath(outDir);
    win->resize(1280, 832);

    struct Runner : public QObject {
        QQuickWindow *w = nullptr;
        QString dir;
        int pages = 7;
        int idx = 0;
        bool pickerDone = false;
        bool aboutDone = false;
        void grabShot(const QString &name) {
            auto result = w->contentItem()->grabToImage();
            QObject::connect(result.data(), &QQuickItemGrabResult::ready, this,
                             [this, result, name] {
                                 result->saveToFile(QString(
                                     QStringLiteral("%1/%2.png")).arg(dir, name));
                                 if (name == QStringLiteral("about")) {
                                     w->close();
                                     return;
                                 }
                                 ++idx;
                                 step();
                             });
        }
        void step()
        {
            if (idx >= pages) {
                if (!pickerDone) {
                    // снимок встроенного выбора файлов (FilePicker)
                    pickerDone = true;
                    QVariant ret;
                    QMetaObject::invokeMethod(w, "openPickerForShots",
                                              Q_RETURN_ARG(QVariant, ret));
                    QTimer::singleShot(420, this, [this] {
                        grabShot(QStringLiteral("picker"));
                    });
                    return;
                }
                if (!aboutDone) {
                    aboutDone = true;
                    QVariant ret;
                    QMetaObject::invokeMethod(w, "closePickerForShots",
                                              Q_RETURN_ARG(QVariant, ret));
                    QMetaObject::invokeMethod(w, "showAbout",
                                              Q_RETURN_ARG(QVariant, ret));
                    QTimer::singleShot(500, this, [this] { grabShot(QStringLiteral("about")); });
                    return;
                }
                w->close();
                return;
            }
            QVariant ret;
            QMetaObject::invokeMethod(w, "showPage",
                                      Q_RETURN_ARG(QVariant, ret),
                                      Q_ARG(QVariant, QVariant(idx)));
            QTimer::singleShot(260, this, [this] { grabShot(
                QStringLiteral("page-%1").arg(idx, 2, 10, QLatin1Char('0'))); });
        }
    };
    auto *runner = new Runner();
    runner->w = win;
    runner->dir = outDir;
    QObject::connect(win, &QQuickWindow::closing, &app, &QCoreApplication::quit);
    runner->step();

    return app.exec();
}
