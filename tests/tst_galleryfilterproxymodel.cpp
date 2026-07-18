#include <QtTest>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QFile>
#include <QDir>
#include "GalleryListModel.h"
#include "GalleryFilterProxyModel.h"
#include "ExifDatabase.h"

class TestGalleryFilterProxyModel : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testFiltering();
    void testVideoFiltering();
    void testSorting();
};

void TestGalleryFilterProxyModel::initTestCase()
{
    QCoreApplication::setOrganizationName("NinjaViewTest");
    QCoreApplication::setApplicationName("tst_galleryfilterproxymodel");
}

void TestGalleryFilterProxyModel::testFiltering()
{
    ExifDatabase db(":memory:");
    QVERIFY(db.init());
    QVERIFY(db.clear());

    GalleryListModel sourceModel;
    GalleryFilterProxyModel proxyModel;
    proxyModel.setSourceModel(&sourceModel);
    proxyModel.setDatabase(&db);

    // Prepare paths using QTemporaryDir
    QTemporaryDir tempDir(QDir::tempPath() + "/test_XXXXXX");
    QVERIFY(tempDir.isValid());
    QString folderPath = tempDir.path();
    QString fileToday = folderPath + "/today.jpg";
    QString fileOld = folderPath + "/old.jpg";
    QString filePng = folderPath + "/photo.png";

    // Write dummy files so their stats match reality
    QFile fToday(fileToday);
    QVERIFY(fToday.open(QIODevice::WriteOnly));
    fToday.write("today");
    fToday.close();

    QFile fOld(fileOld);
    QVERIFY(fOld.open(QIODevice::WriteOnly));
    fOld.write("old");
    fOld.close();

    QFile fPng(filePng);
    QVERIFY(fPng.open(QIODevice::WriteOnly));
    fPng.write("png");
    fPng.close();

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

    // Cache the data in db using actual file stats
    QFileInfo infoToday(fileToday);
    QFileInfo infoOld(fileOld);
    QFileInfo infoPng(filePng);
    QVERIFY(db.saveExifData(fileToday, infoToday.size(), infoToday.lastModified(), exifToday));
    QVERIFY(db.saveExifData(fileOld, infoOld.size(), infoOld.lastModified(), exifOld));
    QVERIFY(db.saveExifData(filePng, infoPng.size(), infoPng.lastModified(), exifPng));

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
    QVariantMap filters = db.getAvailableFiltersForFolder(folderPath);
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
    QStringList cameras = db.getUniqueCamerasForFolder(folderPath);
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

    // Test search functionality
    // 1. Match by filename (case-insensitive)
    proxyModel.setSearchQuery("TODAY");
    // "today.jpg" matches "TODAY". Folder name is "test_dir", so folder is filtered out.
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), fileToday);

    // 2. Match folder by name
    proxyModel.setSearchQuery("test");
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), folderPath);

    // 3. Match by notes
    QVERIFY(db.setNotes(fileOld, "special vacation photo"));
    proxyModel.setSearchQuery("special");
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), fileOld);

    // 4. Match by tags
    QVERIFY(db.setTags(filePng, "nature, waterfall, landscape"));
    proxyModel.setSearchQuery("land");
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), filePng);

    // 5. Combining search with filterType
    proxyModel.setSearchQuery("photo"); // "photo.png" matches filename, and notes of fileOld match "special vacation photo"
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(0), fileOld);
    QCOMPARE(proxyModel.getRawPath(1), filePng);

    proxyModel.setFilterType("JPG");
    // Should accept fileOld since it matches "photo" in notes and is a JPG (filePng is a PNG)
    QCOMPARE(proxyModel.rowCount(), 1);
    QCOMPARE(proxyModel.getRawPath(0), fileOld);

    // Reset filters
    proxyModel.setSearchQuery("");
    proxyModel.setFilterType("All");
    QCOMPARE(proxyModel.rowCount(), 4);

    // Test showNewOnly filter
    QSignalSpy showNewOnlySpy(&proxyModel, &GalleryFilterProxyModel::showNewOnlyChanged);
    QVERIFY(!proxyModel.showNewOnly());

    proxyModel.setShowNewOnly(true);
    QVERIFY(proxyModel.showNewOnly());
    QCOMPARE(showNewOnlySpy.count(), 1);

    // In db, fileToday, fileOld, filePng are already cached.
    // Let's add a new image file that is NOT cached (so it should be considered new).
    QString fileNew = folderPath + "/new_photo.jpg";
    QFile fNew(fileNew);
    QVERIFY(fNew.open(QIODevice::WriteOnly));
    fNew.write("new");
    fNew.close();

    sourceModel.addImages({fileNew});

    // With showNewOnly == true:
    // folderPath should be accepted (folders are always accepted, unless smart:// folder)
    // fileNew is not cached -> accepted
    // fileToday, fileOld, filePng are cached -> rejected
    // Total count should be 2: folderPath and fileNew
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(0), folderPath);
    QCOMPARE(proxyModel.getRawPath(1), fileNew);

    // Now, simulate background indexer indexing fileNew:
    QFileInfo infoNew(fileNew);
    QVERIFY(db.saveExifData(fileNew, infoNew.size(), infoNew.lastModified(), exifToday));
    // Since it's already in the session's m_newFiles set, calling invalidateFilter()
    // should still keep it visible under showNewOnly == true!
    proxyModel.setShowNewOnly(true);
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(1), fileNew);

    // Turn showNewOnly off
    proxyModel.setShowNewOnly(false);
    QCOMPARE(showNewOnlySpy.count(), 2);
    QCOMPARE(proxyModel.rowCount(), 5);
}

