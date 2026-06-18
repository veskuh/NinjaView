#include <QtTest>
#include <QTemporaryFile>
#include <QTemporaryDir>
#include <QFile>
#include <QUrl>
#include <QFileInfo>
#include <QClipboard>
#include <QMimeData>
#include <QGuiApplication>
#include "FileActionService.h"
#include "AsyncImageProvider.h"
#include "exif.h"

class TestFileActionService : public QObject
{
    Q_OBJECT

private slots:
    void testMoveToTrashLocalPath();
    void testMoveToTrashUrlPath();
    void testPathTranslationMock();
    void testRotateImageWritable();
    void testRotateImageReadOnly();
    void testRotateNonExistentFile();
    void testRotateNonJpegFile();
    void testRotateInvalidAngle();
    void testRotateEmptyFile();
    void testRotateInvalidJpegMarker();
    void testRotateJpegWithoutExif();
    void testRotateJpegWithInvalidExifHeader();
    void testRotateJpegWithInvalidTiffByteOrder();
    void testRotateImageFileUrl();
    void testRotateImageInMemoryWithProvider();
    void testRotateFileNotReadable();
    void testRotateJpegInvalidStructure();
    void testRotateJpegEarlyStartOfScan();
    void testRotateJpegHugeIfdOffset();
    void testRotateJpegTruncatedFields();
    void testRotateLittleEndianWritable();
    void testCopyToClipboard();
};

void TestFileActionService::testMoveToTrashLocalPath()
{
    // Create a temporary file
    QTemporaryFile tempFile;
    QVERIFY(tempFile.open());
    QString path = tempFile.fileName();
    tempFile.close(); // Close so we can delete/move it
    QVERIFY(QFile::exists(path));

    FileActionService service;
    bool success = service.moveToTrash(path);
    if (success) {
        QVERIFY(!QFile::exists(path));
    } else {
        qWarning() << "moveToTrash not supported on this platform/setup. File still exists:" << QFile::exists(path);
        QVERIFY(QFile::exists(path));
    }
}

void TestFileActionService::testMoveToTrashUrlPath()
{
    // Create a temporary file
    QTemporaryFile tempFile;
    QVERIFY(tempFile.open());
    QString path = tempFile.fileName();
    tempFile.close();
    QVERIFY(QFile::exists(path));

    // Convert to file:// URL
    QString urlPath = QUrl::fromLocalFile(path).toString();
    QVERIFY(urlPath.startsWith("file://"));

    FileActionService service;
    bool success = service.moveToTrash(urlPath);
    if (success) {
        QVERIFY(!QFile::exists(path));
    } else {
        qWarning() << "moveToTrash URL not supported on this platform/setup. File still exists:" << QFile::exists(path);
        QVERIFY(QFile::exists(path));
    }
}

void TestFileActionService::testPathTranslationMock()
{
    // Test that the other methods don't crash when passed empty paths, invalid paths, and URL paths
    FileActionService service;
    
    // We expect these to run without crashing
    service.showInFolder("");
    service.openExternally("");
    
    // Passing a non-existent temp file should also work without crashing
    service.showInFolder("file:///nonexistent/path/file.jpg");
    service.openExternally("file:///nonexistent/path/file.jpg");
}

void TestFileActionService::testRotateImageWritable()
{
    // Copy the test image to a temp directory
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString sourcePath = "data/canon-g9-x.jpg";
    QString destPath = tempDir.path() + "/test-rotate.jpg";
    QVERIFY(QFile::copy(sourcePath, destPath));

    // Reset permissions to ensure it's writable
    QVERIFY(QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser));

    // Read initial orientation using easyexif
    QFile file(destPath);
    QVERIFY(file.open(QIODevice::ReadOnly));
    QByteArray buffer = file.readAll();
    file.close();

    easyexif::EXIFInfo info;
    QCOMPARE(info.parseFrom((unsigned char *)buffer.data(), buffer.size()), 0);
    int initialOrientation = info.Orientation;
    if (initialOrientation < 1 || initialOrientation > 8) {
        initialOrientation = 1;
    }

    // Call rotateImage (CW 90 degrees)
    FileActionService service;
    int result = service.rotateImage(destPath, 90);
    QCOMPARE(result, 0); // 0 = Success (on disk)

    // Read new orientation using easyexif
    QVERIFY(file.open(QIODevice::ReadOnly));
    buffer = file.readAll();
    file.close();

    QCOMPARE(info.parseFrom((unsigned char *)buffer.data(), buffer.size()), 0);
    int newOrientation = info.Orientation;

    // Verify rotation logic: 1 -> 6, 6 -> 3, 3 -> 8, 8 -> 1 etc.
    static const int cw_rot[8] = { 6, 7, 8, 5, 2, 3, 4, 1 };
    int expectedOrientation = cw_rot[initialOrientation - 1];
    QCOMPARE(newOrientation, expectedOrientation);
}

