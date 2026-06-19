#include <QtTest>
#include <QTemporaryDir>
#include <QStandardPaths>
#include <QFile>
#include "ExifReader.h"
#include "ExifDatabase.h"

/// @brief Tests for ExifReader EXIF metadata extraction.
class TestExifReader : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testNonExistentFile();
    void testDirectoryPath();
    void testEmptyFile();
    void testInvalidFile();
    void testUnreadableFile();
    void testRealImages();
    void testVideoParsing();
    void testWithDatabaseSaveAndCacheHit();
    void testExifReaderExtraCoverage();
    void testVideoHeaderEndAndVersions();
    void testCacheBackfillComplex();
    void testEXIFLensFallbacks();
    void cleanupTestCase();
};

void TestExifReader::initTestCase()
{
    QStandardPaths::setTestModeEnabled(true);
}

void TestExifReader::cleanupTestCase()
{
    QStandardPaths::setTestModeEnabled(false);
}

void TestExifReader::testNonExistentFile()
{
    ExifReader reader;
    QVariantMap data = reader.getExifData("data/nothing.jpg");
    QVERIFY(data.isEmpty());
}

void TestExifReader::testDirectoryPath()
{
    // Passing a directory path should return empty data
    ExifReader reader;
    QVariantMap data = reader.getExifData("data");
    QVERIFY(data.isEmpty());
}

void TestExifReader::testEmptyFile()
{
    QTemporaryDir tempDir;
    QString path = tempDir.path() + "/empty.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.close();

    ExifReader reader;
    QVariantMap data = reader.getExifData(path);
    QCOMPARE(data["FileSize"].toString(), "0 B");
    QVERIFY(!data.contains("Dimensions"));
}

void TestExifReader::testInvalidFile()
{
    QTemporaryDir tempDir;
    QString path = tempDir.path() + "/invalid.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("Not a JPEG at all, just some text.");
    file.close();

    ExifReader reader;
    QVariantMap data = reader.getExifData(path);
    QCOMPARE(data["FileSize"].toString(), "34 B");
    QVERIFY(!data.contains("Dimensions"));
}

void TestExifReader::testUnreadableFile()
{
    QTemporaryDir tempDir;
    QString path = tempDir.path() + "/noperm.jpg";
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("dummy");
    file.close();

    // Remove read permission
    QVERIFY(QFile::setPermissions(path, QFileDevice::WriteOwner));

    ExifReader reader;
    QVariantMap data = reader.getExifData(path);
    QCOMPARE(data["FileSize"].toString(), "5 B");
    QVERIFY(!data.contains("Dimensions"));

    // Restore permissions for cleanup
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
}

void TestExifReader::testRealImages()
{
    ExifReader reader;
    QStringList images = {
        "data/canon-g9-x.jpg",
        "data/fuji-xt30-18-55F28-4.jpeg",
        "data/iphone-15.jpeg",
        "data/DJI_0877.JPG"
    };

    for (const QString &img : images) {
        QFile file(img);
        QVERIFY2(file.exists(), qPrintable(QString("Test image missing: %1").arg(img)));
        
        QVariantMap data = reader.getExifData(img);
        QVERIFY2(!data.isEmpty(), qPrintable(QString("Failed to extract EXIF from %1").arg(img)));
        
        // Basic common keys
        QVERIFY(data.contains("Make"));
        QVERIFY(data.contains("Model"));
        QVERIFY(data.contains("Exposure"));
        QVERIFY(data.contains("Aperture"));
        QVERIFY(data.contains("ISO"));
        QVERIFY(data.contains("Dimensions"));
        QVERIFY(data.contains("FileSize"));
        
        // Robust check for unprintable characters in all string keys
        for (auto it = data.constBegin(); it != data.constEnd(); ++it) {
            if (it.value().typeId() == QMetaType::QString) {
                QString val = it.value().toString();
                for (const QChar &c : val) {
                    QVERIFY2(c.isPrint(), qPrintable(QString("Found unprintable char in file %1 key %2: %3")
                                                     .arg(img).arg(it.key()).arg(val)));
                }
            }
        }
        
        qDebug() << "Image:" << img;
        qDebug() << "  Make:" << data["Make"].toString();
        qDebug() << "  Model:" << data["Model"].toString();
        qDebug() << "  Lens:" << data["Lens"].toString();
    }
}

