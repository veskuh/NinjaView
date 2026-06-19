// tests/tst_filediscoveryservice.cpp

#include <QtTest>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include "FileDiscoveryService.h"
#include "ExifDatabase.h"

/// @brief Tests for FileDiscoveryService scanning and indexing logic.
class TestFileDiscoveryService : public QObject {
    Q_OBJECT
private slots:
    void initTestCase();
    void testScanDirectory();
    void testScanDirectoryWithFolders();
    void testRecursiveScan();
    void testConcurrentScans();
    void testInvalidDirectory();
    void testIsScanningProperty();
    void testFileUrlHandling();
    void testIndexingSignal();
    void testBundleFiltering();
    void cleanupTestCase();

private:
    QTemporaryDir m_appDataDir;
};

void TestFileDiscoveryService::initTestCase()
{
    // Redirect writable locations so the real ExifDatabase doesn't pollute user data
    QVERIFY(m_appDataDir.isValid());
    QStandardPaths::setTestModeEnabled(true);
}

void TestFileDiscoveryService::cleanupTestCase()
{
    QStandardPaths::setTestModeEnabled(false);
}

void TestFileDiscoveryService::testScanDirectory()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    // Create image and video files
    QString img1 = tempDir.path() + "/img1.jpg";
    QString img2 = tempDir.path() + "/img2.png";
    QString video1 = tempDir.path() + "/video1.mp4";
    QString video2 = tempDir.path() + "/video2.mov";
    QFile f1(img1); QVERIFY(f1.open(QIODevice::WriteOnly)); f1.write("dummy"); f1.close();
    QFile f2(img2); QVERIFY(f2.open(QIODevice::WriteOnly)); f2.write("dummy"); f2.close();
    QFile f3(video1); QVERIFY(f3.open(QIODevice::WriteOnly)); f3.write("dummy"); f3.close();
    QFile f4(video2); QVERIFY(f4.open(QIODevice::WriteOnly)); f4.write("dummy"); f4.close();

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    service.scanDirectory(tempDir.path(), false);
    QVERIFY(finishedSpy.wait(5000));

    QCOMPARE(imgSpy.count(), 1);
    QStringList imgList = imgSpy.takeFirst().at(0).toStringList();
    QCOMPARE(imgList.size(), 4);
    QVERIFY(imgList.contains(img1));
    QVERIFY(imgList.contains(img2));
    QVERIFY(imgList.contains(video1));
    QVERIFY(imgList.contains(video2));
}

void TestFileDiscoveryService::testScanDirectoryWithFolders()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    // Create image files
    QString img = tempDir.path() + "/photo.jpg";
    QFile f(img); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("dummy"); f.close();

    // Create subfolders
    QDir dir(tempDir.path());
    QVERIFY(dir.mkdir("sub1"));
    QVERIFY(dir.mkdir("sub2"));

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
    QSignalSpy folderSpy(&service, &FileDiscoveryService::foldersDiscovered);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    service.scanDirectory(tempDir.path(), false);
    QVERIFY(finishedSpy.wait(5000));

    // Verify image discovery
    QCOMPARE(imgSpy.count(), 1);
    QStringList imgList = imgSpy.takeFirst().at(0).toStringList();
    QCOMPARE(imgList.size(), 1);
    QVERIFY(imgList.contains(img));

    // Verify folder discovery
    QCOMPARE(folderSpy.count(), 1);
    QStringList folderList = folderSpy.takeFirst().at(0).toStringList();
    QCOMPARE(folderList.size(), 2);
    QVERIFY(folderList.contains(tempDir.path() + "/sub1"));
    QVERIFY(folderList.contains(tempDir.path() + "/sub2"));
}

void TestFileDiscoveryService::testRecursiveScan()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    // Nested folder with an image
    QDir dir(tempDir.path());
    QVERIFY(dir.mkdir("nested"));
    QString nestedImg = tempDir.path() + "/nested/nested.jpg";
    QFile f(nestedImg);
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write("dummy");
    f.close();

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
    QSignalSpy folderSpy(&service, &FileDiscoveryService::foldersDiscovered);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    service.scanDirectory(tempDir.path(), true);
    QVERIFY(finishedSpy.wait(5000));

    QCOMPARE(imgSpy.count(), 1);
    QStringList imgList = imgSpy.takeFirst().at(0).toStringList();
    QCOMPARE(imgList.size(), 1);
    QVERIFY(imgList.contains(nestedImg));

    // In recursive mode, folders are not emitted
    QCOMPARE(folderSpy.count(), 0);
}

void TestFileDiscoveryService::testConcurrentScans()
{
    QTemporaryDir dirA, dirB;
    QVERIFY(dirA.isValid() && dirB.isValid());

    // Image only in dirA
    QString aImg = dirA.path() + "/a.jpg";
    QFile fA(aImg); QVERIFY(fA.open(QIODevice::WriteOnly)); fA.write("dummy"); fA.close();

    // Image only in dirB
    QString bImg = dirB.path() + "/b.jpg";
    QFile fB(bImg); QVERIFY(fB.open(QIODevice::WriteOnly)); fB.write("dummy"); fB.close();

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    service.scanDirectory(dirA.path(), false);
    // Immediately start another scan – the first should be cancelled via scanId
    service.scanDirectory(dirB.path(), false);
    QVERIFY(finishedSpy.wait(5000));

    // Only the second scan's results should be emitted
    QCOMPARE(imgSpy.count(), 1);
    QStringList imgList = imgSpy.takeFirst().at(0).toStringList();
    QCOMPARE(imgList.size(), 1);
    QCOMPARE(imgList.first(), bImg);
}