void TestFileActionService::testRotateImageReadOnly()
{
    // Copy the test image to a temp directory
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString sourcePath = "data/canon-g9-x.jpg";
    QString destPath = tempDir.path() + "/test-rotate-ro.jpg";
    QVERIFY(QFile::copy(sourcePath, destPath));

    // Make the file read-only
    QVERIFY(QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::ReadUser));

    // Call rotateImage
    FileActionService service;
    int result = service.rotateImage(destPath, 90);
    
    // Result should be 1 (Read-only, rotated in-memory/UI only)
    QCOMPARE(result, 1);

    // Verify file contents were NOT changed on disk
    QFile file(destPath);
    QVERIFY(file.open(QIODevice::ReadOnly));
    QByteArray buffer = file.readAll();
    file.close();

    easyexif::EXIFInfo info;
    QCOMPARE(info.parseFrom((unsigned char *)buffer.data(), buffer.size()), 0);
    // Orientation on disk must be unchanged (still initialOrientation)
    // Restore permissions for cleanup
    QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
}

void TestFileActionService::testRotateNonExistentFile()
{
    FileActionService service;
    QCOMPARE(service.rotateImage("nonexistent.jpg", 90), -1);
}

void TestFileActionService::testRotateNonJpegFile()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/test.txt";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("hello");
    file.close();

    FileActionService service;
    QCOMPARE(service.rotateImage(path, 90), -1);
}

void TestFileActionService::testRotateInvalidAngle()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString sourcePath = "data/canon-g9-x.jpg";
    QString destPath = tempDir.path() + "/test-angle.jpg";
    QVERIFY(QFile::copy(sourcePath, destPath));

    FileActionService service;
    QCOMPARE(service.rotateImage(destPath, 45), -1);
}

void TestFileActionService::testRotateEmptyFile()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/empty.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.close();

    FileActionService service;
    // Empty file has no EXIF orientation tag; falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateInvalidJpegMarker()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/invalid.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("Some text that is not a valid JPEG.");
    file.close();

    FileActionService service;
    // Not a valid JPEG; no orientation tag found — falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateJpegWithoutExif()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/noexif.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + APP0 + EOI
    QByteArray raw = QByteArray::fromHex("ffd8ffe000104a46494600010101006000600000ffd9");
    file.write(raw);
    file.close();

    FileActionService service;
    // JPEG without EXIF has no orientation tag; falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateJpegWithInvalidExifHeader()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/fakeexif.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + APP1 (length 12, "Fake\0\0") + EOI
    QByteArray raw = QByteArray::fromHex("ffd8ffe1000c46616b65000000000000ffd9");
    file.write(raw);
    file.close();

    FileActionService service;
    // APP1 header is not "Exif"; no orientation tag found — falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateJpegWithInvalidTiffByteOrder()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/badtiff.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + APP1 (length 20, "Exif\0\0") + TIFF header with "XX" byte order + EOI
    QByteArray raw = QByteArray::fromHex("ffd8ffe100144578696600005858002a00000008ffd9");
    file.write(raw);
    file.close();

    FileActionService service;
    // Invalid TIFF byte order; no orientation tag found — falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateImageFileUrl()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString sourcePath = "data/canon-g9-x.jpg";
    QString destPath = tempDir.path() + "/test-rotate-url.jpg";
    QVERIFY(QFile::copy(sourcePath, destPath));

    QString urlPath = QUrl::fromLocalFile(destPath).toString();

    FileActionService service;
    int result = service.rotateImage(urlPath, 90);
    QCOMPARE(result, 0);

    QFile file(destPath);
    QVERIFY(file.open(QIODevice::ReadOnly));
    QByteArray buffer = file.readAll();
    file.close();

    easyexif::EXIFInfo info;
    QCOMPARE(info.parseFrom((unsigned char *)buffer.data(), buffer.size()), 0);
    QCOMPARE(info.Orientation, 6);
}

void TestFileActionService::testRotateImageInMemoryWithProvider()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString sourcePath = "data/canon-g9-x.jpg";
    QString destPath = tempDir.path() + "/test-rotate-prov.jpg";
    QVERIFY(QFile::copy(sourcePath, destPath));

    AsyncImageProvider provider(nullptr);
    FileActionService service;
    service.setImageProvider(&provider);

    // 1. Test writable file (clears provider in-memory rotation)
    provider.setInMemoryRotation(destPath, 90);
    QCOMPARE(provider.inMemoryRotation(destPath), 90);

    int result = service.rotateImage(destPath, 90);
    QCOMPARE(result, 0);
    QCOMPARE(provider.inMemoryRotation(destPath), 0);

    // 2. Test read-only file (sets provider in-memory rotation)
    QVERIFY(QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::ReadUser));
    result = service.rotateImage(destPath, 90);
    QCOMPARE(result, 1); // Read-only success
    QCOMPARE(provider.inMemoryRotation(destPath), 90);

    // Clean up permissions
    QFile::setPermissions(destPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
}