void TestExifReader::testVideoParsing()
{
    ExifReader reader;
    QVariantMap data = reader.getExifData("data/test.mp4");
    QVERIFY2(!data.isEmpty(), "test.mp4 EXIF data should not be empty");
    QCOMPARE(data["IsVideo"].toBool(), true);
    QCOMPARE(data["Dimensions"].toString(), "160x120");
    QCOMPARE(data["Duration"].toString(), "1s");
    QCOMPARE(data["Model"].toString(), "MPEG-4 Video (ISOM)");
    QCOMPARE(data["Make"].toString(), "Video File");
    QVERIFY(data.contains("DateTime"));
}

void TestExifReader::testWithDatabaseSaveAndCacheHit()
{
    // Use a fresh database by clearing first
    ExifDatabase db(":memory:");
    QVERIFY(db.init());
    QVERIFY(db.clear());

    ExifReader reader;
    reader.setDatabase(&db);

    // First call: parses the file, saves to DB (exercises lines 109-110)
    QVariantMap data1 = reader.getExifData("data/canon-g9-x.jpg");
    QVERIFY(!data1.isEmpty());
    QVERIFY(data1.contains("Make"));

    // Verify the data was cached
    QFileInfo fi("data/canon-g9-x.jpg");
    QVERIFY(db.isCached("data/canon-g9-x.jpg", fi.size(), fi.lastModified()));

    // Second call: should hit cache (exercises line 42)
    QVariantMap data2 = reader.getExifData("data/canon-g9-x.jpg");
    QVERIFY(!data2.isEmpty());

    // Cached data should match original
    QCOMPARE(data2["Make"].toString(), data1["Make"].toString());
    QCOMPARE(data2["Model"].toString(), data1["Model"].toString());
    QCOMPARE(data2["ISO"].toInt(), data1["ISO"].toInt());
}

void TestExifReader::testExifReaderExtraCoverage()
{
    ExifDatabase db(":memory:");
    QVERIFY(db.init());
    QVERIFY(db.clear());

    ExifReader reader;
    reader.setDatabase(&db);

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    // 1. File size >= 1MB formatting path
    QString path1 = tempDir.path() + "/large.jpg";
    QFile file1(path1);
    QVERIFY(file1.open(QIODevice::WriteOnly));
    QByteArray dummyData(1.2 * 1024 * 1024, 'A');
    QVERIFY(file1.write(dummyData) > 0);
    file1.close();

    QVariantMap data1 = reader.getExifData(path1);
    QCOMPARE(data1["FileSize"].toString(), "1.20 MB");
    QVERIFY(db.isCached(path1, dummyData.size(), QFileInfo(path1).lastModified()));

    // 2. Database save on unreadable file path
    QString path2 = tempDir.path() + "/noperm_db.jpg";
    QFile file2(path2);
    QVERIFY(file2.open(QIODevice::WriteOnly));
    file2.write("dummy");
    file2.close();
    QVERIFY(QFile::setPermissions(path2, QFileDevice::WriteOwner));

    QVariantMap data2 = reader.getExifData(path2);
    QCOMPARE(data2["FileSize"].toString(), "5 B");
    QVERIFY(db.isCached(path2, 5, QFileInfo(path2).lastModified()));
    QFile::setPermissions(path2, QFileDevice::ReadOwner | QFileDevice::WriteOwner);

    // 3. Database save on un-parsable (invalid JPEG) file path
    QString path3 = tempDir.path() + "/invalid_db.jpg";
    QFile file3(path3);
    QVERIFY(file3.open(QIODevice::WriteOnly));
    file3.write("invalid jpeg content");
    file3.close();

    QVariantMap data3 = reader.getExifData(path3);
    QCOMPARE(data3["FileSize"].toString(), "20 B");
    QVERIFY(db.isCached(path3, 20, QFileInfo(path3).lastModified()));

    // 4. Backfill dimensions path
    QString path4 = tempDir.path() + "/real_backfill.jpg";
    QVERIFY(QFile::copy("data/canon-g9-x.jpg", path4));
    QFileInfo fi4(path4);

    QVariantMap dataManual;
    dataManual["Make"] = "ManualMake";
    dataManual["Model"] = "ManualModel";
    QVERIFY(db.saveExifData(path4, fi4.size(), fi4.lastModified(), dataManual));

    QVariantMap dataBackfilled = reader.getExifData(path4);
    QCOMPARE(dataBackfilled["Make"].toString(), "ManualMake");
    QVERIFY(!dataBackfilled["Dimensions"].toString().isEmpty());
    QVERIFY(!dataBackfilled["DateTime"].toString().isEmpty());
}

