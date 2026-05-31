#include <QtTest>
#include <QSignalSpy>
#include <QTemporaryDir>
#include "GalleryListModel.h"
#include "GalleryFilterProxyModel.h"
#include "ExifDatabase.h"

class TestGalleryFilterProxyModel : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testFiltering();
};

void TestGalleryFilterProxyModel::initTestCase()
{
    QCoreApplication::setOrganizationName("NinjaViewTest");
    QCoreApplication::setApplicationName("tst_galleryfilterproxymodel");
}

void TestGalleryFilterProxyModel::testFiltering()
{
    ExifDatabase db;
    QVERIFY(db.init());
    QVERIFY(db.clear());

    GalleryListModel sourceModel;
    GalleryFilterProxyModel proxyModel;
    proxyModel.setSourceModel(&sourceModel);
    proxyModel.setDatabase(&db);

    // Prepare paths
    QString folderPath = "/tmp/test_dir";
    QString fileToday = "/tmp/test_dir/today.jpg";
    QString fileOld = "/tmp/test_dir/old.jpg";
    QString filePng = "/tmp/test_dir/photo.png";

    // Setup EXIF data in DB
    QDateTime now = QDateTime::currentDateTime();
    QDateTime oldDate = now.addDays(-15);

    QVariantMap exifToday;
    exifToday["Make"] = "Canon";
    exifToday["Model"] = "EOS R5";
    exifToday["DateTime"] = now.toString("yyyy:MM:dd HH:mm:ss");

    QVariantMap exifOld;
    exifOld["Make"] = "Sony";
    exifOld["Model"] = "A7RIV";
    exifOld["DateTime"] = oldDate.toString("yyyy:MM:dd HH:mm:ss");

    QVariantMap exifPng;
    exifPng["Make"] = "Apple";
    exifPng["Model"] = "iPhone 15";
    exifPng["DateTime"] = now.toString("yyyy:MM:dd HH:mm:ss");

    // Cache the data in db
    QVERIFY(db.saveExifData(fileToday, 1000, now, exifToday));
    QVERIFY(db.saveExifData(fileOld, 2000, oldDate, exifOld));
    QVERIFY(db.saveExifData(filePng, 3000, now, exifPng));

    // Populate source model: 1 folder, 3 files
    sourceModel.addFolders({folderPath});
    sourceModel.addImages({fileToday, fileOld, filePng});

    // Verify initial count (folders are always accepted, so 1 folder + 3 files = 4)
    QCOMPARE(proxyModel.rowCount(), 4);

    // Test "All" filter
    proxyModel.setFilterType("All");
    QCOMPARE(proxyModel.rowCount(), 4);

    // Test "Today" filter
    proxyModel.setFilterType("Today");
    // Should accept folder and today's JPG + PNG (count = 3)
    QCOMPARE(proxyModel.rowCount(), 3);
    QCOMPARE(proxyModel.getRawPath(0), folderPath);
    QCOMPARE(proxyModel.getRawPath(1), fileToday);
    QCOMPARE(proxyModel.getRawPath(2), filePng);

    // Test "This Week" filter
    proxyModel.setFilterType("This Week");
    // Should accept folder, today's JPG and PNG (count = 3)
    QCOMPARE(proxyModel.rowCount(), 3);

    // Test "This Month" filter
    proxyModel.setFilterType("This Month");
    // Depending on when the test runs, now and now-15 might be in the same month
    if (now.date().month() == oldDate.date().month() && now.date().year() == oldDate.date().year()) {
        QCOMPARE(proxyModel.rowCount(), 4);
    } else {
        QCOMPARE(proxyModel.rowCount(), 3);
    }

    // Test getAvailableFiltersForFolder
    QVariantMap filters = db.getAvailableFiltersForFolder("/tmp/test_dir");
    QVERIFY(filters.value("hasToday").toBool());
    QVERIFY(filters.value("hasThisWeek").toBool());
    
    QStringList yearsList = filters.value("years").toStringList();
    QVERIFY(yearsList.contains(QString::number(now.date().year())));
    QVERIFY(yearsList.contains(QString::number(oldDate.date().year())));

    QStringList typesList = filters.value("imageTypes").toStringList();
    QVERIFY(typesList.contains("JPG"));
    QVERIFY(typesList.contains("PNG"));

    // Test year filtering
    proxyModel.setFilterType(QString::number(oldDate.date().year()));
    // Should match at least the old image and folder (count >= 2)
    QVERIFY(proxyModel.rowCount() >= 2);

    // Test image type filtering: PNG
    proxyModel.setFilterType("PNG");
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(1), filePng);

    // Test image type filtering: JPG
    proxyModel.setFilterType("JPG");
    QCOMPARE(proxyModel.rowCount(), 3);
    QCOMPARE(proxyModel.getRawPath(1), fileToday);
    QCOMPARE(proxyModel.getRawPath(2), fileOld);
    
    // Test "Camera" filter
    proxyModel.setFilterType("Camera");
    proxyModel.setCameraFilter("Canon EOS R5");
    // Should accept folder and Canon image (count = 2)
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(1), fileToday);

    // Test "Camera" filter with non-matching camera
    proxyModel.setCameraFilter("Nikon Z7");
    // Should accept folder only (count = 1)
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), folderPath);

    // Test camera query
    QStringList cameras = db.getUniqueCamerasForFolder("/tmp/test_dir");
    QVERIFY(cameras.contains("Canon EOS R5"));
    QVERIFY(cameras.contains("Sony A7RIV"));
    QVERIFY(cameras.contains("Apple iPhone 15"));
    QCOMPARE(cameras.count(), 3);

    // Test smart folder filtering
    QObject::connect(&db, &ExifDatabase::favoritesChanged,
                     &proxyModel, &GalleryFilterProxyModel::invalidateFilter);
    QObject::connect(&db, &ExifDatabase::tagsChanged,
                     &proxyModel, &GalleryFilterProxyModel::invalidateFilter);

    // Filter to smart favorites
    proxyModel.setFilterType("All"); // Reset filter type
    proxyModel.setCurrentFolderPath("smart://favorites");
    // Should accept no files (since no favorite images yet)
    QCOMPARE(proxyModel.rowCount(), 0);

    // Favorite fileToday
    QVERIFY(db.setFavorite(fileToday, true));
    // Verify it automatically updates proxy model rowCount to 1 (fileToday)
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), fileToday);

    // Favorite fileOld as well
    QVERIFY(db.setFavorite(fileOld, true));
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(1), fileOld);

    // Unfavorite fileToday
    QVERIFY(db.setFavorite(fileToday, false));
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), fileOld);

    // Test smart tags filtering
    proxyModel.setCurrentFolderPath("smart://tag/vacation");
    // Should accept no files
    QCOMPARE(proxyModel.rowCount(), 0);

    // Tag fileOld with "vacation, nature"
    QVERIFY(db.setTags(fileOld, "vacation, nature"));
    // Verify it updates and accepts fileOld
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), fileOld);

    // Change to tag "nature"
    proxyModel.setCurrentFolderPath("smart://tag/nature");
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), fileOld);

    // Change to tag "party" (non-matching)
    proxyModel.setCurrentFolderPath("smart://tag/party");
    QCOMPARE(proxyModel.rowCount(), 0);

    // Reset currentFolderPath to empty/normal
    proxyModel.setCurrentFolderPath("");
    QCOMPARE(proxyModel.rowCount(), 4);
}

QTEST_MAIN(TestGalleryFilterProxyModel)
#include "tst_galleryfilterproxymodel.moc"
