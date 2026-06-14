#include <QtTest>
#include "AsyncImageProvider.h"
#include <QTemporaryFile>
#include <QImage>
#include <QPainter>
#include <QStandardPaths>
#include <QProcess>

/// @brief Tests for AsyncImageProvider thumbnail generation and caching.
class TestAsyncImageProvider : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testRequestImage();
    void testMemoryCacheHit();
    void testMemoryCacheLimit();
    void testCancelRequest();
    void testClearCache();
    void testDiskCacheOps();
    void testClearImageCacheSpecific();
    void testInMemoryRotationDecodeAndQueryParam();
    void testRequestVideo();
    void cleanupTestCase();
};

void TestAsyncImageProvider::initTestCase()
{
    QStandardPaths::setTestModeEnabled(true);
}

void TestAsyncImageProvider::cleanupTestCase()
{
    QStandardPaths::setTestModeEnabled(false);
}

void TestAsyncImageProvider::testRequestImage()
{
    // Create a real image file
    QTemporaryFile tempFile(QDir::tempPath() + "/testXXXXXX.png");
    QVERIFY(tempFile.open());
    QString filePath = tempFile.fileName();
    
    QImage testImage(100, 100, QImage::Format_RGB32);
    testImage.fill(Qt::red);
    QVERIFY(testImage.save(filePath, "PNG"));
    tempFile.close();

    AsyncImageProvider provider;
    QSize requestedSize(50, 50);
    
    QQuickImageResponse *response = provider.requestImageResponse(filePath, requestedSize);
    QVERIFY(response);
    
    // Wait for the async response
    QSignalSpy spy(response, &QQuickImageResponse::finished);
    QVERIFY(spy.wait(5000));
    
    QQuickTextureFactory *factory = response->textureFactory();
    QVERIFY(factory);
    
    QImage resultImage = factory->image();
    QCOMPARE(resultImage.size(), requestedSize);
    QCOMPARE(resultImage.pixelColor(0,0), QColor(Qt::red));
    
    delete response;
}

void TestAsyncImageProvider::testMemoryCacheHit()
{
    // Create a real image file
    QTemporaryFile tempFile(QDir::tempPath() + "/cacheXXXXXX.png");
    QVERIFY(tempFile.open());
    QString filePath = tempFile.fileName();
    
    QImage testImage(80, 80, QImage::Format_RGB32);
    testImage.fill(Qt::green);
    QVERIFY(testImage.save(filePath, "PNG"));
    tempFile.close();

    AsyncImageProvider provider;
    QSize requestedSize(40, 40);
    
    // First request — should decode from file and populate cache
    QQuickImageResponse *response1 = provider.requestImageResponse(filePath, requestedSize);
    QVERIFY(response1);
    QSignalSpy spy1(response1, &QQuickImageResponse::finished);
    QVERIFY(spy1.wait(5000));
    
    QQuickTextureFactory *factory1 = response1->textureFactory();
    QVERIFY(factory1);
    QVERIFY(!factory1->image().isNull());
    delete response1;

    // Second request — should hit the memory cache (covers lines 39-42)
    QQuickImageResponse *response2 = provider.requestImageResponse(filePath, requestedSize);
    QVERIFY(response2);
    QSignalSpy spy2(response2, &QQuickImageResponse::finished);
    QVERIFY(spy2.wait(5000));
    
    QQuickTextureFactory *factory2 = response2->textureFactory();
    QVERIFY(factory2);
    QImage resultImage = factory2->image();
    QCOMPARE(resultImage.size(), requestedSize);
    delete response2;
}

void TestAsyncImageProvider::testMemoryCacheLimit()
{
    AsyncImageProvider provider;
    
    // Check initial default cost (2 GB in bytes)
    QCOMPARE(provider.maxMemoryCacheSize(), 2048 * 1024 * 1024ULL);
    
    // Test changing max memory cache size
    qint64 newSize = 512 * 1024 * 1024ULL; // 512 MB
    
    QSignalSpy spy(&provider, &AsyncImageProvider::maxMemoryCacheSizeChanged);
    provider.setMaxMemoryCacheSize(newSize);
    
    QCOMPARE(provider.maxMemoryCacheSize(), newSize);
    QCOMPARE(spy.count(), 1);

    // Setting the same size again should not emit
    provider.setMaxMemoryCacheSize(newSize);
    QCOMPARE(spy.count(), 1);
}

void TestAsyncImageProvider::testCancelRequest()
{
    // Create a real image file
    QTemporaryFile tempFile(QDir::tempPath() + "/testXXXXXX.png");
    QVERIFY(tempFile.open());
    QString filePath = tempFile.fileName();
    
    QImage testImage(100, 100, QImage::Format_RGB32);
    testImage.fill(Qt::blue);
    QVERIFY(testImage.save(filePath, "PNG"));
    tempFile.close();

    AsyncImageProvider provider;
    QSize requestedSize(50, 50);
    
    QQuickImageResponse *response = provider.requestImageResponse(filePath, requestedSize);
    QVERIFY(response);
    
    // Cancel immediately before it finishes (or even starts)
    QSignalSpy spy(response, &QQuickImageResponse::finished);
    response->cancel();
    
    // Wait for the async response to report finished
    QVERIFY(spy.wait(5000));
    
    // It should have finished
    QCOMPARE(spy.count(), 1);
    
    // The texture factory should be null or return a null/empty image because it was cancelled
    QQuickTextureFactory *factory = response->textureFactory();
    if (factory) {
        QVERIFY(factory->image().isNull());
    }
    
    delete response;
}