void TestGalleryFilterProxyModel::testVideoFiltering()
{
    ExifDatabase db(":memory:");
    QVERIFY(db.init());
    QVERIFY(db.clear());

    GalleryListModel sourceModel;
    GalleryFilterProxyModel proxyModel;
    proxyModel.setSourceModel(&sourceModel);
    proxyModel.setDatabase(&db);

    QString folderPath = "/tmp/test_video_dir";
    QString fileMp4 = "/tmp/test_video_dir/video.mp4";
    QString fileMov = "/tmp/test_video_dir/clip.mov";
    QString fileJpg = "/tmp/test_video_dir/photo.jpg";

    sourceModel.addFolders({folderPath});
    sourceModel.addImages({fileMp4, fileMov, fileJpg});

    // Total rowCount should be 4 (1 folder + 3 files)
    QCOMPARE(proxyModel.rowCount(), 4);

    // Filter by MP4
    proxyModel.setFilterType("MP4");
    // Should accept folder and video.mp4 (count = 2)
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(0), folderPath);
    QCOMPARE(proxyModel.getRawPath(1), fileMp4);
    QVERIFY(proxyModel.isVideo(1));
    QVERIFY(!proxyModel.isVideo(0));

    // Filter by MOV
    proxyModel.setFilterType("MOV");
    // Should accept folder and clip.mov (count = 2)
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(1), fileMov);
    QVERIFY(proxyModel.isVideo(1));

    // Filter by JPG
    proxyModel.setFilterType("JPG");
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(1), fileJpg);
    QVERIFY(!proxyModel.isVideo(1));

    // Test mediaTypeFilter
    proxyModel.setFilterType("All");
    proxyModel.setMediaTypeFilter("Photos");
    // Should accept folder and photo.jpg (count = 2)
    QCOMPARE(proxyModel.rowCount(), 2);
    QCOMPARE(proxyModel.getRawPath(1), fileJpg);

    proxyModel.setMediaTypeFilter("Videos");
    // Should accept folder, video.mp4 and clip.mov (count = 3)
    QCOMPARE(proxyModel.rowCount(), 3);
    QCOMPARE(proxyModel.getRawPath(1), fileMp4);
    QCOMPARE(proxyModel.getRawPath(2), fileMov);

    proxyModel.setMediaTypeFilter("All");
    QCOMPARE(proxyModel.rowCount(), 4);
}

