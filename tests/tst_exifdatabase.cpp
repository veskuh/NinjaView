#include <QtTest>
#include <QSignalSpy>
#include <QTemporaryDir>
#include "ExifDatabase.h"

class TestExifDatabase : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testDatabaseOperations();
    void testBatchOperations();
};

void TestExifDatabase::initTestCase()
{
    QCoreApplication::setOrganizationName("NinjaViewTest");
    QCoreApplication::setApplicationName("tst_exifdatabase");
}

void TestExifDatabase::testDatabaseOperations()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString tempDbPath = tempDir.path() + "/test_exif.db";
    ExifDatabase db(tempDbPath);
    QVERIFY(db.init());

    QString filePath = "/tmp/fake_image.jpg";
    qint64 fileSize = 12345;
    QDateTime lastModified = QDateTime::currentDateTime();

    // Check uncached
    QVERIFY(!db.isCached(filePath, fileSize, lastModified));

    // Save data
    QVariantMap exif;
    exif["Make"] = "Canon";
    exif["Model"] = "EOS R5";
    exif["Lens"] = "RF 24-70mm f/2.8L IS USM";
    exif["Exposure"] = "1/125s";
    exif["Aperture"] = "f/2.8";
    exif["ISO"] = 400;
    exif["DateTime"] = "2026:05:30 12:00:00";
    exif["Duration"] = "5s";

    QVERIFY(db.saveExifData(filePath, fileSize, lastModified, exif));

    // Check cached
    QVERIFY(db.isCached(filePath, fileSize, lastModified));

    // Check cached with wrong file size (should return false)
    QVERIFY(!db.isCached(filePath, 99999, lastModified));

    // Check cached with wrong modified date (should return false)
    QVERIFY(!db.isCached(filePath, fileSize, lastModified.addDays(1)));

    // Retrieve data and assert values
    QVariantMap retrieved = db.getExifData(filePath);
    QCOMPARE(retrieved.value("Make").toString(), QString("Canon"));
    QCOMPARE(retrieved.value("Model").toString(), QString("EOS R5"));
    QCOMPARE(retrieved.value("Lens").toString(), QString("RF 24-70mm f/2.8L IS USM"));
    QCOMPARE(retrieved.value("Exposure").toString(), QString("1/125s"));
    QCOMPARE(retrieved.value("Aperture").toString(), QString("f/2.8"));
    QCOMPARE(retrieved.value("ISO").toInt(), 400);
    QCOMPARE(retrieved.value("DateTime").toString(), QString("2026:05:30 12:00:00"));
    QCOMPARE(retrieved.value("Duration").toString(), QString("5s"));

    // Test favorite, notes, tags
    QSignalSpy favSpy(&db, &ExifDatabase::favoritesChanged);
    QSignalSpy notesSpy(&db, &ExifDatabase::notesChanged);
    QSignalSpy tagsSpy(&db, &ExifDatabase::tagsChanged);

    // Initial state checks
    QVERIFY(!db.isFavorite(filePath));
    QCOMPARE(db.getNotes(filePath), QString(""));
    QCOMPARE(db.getTags(filePath), QString(""));

    // Set favorite
    QVERIFY(db.setFavorite(filePath, true));
    QCOMPARE(favSpy.count(), 1);
    QVERIFY(db.isFavorite(filePath));

    // Set notes
    QVERIFY(db.setNotes(filePath, "Testing notes"));
    QCOMPARE(notesSpy.count(), 1);
    QCOMPARE(db.getNotes(filePath), QString("Testing notes"));

    // Set tags (ensure whitespace cleaning and comma normalization)
    QVERIFY(db.setTags(filePath, "nature, vacation, water"));
    QCOMPARE(tagsSpy.count(), 1);
    QCOMPARE(db.getTags(filePath), QString("nature,vacation,water"));

    // Verify tag listings and dynamic tag retrieval
    QStringList allTags = db.getAllTags();
    QCOMPARE(allTags.count(), 3);
    QVERIFY(allTags.contains("nature"));
    QVERIFY(allTags.contains("vacation"));
    QVERIFY(allTags.contains("water"));

    // Verify favorite lists
    QStringList favs = db.getFavorites();
    QCOMPARE(favs.count(), 1);
    QCOMPARE(favs.first(), filePath);

    // Verify tag matching queries (SQL csv matching)
    QCOMPARE(db.getImagesWithTag("vacation").count(), 1);
    QCOMPARE(db.getImagesWithTag("nature").count(), 1);
    QCOMPARE(db.getImagesWithTag("water").count(), 1);
    QCOMPARE(db.getImagesWithTag("something_else").count(), 0);

    // CRITICAL: Verify EXIF updates preserve custom metadata
    QVariantMap updatedExif = exif;
    updatedExif["Exposure"] = "1/250s";
    QVERIFY(db.saveExifData(filePath, fileSize, lastModified, updatedExif));

    // Ensure custom fields are preserved!
    QVERIFY(db.isFavorite(filePath));
    QCOMPARE(db.getNotes(filePath), QString("Testing notes"));
    QCOMPARE(db.getTags(filePath), QString("nature,vacation,water"));

    // Ensure EXIF field was updated
    QCOMPARE(db.getExifData(filePath).value("Exposure").toString(), QString("1/250s"));

    // Test clear database
    QVERIFY(db.clear());
    QCOMPARE(favSpy.count(), 2);
    QCOMPARE(notesSpy.count(), 2);
    QCOMPARE(notesSpy.last().at(0).toString(), QString(""));
    QCOMPARE(tagsSpy.count(), 2);

    QVERIFY(!db.isCached(filePath, fileSize, lastModified));
    QVERIFY(db.getExifData(filePath).isEmpty());
}

