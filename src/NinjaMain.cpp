#include <QGuiApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QtPlugin>
#include <QLibraryInfo>

#include "GalleryListModel.h"
#include "GalleryFilterProxyModel.h"
#include "FileDiscoveryService.h"
#include "AsyncImageProvider.h"
#include "VolumeMonitor.h"
#include "ExifReader.h"
#include "FileActionService.h"
#include "Logger.h"
#include "ExifDatabase.h"

Q_IMPORT_PLUGIN(NinjaViewPlugin)

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("NinjaView");
    bool selfTest = app.arguments().contains("--selftest");
    if (selfTest) {
        app.setOrganizationDomain("net.veskuh.test");
    } else {
        app.setOrganizationDomain("net.veskuh");
    }

    // Backend components (must be declared before engine to ensure they outlive it)
    Logger logger;
    ExifDatabase exifDb;
    exifDb.init();
    
    GalleryListModel galleryModel(selfTest);
    
    GalleryFilterProxyModel filterModel;
    filterModel.setSourceModel(&galleryModel);
    filterModel.setDatabase(&exifDb);
    
    // Auto-refresh proxy filter when metadata updates
    QObject::connect(&exifDb, &ExifDatabase::favoritesChanged,
                     &filterModel, &GalleryFilterProxyModel::invalidateFilter);
    QObject::connect(&exifDb, &ExifDatabase::tagsChanged,
                     &filterModel, &GalleryFilterProxyModel::invalidateFilter);
    
    FileDiscoveryService discoveryService;
    discoveryService.setDatabase(&exifDb);
    
    FileActionService fileActionService;
    VolumeMonitor volumeMonitor;
    
    ExifReader exifReader;
    exifReader.setDatabase(&exifDb);
    
    AsyncImageProvider *imageProvider = new AsyncImageProvider(&logger);

    QQmlApplicationEngine engine;

#if defined(Q_OS_LINUX)
    engine.addImportPath(QCoreApplication::applicationDirPath() + "/../lib/ninjaview/qml");
    engine.addImportPath(QCoreApplication::applicationDirPath() + "/../lib64/ninjaview/qml");
#endif


    // Connect discovery service to model
    QObject::connect(&discoveryService, &FileDiscoveryService::imagesDiscovered,
                     &galleryModel, &GalleryListModel::addImages);
    QObject::connect(&discoveryService, &FileDiscoveryService::foldersDiscovered,
                     &galleryModel, &GalleryListModel::addFolders);

    // Connect volume monitor to cleanup actions (only if the unmounted volume was being viewed)
    QObject::connect(&volumeMonitor, &VolumeMonitor::volumeUnmounted,
                     [&galleryModel, imageProvider](const QString &path) {
        if (galleryModel.rowCount() > 0) {
            QString firstPath = galleryModel.getRawPath(0);
            if (firstPath.startsWith(path)) {
                qDebug() << "Active directory resides on unmounted volume" << path << "- clearing gallery.";
                galleryModel.clear();
                imageProvider->clearCache();
            }
        }
    });

    // Register types and providers
    engine.rootContext()->setContextProperty("allowFullScreen", true);
    engine.rootContext()->setContextProperty("isSelfTest", selfTest);
    engine.rootContext()->setContextProperty("fileActionService", &fileActionService);
    engine.rootContext()->setContextProperty("imageProvider", imageProvider);
    engine.rootContext()->setContextProperty("volumeMonitor", &volumeMonitor);
    engine.rootContext()->setContextProperty("logger", &logger);
    engine.rootContext()->setContextProperty("galleryModel", &filterModel);
    engine.rootContext()->setContextProperty("rawGalleryModel", &galleryModel);
    engine.rootContext()->setContextProperty("exifDatabase", &exifDb);
    engine.rootContext()->setContextProperty("discoveryService", (QObject*)&discoveryService);
    engine.rootContext()->setContextProperty("exifReader", (QObject*)&exifReader);
    engine.rootContext()->setContextProperty("appVersion", QString(NINJAVIEW_VERSION));
    engine.rootContext()->setContextProperty("appBuild", QString(NINJAVIEW_BUILD_ID));
    engine.rootContext()->setContextProperty("qtVersion", QString(qVersion()));
    engine.addImageProvider(QLatin1String("gallery"), imageProvider);

    using namespace Qt::StringLiterals;
    const QUrl url(u"qrc:/qt/qml/NinjaView/qml/views/NinjaWindow.qml"_s);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url, selfTest](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            qCritical() << "Failed to load" << url;
            QCoreApplication::exit(-1);
        } else if (selfTest) {
            qDebug() << "Self-test passed: Main.qml loaded successfully.";
            QCoreApplication::quit();
        }
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
