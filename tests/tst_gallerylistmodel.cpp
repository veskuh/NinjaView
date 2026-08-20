#include <QtTest>
#include <QSignalSpy>
#include "GalleryListModel.h"

class TestGalleryListModel : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testInitialData();
    void testAddImages();
    void testRemoveImage();
    void testClear();
    void testFolders();
    void testVideoSupport();
    void testUpdateItemPath();
};

void TestGalleryListModel::initTestCase()
{
}

void TestGalleryListModel::testInitialData()
{
    // By default, model should be empty in production
    GalleryListModel model;
    QCOMPARE(model.rowCount(), 0);

    // When requested, model should populate dummy data
    GalleryListModel dummyModel(true);
    QCOMPARE(dummyModel.rowCount(), 10);
    
    QModelIndex index = dummyModel.index(0, 0);
    QVERIFY(index.isValid());
    QVERIFY(dummyModel.data(index, GalleryListModel::FilePathRole).toUrl().isValid());
    QVERIFY(!dummyModel.data(index, GalleryListModel::FileNameRole).toString().isEmpty());
    QVERIFY(!dummyModel.data(index, GalleryListModel::RawPathRole).toString().isEmpty());
}

void TestGalleryListModel::testAddImages()
{
    GalleryListModel model;
    model.clear();
    QCOMPARE(model.rowCount(), 0);

    QStringList newImages = {"/tmp/test1.jpg", "/tmp/test2.png"};
    
    QSignalSpy spy(&model, &GalleryListModel::rowsInserted);
    model.addImages(newImages);
    
    QCOMPARE(model.rowCount(), 2);
    QCOMPARE(spy.count(), 1);
    
    QCOMPARE(model.data(model.index(0,0), GalleryListModel::FileNameRole).toString(), QString("test1.jpg"));
}

void TestGalleryListModel::testRemoveImage()
{
    GalleryListModel model;
    model.clear();
    model.addImages({"/tmp/1.jpg", "/tmp/2.jpg", "/tmp/3.jpg"});
    QCOMPARE(model.rowCount(), 3);

    QSignalSpy spy(&model, &GalleryListModel::rowsRemoved);
    model.removeImage(1); // Remove 2.jpg
    
    QCOMPARE(model.rowCount(), 2);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(model.data(model.index(1, 0), GalleryListModel::FileNameRole).toString(), QString("3.jpg"));
}

void TestGalleryListModel::testClear()
{
    GalleryListModel model(true);
    QVERIFY(model.rowCount() > 0);
    
    model.clear();
    QCOMPARE(model.rowCount(), 0);
}

void TestGalleryListModel::testFolders()
{
    GalleryListModel model;
    model.clear();
    
    // Add images
    model.addImages({"/tmp/img1.jpg", "/tmp/img2.jpg"});
    QCOMPARE(model.rowCount(), 2);
    
    // Add folders (should be prepended)
    model.addFolders({"/tmp/dir1", "/tmp/dir2"});
    QCOMPARE(model.rowCount(), 4);
    
    // Check that folders are first
    QCOMPARE(model.getFileName(0), QString("dir1"));
    QVERIFY(model.isFolder(0));
    QCOMPARE(model.data(model.index(0, 0), GalleryListModel::IsFolderRole).toBool(), true);
    
    QCOMPARE(model.getFileName(1), QString("dir2"));
    QVERIFY(model.isFolder(1));
    QCOMPARE(model.data(model.index(1, 0), GalleryListModel::IsFolderRole).toBool(), true);
    
    // Check that images are last
    QCOMPARE(model.getFileName(2), QString("img1.jpg"));
    QVERIFY(!model.isFolder(2));
    QCOMPARE(model.data(model.index(2, 0), GalleryListModel::IsFolderRole).toBool(), false);
    
    QCOMPARE(model.getFileName(3), QString("img2.jpg"));
    QVERIFY(!model.isFolder(3));
    QCOMPARE(model.data(model.index(3, 0), GalleryListModel::IsFolderRole).toBool(), false);
}

void TestGalleryListModel::testVideoSupport()
{
    GalleryListModel model;
    model.clear();
    
    // Add mix of images and videos
    model.addImages({"/tmp/img.jpg", "/tmp/video.mp4", "/tmp/video2.MOV", "/tmp/img2.png"});
    QCOMPARE(model.rowCount(), 4);
    
    // Check classification
    QCOMPARE(model.isVideo(0), false);
    QCOMPARE(model.data(model.index(0, 0), GalleryListModel::IsVideoRole).toBool(), false);
    
    QCOMPARE(model.isVideo(1), true);
    QCOMPARE(model.data(model.index(1, 0), GalleryListModel::IsVideoRole).toBool(), true);
    
    QCOMPARE(model.isVideo(2), true);
    QCOMPARE(model.data(model.index(2, 0), GalleryListModel::IsVideoRole).toBool(), true);
    
    QCOMPARE(model.isVideo(3), false);
    QCOMPARE(model.data(model.index(3, 0), GalleryListModel::IsVideoRole).toBool(), false);
}

void TestGalleryListModel::testUpdateItemPath()
{
    GalleryListModel model;
    model.addImages({"/tmp/photoA.jpg", "/tmp/photoB.jpg"});
    QCOMPARE(model.rowCount(), 2);

    QSignalSpy spy(&model, &GalleryListModel::dataChanged);
    bool updated = model.updateItemPath("/tmp/photoA.jpg", "/tmp/photoRenamed.jpg");
    QVERIFY(updated);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(model.getRawPath(0), "/tmp/photoRenamed.jpg");
    QCOMPARE(model.getFileName(0), "photoRenamed.jpg");

    // Non-existent path returns false
    QVERIFY(!model.updateItemPath("/tmp/nonexistent.jpg", "/tmp/other.jpg"));
}

QTEST_MAIN(TestGalleryListModel)
#include "tst_gallerylistmodel.moc"