void TestExifReader::testVideoHeaderEndAndVersions()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString path = tempDir.path() + "/mock_video.mp4";

    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));

    // 1. Write ftyp box at the very beginning
    QByteArray firstHeader;
    firstHeader.append("\x00\x00\x00\x14""ftypmp41\x00\x00\x00\x00mp41", 20);
    QVERIFY(file.write(firstHeader) > 0);

    // 2. Write 130KB of padding to make sure the remainder is NOT in the first 128KB
    QByteArray padding(130 * 1024, 'A');
    QVERIFY(file.write(padding) > 0);

    // 3. Write mvhd and tkhd headers at the end
    QByteArray header;
    // mvhd box Version 1 (64-bit timestamps and duration)
    // Structure:
    // 4 bytes: size (120 bytes -> \x00\x00\x00\x78)
    // 4 bytes: "mvhd"
    // 1 byte: version = 1 (\x01)
    // 3 bytes: flags (\x00\x00\x00)
    // 8 bytes: creation time (64-bit)
    // 8 bytes: modification time (64-bit)
    // 4 bytes: timescale (32-bit, e.g. 1000 -> \x00\x00\x03\xe8)
    // 8 bytes: duration (64-bit, e.g., 3600000 ms -> 1 hour -> \x00\x00\x00\x00\x00\x36\xee\x80)
    header.append("\x00\x00\x00\x78""mvhd", 8);
    header.append("\x01\x00\x00\x00", 4); // version 1, flags 0
    header.append("\x00\x00\x00\x00\x00\x00\x00\x05", 8); // creation time
    header.append("\x00\x00\x00\x00\x00\x00\x00\x05", 8); // modification time
    header.append("\x00\x00\x03\xe8", 4); // timescale 1000
    header.append("\x00\x00\x00\x00\x00\x36\xee\x80", 8); // duration 3600000 (1 hour)
    // Pad remaining mvhd box up to 120 bytes
    header.append(QByteArray(120 - 8 - 4 - 8 - 8 - 4 - 8, '\x00'));

    // tkhd box Version 1 (64-bit dimensions)
    // Structure:
    // 4 bytes: size (150 bytes -> \x00\x00\x00\x96)
    // 4 bytes: "tkhd"
    // 1 byte: version = 1 (\x01)
    // 3 bytes: flags (\x00\x00\x00)
    // 84 bytes of padding (so that width starts at offset 92 from start of tkhd, i.e. offset 88 from version)
    // 4 bytes: width (fixed point 16.16 -> 1920 -> \x07\x80\x00\x00)
    // 4 bytes: height (fixed point 16.16 -> 1080 -> \x04\x38\x00\x00)
    header.append("\x00\x00\x00\x96""tkhd", 8);
    header.append("\x01\x00\x00\x00", 4); // version 1
    header.append(QByteArray(84, '\x00'));
    header.append("\x07\x80\x00\x00", 4); // 1920
    header.append("\x04\x38\x00\x00", 4); // 1080
    // Pad remainder
    header.append(QByteArray(150 - 8 - 4 - 84 - 8, '\x00'));

    QVERIFY(file.write(header) > 0);
    file.close();

    ExifReader reader;
    QVariantMap data = reader.getExifData(path);
    QCOMPARE(data["Make"].toString(), QString("Video File"));
    QCOMPARE(data["Model"].toString(), QString("MPEG-4 Video (MP4 v1)"));
    QCOMPARE(data["Dimensions"].toString(), QString("1920x1080"));
    QCOMPARE(data["Duration"].toString(), QString("1h 00m"));
}