void TestFileDiscoveryService::testInvalidDirectory()
{
    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
    QSignalSpy folderSpy(&service, &FileDiscoveryService::foldersDiscovered);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    service.scanDirectory("/nonexistent/path");
    QVERIFY(finishedSpy.wait(5000));

    // No images or folders should be emitted
    QCOMPARE(imgSpy.count(), 0);
    QCOMPARE(folderSpy.count(), 0);
}

void TestFileDiscoveryService::testIsScanningProperty()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    QString img = tempDir.path() + "/test.jpg";
    QFile f(img); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("dummy"); f.close();

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QVERIFY(!service.isScanning());

    QSignalSpy scanChangedSpy(&service, &FileDiscoveryService::isScanningChanged);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    service.scanDirectory(tempDir.path(), false);

    // isScanning should have been set to true synchronously
    QVERIFY(service.isScanning());
    QVERIFY(scanChangedSpy.count() >= 1);

    QVERIFY(finishedSpy.wait(5000));

    // After scan finishes, isScanning should be false
    QVERIFY(!service.isScanning());
}

void TestFileDiscoveryService::testFileUrlHandling()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    QString img = tempDir.path() + "/url_test.jpg";
    QFile f(img); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("dummy"); f.close();

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    // Pass as file:// URL instead of plain path
    QString fileUrl = QUrl::fromLocalFile(tempDir.path()).toString();
    service.scanDirectory(fileUrl, false);
    QVERIFY(finishedSpy.wait(5000));

    QCOMPARE(imgSpy.count(), 1);
    QStringList imgList = imgSpy.takeFirst().at(0).toStringList();
    QCOMPARE(imgList.size(), 1);
    QVERIFY(imgList.contains(img));
}

void TestFileDiscoveryService::testIndexingSignal()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    QString img = tempDir.path() + "/index_test.jpg";
    QFile f(img); QVERIFY(f.open(QIODevice::WriteOnly)); f.write("dummy"); f.close();

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    QSignalSpy indexingSpy(&service, &FileDiscoveryService::indexingFinished);
    QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

    service.scanDirectory(tempDir.path(), false);
    QVERIFY(finishedSpy.wait(5000));

    // indexingFinished should have been emitted after EXIF cache population
    QCOMPARE(indexingSpy.count(), 1);
}

void TestFileDiscoveryService::testBundleFiltering()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    // Create a normal subfolder and some bundle folders
    QDir dir(tempDir.path());
    QVERIFY(dir.mkdir("normal_folder"));
    QVERIFY(dir.mkdir("AppBundle.app"));
    QVERIFY(dir.mkdir("MyFramework.framework"));
    QVERIFY(dir.mkdir("Photos.photoslibrary"));

    // Create an image inside the normal folder and one inside each bundle folder
    QString normalImg = tempDir.path() + "/normal_folder/pic1.jpg";
    QString appImg = tempDir.path() + "/AppBundle.app/pic2.jpg";
    QString frameworkImg = tempDir.path() + "/MyFramework.framework/pic3.jpg";
    QString photosImg = tempDir.path() + "/Photos.photoslibrary/pic4.jpg";

    QFile f1(normalImg); QVERIFY(f1.open(QIODevice::WriteOnly)); f1.write("dummy"); f1.close();
    QFile f2(appImg); QVERIFY(f2.open(QIODevice::WriteOnly)); f2.write("dummy"); f2.close();
    QFile f3(frameworkImg); QVERIFY(f3.open(QIODevice::WriteOnly)); f3.write("dummy"); f3.close();
    QFile f4(photosImg); QVERIFY(f4.open(QIODevice::WriteOnly)); f4.write("dummy"); f4.close();

    FileDiscoveryService service;
    ExifDatabase db(":memory:");
    db.init();
    service.setDatabase(&db);

    // Test non-recursive: bundles should NOT be reported as folders
    {
        QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
        QSignalSpy folderSpy(&service, &FileDiscoveryService::foldersDiscovered);
        QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

        service.scanDirectory(tempDir.path(), false);
        QVERIFY(finishedSpy.wait(5000));

        // Folders should contain only normal_folder
        QCOMPARE(folderSpy.count(), 1);
        QStringList folderList = folderSpy.takeFirst().at(0).toStringList();
        QCOMPARE(folderList.size(), 1);
        QVERIFY(folderList.contains(tempDir.path() + "/normal_folder"));
        QVERIFY(!folderList.contains(tempDir.path() + "/AppBundle.app"));
        QVERIFY(!folderList.contains(tempDir.path() + "/MyFramework.framework"));
        QVERIFY(!folderList.contains(tempDir.path() + "/Photos.photoslibrary"));
    }

    // Test recursive: images inside bundles should NOT be discovered
    {
        QSignalSpy imgSpy(&service, &FileDiscoveryService::imagesDiscovered);
        QSignalSpy finishedSpy(&service, &FileDiscoveryService::scanFinished);

        service.scanDirectory(tempDir.path(), true);
        QVERIFY(finishedSpy.wait(5000));

        // Images should contain only normalImg
        QCOMPARE(imgSpy.count(), 1);
        QStringList imgList = imgSpy.takeFirst().at(0).toStringList();
        QCOMPARE(imgList.size(), 1);
        QVERIFY(imgList.contains(normalImg));
        QVERIFY(!imgList.contains(appImg));
        QVERIFY(!imgList.contains(frameworkImg));
        QVERIFY(!imgList.contains(photosImg));
    }
}

QTEST_MAIN(TestFileDiscoveryService)
#include "tst_filediscoveryservice.moc"