void TestExifDatabase::testBatchOperations()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString tempDbPath = tempDir.path() + "/test_exif_batch.db";
    ExifDatabase db(tempDbPath);
    QVERIFY(db.init());

    QStringList paths = { "/tmp/img1.jpg", "/tmp/img2.jpg", "/tmp/img3.jpg" };
    
    // Test favorite batch
    QSignalSpy favSpy(&db, &ExifDatabase::favoritesChanged);
    QVERIFY(db.setFavoriteBatch(paths, true));
    QCOMPARE(favSpy.count(), 1);
    QVERIFY(db.isFavorite(paths[0]));
    QVERIFY(db.isFavorite(paths[1]));
    QVERIFY(db.isFavorite(paths[2]));

    // Test favorite batch back to false
    QVERIFY(db.setFavoriteBatch(paths, false));
    QVERIFY(!db.isFavorite(paths[0]));

    // Test tags batch (overwrite mode)
    QSignalSpy tagsSpy(&db, &ExifDatabase::tagsChanged);
    QVERIFY(db.setTagsBatch(paths, "holiday, beach", false));
    QCOMPARE(tagsSpy.count(), 1);
    QCOMPARE(db.getTags(paths[0]), QString("holiday,beach"));
    QCOMPARE(db.getTags(paths[1]), QString("holiday,beach"));

    // Test tags batch (append mode)
    QVERIFY(db.setTagsBatch(paths, "sun, beach", true));
    QString tags0 = db.getTags(paths[0]);
    QVERIFY(tags0.contains("holiday"));
    QVERIFY(tags0.contains("beach"));
    QVERIFY(tags0.contains("sun"));
    
    // Test notes batch (overwrite mode)
    QSignalSpy notesSpy(&db, &ExifDatabase::notesChanged);
    QVERIFY(db.setNotesBatch(paths, "Batch notes", false));
    QCOMPARE(notesSpy.count(), 1);
    QCOMPARE(db.getNotes(paths[0]), QString("Batch notes"));

    // Test notes batch (append mode)
    QVERIFY(db.setNotesBatch(paths, "Appended notes", true));
    QCOMPARE(db.getNotes(paths[0]), QString("Batch notes\nAppended notes"));
}

QTEST_MAIN(TestExifDatabase)
#include "tst_exifdatabase.moc"