void TestGalleryFilterProxyModel::testSorting()
{
    ExifDatabase db(":memory:");
    QVERIFY(db.init());
    QVERIFY(db.clear());

    GalleryListModel sourceModel;
    GalleryFilterProxyModel proxyModel;
    proxyModel.setSourceModel(&sourceModel);
    proxyModel.setDatabase(&db);

    QTemporaryDir tempDir(QDir::tempPath() + "/sort_XXXXXX");
    QVERIFY(tempDir.isValid());
    const QString folderPath = tempDir.path();

    // Files with deliberately "unsorted" insertion order, distinct sizes and mtimes
    const QString fileB = folderPath + "/b10.jpg"; // natural order: b2 < b10
    const QString fileA = folderPath + "/b2.jpg";
    const QString fileC = folderPath + "/alpha.png";

    auto writeFile = [](const QString &path, qint64 size) {
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly))
            return false;
        f.write(QByteArray(size, 'x'));
        f.close();
        return true;
    };
    QVERIFY(writeFile(fileB, 100));
    QVERIFY(writeFile(fileA, 300));
    QVERIFY(writeFile(fileC, 200));

    const QDateTime now = QDateTime::currentDateTime();
    auto setMtime = [&](const QString &path, const QDateTime &dt) {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly))
            return false;
        return f.setFileTime(dt, QFileDevice::FileModificationTime);
    };
    QVERIFY(setMtime(fileA, now.addDays(-1)));
    QVERIFY(setMtime(fileB, now.addDays(-2)));
    QVERIFY(setMtime(fileC, now.addDays(-3)));

    QVariantMap exifA, exifB, exifC;
    exifA["Dimensions"] = "1920x1080";
    exifB["Dimensions"] = "800x600";
    exifC["Dimensions"] = "1024x768";
    QVERIFY(db.saveExifData(fileA, 300, now.addDays(-1), exifA));
    QVERIFY(db.saveExifData(fileB, 100, now.addDays(-2), exifB));
    QVERIFY(db.saveExifData(fileC, 200, now.addDays(-3), exifC));

    sourceModel.addFolders({folderPath});
    sourceModel.addImages({fileB, fileA, fileC});

    // Initially unsorted: insertion order is preserved (folder, B, A, C)
    QCOMPARE(proxyModel.rowCount(), 4);
    QCOMPARE(proxyModel.getRawPath(1), fileB);

    // Invalid sort key is rejected and leaves state unchanged
    QSignalSpy sortBySpy(&proxyModel, &GalleryFilterProxyModel::sortByChanged);
    proxyModel.setSortBy("bogus");
    QCOMPARE(proxyModel.sortBy(), QString("name"));
    QCOMPARE(sortBySpy.count(), 0);

    // --- Name, ascending: folders first, then alpha with natural numeric order ---
    proxyModel.setSortBy("name");
    proxyModel.setSortOrder(Qt::AscendingOrder);
    qDebug() << "ORDER" << proxyModel.sortColumn() << proxyModel.sortOrder()
             << proxyModel.getRawPath(0) << proxyModel.getRawPath(1)
             << proxyModel.getRawPath(2) << proxyModel.getRawPath(3);
    qDebug() << "AGAIN" << proxyModel.getRawPath(0) << proxyModel.getRawPath(1)
             << proxyModel.getRawPath(2) << proxyModel.getRawPath(3);
    QCOMPARE(proxyModel.getRawPath(0), folderPath);
    QCOMPARE(proxyModel.getRawPath(1), fileC); // alpha.png
    QCOMPARE(proxyModel.getRawPath(2), fileA); // b2
    QCOMPARE(proxyModel.getRawPath(3), fileB); // b10

    // --- Name, descending: folders stay first, then reverse ---
    proxyModel.setSortOrder(Qt::DescendingOrder);
    QCOMPARE(proxyModel.getRawPath(0), folderPath);
    QCOMPARE(proxyModel.getRawPath(1), fileB);
    QCOMPARE(proxyModel.getRawPath(2), fileA);
    QCOMPARE(proxyModel.getRawPath(3), fileC);

    // --- Size ascending ---
    proxyModel.setSortBy("size");
    proxyModel.setSortOrder(Qt::AscendingOrder);
    QCOMPARE(proxyModel.getRawPath(1), fileB); // 100
    QCOMPARE(proxyModel.getRawPath(2), fileC); // 200
    QCOMPARE(proxyModel.getRawPath(3), fileA); // 300

    // --- Size descending ---
    proxyModel.setSortOrder(Qt::DescendingOrder);
    QCOMPARE(proxyModel.getRawPath(1), fileA); // 300
    QCOMPARE(proxyModel.getRawPath(2), fileC); // 200
    QCOMPARE(proxyModel.getRawPath(3), fileB); // 100

    // --- Date ascending (oldest first) ---
    proxyModel.setSortBy("date");
    proxyModel.setSortOrder(Qt::AscendingOrder);
    QCOMPARE(proxyModel.getRawPath(1), fileC); // -3 days
    QCOMPARE(proxyModel.getRawPath(2), fileB); // -2 days
    QCOMPARE(proxyModel.getRawPath(3), fileA); // -1 day

    // --- Date descending (newest first) ---
    proxyModel.setSortOrder(Qt::DescendingOrder);
    QCOMPARE(proxyModel.getRawPath(1), fileA);
    QCOMPARE(proxyModel.getRawPath(2), fileB);
    QCOMPARE(proxyModel.getRawPath(3), fileC);

    // --- Dimensions ascending ---
    proxyModel.setSortBy("dimensions");
    proxyModel.setSortOrder(Qt::AscendingOrder);
    QCOMPARE(proxyModel.getRawPath(1), fileB); // 800x600
    QCOMPARE(proxyModel.getRawPath(2), fileC); // 1024x768
    QCOMPARE(proxyModel.getRawPath(3), fileA); // 1920x1080

    // --- Dimensions descending ---
    proxyModel.setSortOrder(Qt::DescendingOrder);
    QCOMPARE(proxyModel.getRawPath(1), fileA);
    QCOMPARE(proxyModel.getRawPath(2), fileC);
    QCOMPARE(proxyModel.getRawPath(3), fileB);

    // --- New roles are exposed on the proxy (filered from the source model) ---
    QModelIndex firstFile = proxyModel.index(1, 0);
    QCOMPARE(proxyModel.data(firstFile, GalleryListModel::FileSizeRole).toLongLong(), qint64(300));
    QVERIFY(proxyModel.data(firstFile, GalleryListModel::LastModifiedRole).toDateTime().isValid());

    // Reset to a clean sorted state for any test that runs afterwards
    proxyModel.setSortBy("name");
    proxyModel.setSortOrder(Qt::AscendingOrder);
}

QTEST_MAIN(TestGalleryFilterProxyModel)
#include "tst_galleryfilterproxymodel.moc"