void TestAsyncImageProvider::testClearCache()
{
    AsyncImageProvider provider;

    // Generate a cached image first
    QTemporaryFile tempFile(QDir::tempPath() + "/clearXXXXXX.png");
    QVERIFY(tempFile.open());
    QString filePath = tempFile.fileName();
    QImage testImage(60, 60, QImage::Format_RGB32);
    testImage.fill(Qt::cyan);
    QVERIFY(testImage.save(filePath, "PNG"));
    tempFile.close();

    QQuickImageResponse *response = provider.requestImageResponse(filePath, QSize(30, 30));
    QSignalSpy spy(response, &QQuickImageResponse::finished);
    QVERIFY(spy.wait(5000));
    delete response;

    // Clear should not crash and memory cache should be emptied
    provider.clearCache();
}

void TestAsyncImageProvider::testDiskCacheOps()
{
    AsyncImageProvider provider;

    // Generate a cached image on disk
    QTemporaryFile tempFile(QDir::tempPath() + "/diskXXXXXX.png");
    QVERIFY(tempFile.open());
    QString filePath = tempFile.fileName();
    QImage testImage(64, 64, QImage::Format_RGB32);
    testImage.fill(Qt::yellow);
    QVERIFY(testImage.save(filePath, "PNG"));
    tempFile.close();

    QQuickImageResponse *response = provider.requestImageResponse(filePath, QSize(32, 32));
    QSignalSpy spy(response, &QQuickImageResponse::finished);
    QVERIFY(spy.wait(5000));
    delete response;

    // cachePath should return a valid path
    QVERIFY(!provider.cachePath().isEmpty());

    // cacheSize should be >= 0
    QVERIFY(provider.cacheSize() >= 0);

    // clearDiskCache should not crash and should clear the cache directory
    provider.clearDiskCache();
    QCOMPARE(provider.cacheSize(), 0);
}

void TestAsyncImageProvider::testClearImageCacheSpecific()
{
    AsyncImageProvider provider;

    QTemporaryFile tempFile(QDir::tempPath() + "/specificXXXXXX.png");
    QVERIFY(tempFile.open());
    QString filePath = tempFile.fileName();
    QImage testImage(60, 60, QImage::Format_RGB32);
    testImage.fill(Qt::blue);
    QVERIFY(testImage.save(filePath, "PNG"));
    tempFile.close();

    // 1. Request image to populate memory and disk caches
    QQuickImageResponse *response = provider.requestImageResponse(filePath, QSize(30, 30));
    QSignalSpy spy(response, &QQuickImageResponse::finished);
    QVERIFY(spy.wait(5000));
    delete response;

    // Check that disk cache size is greater than 0
    qint64 sizeBefore = provider.cacheSize();
    QVERIFY(sizeBefore > 0);

    // 2. Clear image cache for this file
    provider.clearImageCache(filePath);

    // 3. Disk cache for this file should be removed
    QCOMPARE(provider.cacheSize(), 0);
}

void TestAsyncImageProvider::testInMemoryRotationDecodeAndQueryParam()
{
    AsyncImageProvider provider;

    QTemporaryFile tempFile(QDir::tempPath() + "/rotate_queryXXXXXX.png");
    QVERIFY(tempFile.open());
    QString filePath = tempFile.fileName();
    QImage testImage(64, 32, QImage::Format_RGB32); // 64 wide, 32 high
    testImage.fill(Qt::green);
    QVERIFY(testImage.save(filePath, "PNG"));
    tempFile.close();

    // Set in-memory rotation using query parameters to test query parsing paths
    QString filePathWithQuery = filePath + "?t=123456";
    provider.setInMemoryRotation(filePathWithQuery, 90);
    
    // Check rotation is stored (with query stripped)
    QCOMPARE(provider.inMemoryRotation(filePathWithQuery), 90);
    QCOMPARE(provider.inMemoryRotation(filePath), 90);

    // Request the image (which will decode it from source, see it has rotation, and rotate it)
    QQuickImageResponse *response = provider.requestImageResponse(filePathWithQuery, QSize(32, 32));
    QSignalSpy spy(response, &QQuickImageResponse::finished);
    QVERIFY(spy.wait(5000));

    QQuickTextureFactory *factory = response->textureFactory();
    QVERIFY(factory != nullptr);
    QImage resultImage = factory->image();
    delete response;

    // Width should be 16 and height 32 due to rotation of 64x32 scaled to fit 32x32
    QCOMPARE(resultImage.width(), 16);
    QCOMPARE(resultImage.height(), 32);

    // Clear in-memory rotation
    provider.clearInMemoryRotation(filePathWithQuery);
    QCOMPARE(provider.inMemoryRotation(filePathWithQuery), 0);
}

void TestAsyncImageProvider::testRequestVideo()
{
    QString filePath = "data/test.mp4";

    AsyncImageProvider provider;
    QSize requestedSize(50, 50);
    
    QQuickImageResponse *response = provider.requestImageResponse(filePath, requestedSize);
    QVERIFY(response);
    
    QSignalSpy spy(response, &QQuickImageResponse::finished);
    QVERIFY(spy.wait(5000));
    
    QQuickTextureFactory *factory = response->textureFactory();
    QVERIFY(factory);
    QImage resultImage = factory->image();
    
    // On platforms with ffmpeg installed (macOS in our case), it should successfully decode a frame!
    QVERIFY(!resultImage.isNull());
    QCOMPARE(resultImage.size(), QSize(50, 37));
    
    delete response;
}

QTEST_MAIN(TestAsyncImageProvider)
#include "tst_asyncimageprovider.moc"