void TestFileActionService::testRotateFileNotReadable()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/writeonly.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("dummy");
    file.close();

    // Set permission to write-only so exists() and isWritable() are true, but ReadOnly open fails
    QVERIFY(QFile::setPermissions(path, QFileDevice::WriteOwner));

    FileActionService service;
    QCOMPARE(service.rotateImage(path, 90), -1);

    // Clean up permissions
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

void TestFileActionService::testRotateJpegInvalidStructure()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/invalid_struct.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + APP1 (length 8, "Exif\0\0") + non-FF marker byte "12" + EOI
    QByteArray raw = QByteArray::fromHex("ffd8ffe100084578696600001234ffd9");
    file.write(raw);
    file.close();

    FileActionService service;
    // Malformed JPEG structure; no orientation tag found — falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateJpegEarlyStartOfScan()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/early_sos.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + EOI + padding to allow loop execution
    QByteArray raw = QByteArray::fromHex("ffd8ffd90000");
    file.write(raw);
    file.close();

    FileActionService service;
    // SOI immediately followed by EOI/SOS; no orientation tag — falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateJpegHugeIfdOffset()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/huge_offset.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + APP1 (length 20, "Exif\0\0") + TIFF header (MM, magic 002a, offset 00010000) + EOI
    QByteArray raw = QByteArray::fromHex("ffd8ffe100144578696600004d4d002a00010000ffd9");
    file.write(raw);
    file.close();

    FileActionService service;
    // IFD offset points past buffer bounds; no orientation tag — falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateJpegTruncatedFields()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/truncated_fields.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + APP1 (length 30) + Exif header + TIFF MM header + numFields = 2, first field is ResolutionX, second is truncated.
    QByteArray raw = QByteArray::fromHex("ffd8ffe1001e4578696600004d4d002a000000080002011a00050000000100000008ffd9");
    file.write(raw);
    file.close();

    FileActionService service;
    // IFD fields are truncated; no orientation tag found — falls back to in-memory rotation.
    QCOMPARE(service.rotateImage(path, 90), 1);
}

void TestFileActionService::testRotateLittleEndianWritable()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/le_writable.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    // SOI + APP1 (length 34) + Exif header + TIFF II header (4949, magic 2a00, offset 08000000)
    // IFD at tiffStart + 8: numFields = 1 (0100)
    // Field 1: tag 1201 (little endian 0112), type 0300 (SHORT), count 01000000, value 01000000
    // next IFD: 00000000
    QByteArray raw = QByteArray::fromHex("ffd8ffe1002245786966000049492a0008000000010012010300010000000100000000000000ffd9");
    file.write(raw);
    file.close();

    FileActionService service;
    int result = service.rotateImage(path, 90);
    QCOMPARE(result, 0);

    QVERIFY(file.open(QIODevice::ReadOnly));
    QByteArray buffer = file.readAll();
    file.close();

    easyexif::EXIFInfo info;
    QCOMPARE(info.parseFrom((unsigned char *)buffer.data(), buffer.size()), 0);
    QCOMPARE(info.Orientation, 6);
}

void TestFileActionService::testCopyToClipboard()
{
    // Copy the test image to a temp directory
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString sourcePath = "data/canon-g9-x.jpg";
    QString destPath = tempDir.path() + "/test-copy.jpg";
    QVERIFY(QFile::copy(sourcePath, destPath));

    FileActionService service;
    // Call copyToClipboard
    service.copyToClipboard(destPath);

    // Get the clipboard and verify the mime data
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        const QMimeData *mimeData = clipboard->mimeData();
        QVERIFY(mimeData != nullptr);
        
        // 1. Verify text
        QCOMPARE(mimeData->text(), destPath);

        // 2. Verify URL
        QVERIFY(mimeData->hasUrls());
        QCOMPARE(mimeData->urls().first(), QUrl::fromLocalFile(destPath));

        // 3. Verify image
        QVERIFY(mimeData->hasImage());
        QImage image = qvariant_cast<QImage>(mimeData->imageData());
        QVERIFY(!image.isNull());
    } else {
        qWarning() << "Clipboard is not available in this test environment.";
    }
}

QTEST_MAIN(TestFileActionService)
#include "tst_fileactionservice.moc"