void TestExifReader::testCacheBackfillComplex()
{
    ExifDatabase db(":memory:");
    QVERIFY(db.init());

    ExifReader reader;
    reader.setDatabase(&db);

    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    // 1. Mock Video file with partial cached record (missing Dimensions, Duration, and Model)
    QString videoPath = tempDir.path() + "/backfill_video.mp4";
    QFile vfile(videoPath);
    QVERIFY(vfile.open(QIODevice::WriteOnly));
    QByteArray vheader;
    vheader.append("\x00\x00\x00\x14""ftypqt  \x00\x00\x00\x00qt  ", 20);
    
    // mvhd version 0
    vheader.append("\x00\x00\x00\x6c""mvhd", 8);
    vheader.append("\x00\x00\x00\x00", 4); // version 0
    vheader.append("\x00\x00\x00\x05", 4); // creationSeconds
    vheader.append("\x00\x00\x00\x05", 4); // modificationSeconds
    vheader.append("\x00\x00\x03\xe8", 4); // timescale 1000
    vheader.append("\x00\x00\x13\x88", 4); // duration 5000 (5s)
    vheader.append(QByteArray(120 - 8 - 4 - 4 - 4 - 4 - 4, '\x00')); // remainder
    
    // tkhd version 0
    // Width starts at offset 84 from tkhd start (offset 76 from version)
    // Size (4) + Type (4) + Version/Flags (4) = 12 bytes.
    // Padding should be 84 - 12 = 72 bytes.
    vheader.append("\x00\x00\x00\x96""tkhd", 8);
    vheader.append("\x00\x00\x00\x00", 4); // version 0
    vheader.append(QByteArray(72, '\x00')); // padding
    vheader.append("\x02\x80\x00\x00", 4); // 640
    vheader.append("\x01\xe0\x00\x00", 4); // 480
    vheader.append(QByteArray(150 - 8 - 4 - 72 - 8, '\x00'));
    QVERIFY(vfile.write(vheader) > 0);
    vfile.close();

    QFileInfo vfi(videoPath);
    QVariantMap cachedVideo;
    cachedVideo["FileSize"] = "1.5 KB";
    QVERIFY(db.saveExifData(videoPath, vfi.size(), vfi.lastModified(), cachedVideo));

    // Call getExifData - should hit cache and backfill missing fields from the video file
    QVariantMap backfilledVideo = reader.getExifData(videoPath);
    QCOMPARE(backfilledVideo["Dimensions"].toString(), QString("640x480"));
    QCOMPARE(backfilledVideo["Duration"].toString(), QString("5s"));
    QCOMPARE(backfilledVideo["Model"].toString(), QString("QuickTime Movie (MOV)"));

    // 2. Photo file with partial cached record (missing Dimensions and DateTime)
    QString photoPath = tempDir.path() + "/backfill_photo.jpg";
    QVERIFY(QFile::copy("data/canon-g9-x.jpg", photoPath));
    QFileInfo pfi(photoPath);

    QVariantMap cachedPhoto;
    cachedPhoto["FileSize"] = "1.2 MB";
    cachedPhoto["Make"] = "MockMake";
    QVERIFY(db.saveExifData(photoPath, pfi.size(), pfi.lastModified(), cachedPhoto));

    // Call getExifData - should hit cache and backfill missing photo dimensions and timestamp
    QVariantMap backfilledPhoto = reader.getExifData(photoPath);
    QCOMPARE(backfilledPhoto["Make"].toString(), QString("MockMake"));
    QVERIFY(!backfilledPhoto["Dimensions"].toString().isEmpty());
    QVERIFY(!backfilledPhoto["DateTime"].toString().isEmpty());
}

void TestExifReader::testEXIFLensFallbacks()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString testJpg = tempDir.path() + "/lens_fallback.jpg";
    QVERIFY(QFile::copy("data/fuji-xt30-18-55F28-4.jpeg", testJpg));

    // Read fuji image, find LensModel string and replace it with null bytes
    QFile file(testJpg);
    QVERIFY(file.open(QIODevice::ReadWrite));
    QByteArray buffer = file.readAll();
    
    // Fuji X-T30 writes "XF18-55mmF2.8-4 R LM OIS" in EXIF
    int idx = buffer.indexOf("XF18-55mmF2.8-4 R LM OIS");
    if (idx != -1) {
        for (int i = 0; i < 24; ++i) {
            buffer[idx + i] = 0;
        }
    }
    // Also zero out manufacturer "FUJIFILM" to make LensMake empty
    int idx2 = 0;
    while ((idx2 = buffer.indexOf("FUJIFILM", idx2)) != -1) {
        for (int i = 0; i < 8; ++i) {
            buffer[idx2 + i] = 0;
        }
        idx2 += 8;
    }
    file.seek(0);
    QVERIFY(file.write(buffer) > 0);
    file.close();

    ExifReader reader;
    QVariantMap data = reader.getExifData(testJpg);
    
    // LensModel was zeroed out, so it must fall back to the min/max specifications in rational tags
    QString lensInfo = data["Lens"].toString();
    QVERIFY(!lensInfo.isEmpty());
    QVERIFY(lensInfo.contains("18-55mm"));
    QVERIFY(lensInfo.contains("f/2.8-4"));
}

QTEST_MAIN(TestExifReader)
#include "tst_exifreader.moc"
