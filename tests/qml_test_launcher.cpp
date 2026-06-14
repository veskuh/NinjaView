#include <QtQuickTest>
#include <QtPlugin>
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlContext>
#include <QLibraryInfo>
#include <QThreadPool>
#include "AsyncImageProvider.h"
#include "FileDiscoveryService.h"
#include "GalleryListModel.h"
#include "FileActionService.h"
#include "VolumeMonitor.h"
#include "ExifReader.h"
#include "Logger.h"

#include "ExifDatabase.h"
#include "GalleryFilterProxyModel.h"

#include <QImage>
#include <QPainter>
#include <QDir>

Q_IMPORT_PLUGIN(NinjaViewPlugin)

class TestSetup : public QObject
{
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        static Logger* logger = new Logger();
        static ExifDatabase* exifDb = new ExifDatabase();
        static bool dbInit = false;
        if (!dbInit) {
            exifDb->init();
            dbInit = true;
        }

        static GalleryListModel* rawGalleryModel = new GalleryListModel();
        static GalleryFilterProxyModel* galleryModel = new GalleryFilterProxyModel();
        static bool modelsConnected = false;
        if (!modelsConnected) {
            galleryModel->setSourceModel(rawGalleryModel);
            galleryModel->setDatabase(exifDb);
            modelsConnected = true;
        }

        static FileDiscoveryService* discoveryService = new FileDiscoveryService();
        static bool discInit = false;
        if (!discInit) {
            discoveryService->setDatabase(exifDb);
            discInit = true;
        }

        static VolumeMonitor* volumeMonitor = new VolumeMonitor();
        static ExifReader* exifReader = new ExifReader();
        static bool readerInit = false;
        if (!readerInit) {
            exifReader->setDatabase(exifDb);
            readerInit = true;
        }

        static FileActionService* fileActionService = new FileActionService();
        static AsyncImageProvider* imageProvider = new AsyncImageProvider(logger);
        
        static bool connectionsDone = false;
        if (!connectionsDone) {
            QObject::connect(discoveryService, &FileDiscoveryService::imagesDiscovered,
                             rawGalleryModel, &GalleryListModel::addImages);
            QObject::connect(discoveryService, &FileDiscoveryService::foldersDiscovered,
                             rawGalleryModel, &GalleryListModel::addFolders);
            connectionsDone = true;
        }

        engine->rootContext()->setContextProperty("allowFullScreen", false);
        engine->rootContext()->setContextProperty("isSelfTest", false);
        engine->rootContext()->setContextProperty("fileActionService", fileActionService);
        engine->rootContext()->setContextProperty("logger", logger);
        engine->rootContext()->setContextProperty("galleryModel", galleryModel);
        engine->rootContext()->setContextProperty("rawGalleryModel", rawGalleryModel);
        engine->rootContext()->setContextProperty("exifDatabase", exifDb);
        engine->rootContext()->setContextProperty("discoveryService", discoveryService);
        engine->rootContext()->setContextProperty("volumeMonitor", volumeMonitor);
        engine->rootContext()->setContextProperty("exifReader", exifReader);
        engine->rootContext()->setContextProperty("imageProvider", imageProvider);
        engine->rootContext()->setContextProperty("appVersion", QString(NINJAVIEW_VERSION));
        engine->rootContext()->setContextProperty("appBuild", QString(NINJAVIEW_BUILD_ID));
        engine->rootContext()->setContextProperty("qtVersion", QString(qVersion()));
        
        engine->addImageProvider(QLatin1String("gallery"), imageProvider);
        
        // Create dummy images for tests
        QStringList files = {"/tmp/test1.jpg", "/tmp/test2.jpg", "/tmp/test3.jpg"};
        QImage img(10, 10, QImage::Format_RGB32);
        img.fill(Qt::red);
        for (const auto &f : files) {
            img.save(f, "JPG");
        }
    }
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("NinjaView");
    app.setOrganizationDomain("net.veskuh.test");

    TestSetup setup;
    int ret = quick_test_main_with_setup(argc, argv, "ninjaview", QUICK_TEST_SOURCE_DIR, &setup);
    QThreadPool::globalInstance()->waitForDone();
    return ret;
}

#include "qml_test_launcher.moc"
