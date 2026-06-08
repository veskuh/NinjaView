#include <QtTest>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QDir>
#include "VolumeMonitor.h"

class TestVolumeMonitor : public QObject
{
    Q_OBJECT

private slots:
    void testConstruction();
    void testMountSignal();
    void testUnmountSignal();
    void testSdCardPathDetection();
    void testSdCardIgnoreInvalid();
};

void TestVolumeMonitor::testConstruction()
{
    VolumeMonitor monitor;
    QVERIFY(monitor.sdCardPath().isEmpty());
}

void TestVolumeMonitor::testMountSignal()
{
    VolumeMonitor monitor;
    
    // Set initial volumes
    QList<VolumeMonitor::VolumeInfo> initialVolumes;
    VolumeMonitor::VolumeInfo vol1;
    vol1.rootPath = "/vol1";
    initialVolumes.append(vol1);
    
    monitor.setVolumesProvider([initialVolumes]() {
        return initialVolumes;
    });
    
    // Call checkVolumes to set initial state and wait for it
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    QTest::qWait(50);
    
    // Setup mock for new volume mount
    QList<VolumeMonitor::VolumeInfo> mountedVolumes = initialVolumes;
    VolumeMonitor::VolumeInfo vol2;
    vol2.rootPath = "/vol2";
    mountedVolumes.append(vol2);
    
    monitor.setVolumesProvider([mountedVolumes]() {
        return mountedVolumes;
    });
    
    QSignalSpy mountSpy(&monitor, &VolumeMonitor::volumeMounted);
    QSignalSpy unmountSpy(&monitor, &VolumeMonitor::volumeUnmounted);
    
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    
    QTRY_COMPARE(mountSpy.count(), 1);
    QCOMPARE(unmountSpy.count(), 0);
    QCOMPARE(mountSpy.at(0).at(0).toString(), QString("/vol2"));
}

void TestVolumeMonitor::testUnmountSignal()
{
    VolumeMonitor monitor;
    
    // Set initial volumes
    QList<VolumeMonitor::VolumeInfo> initialVolumes;
    VolumeMonitor::VolumeInfo vol1;
    vol1.rootPath = "/vol1";
    VolumeMonitor::VolumeInfo vol2;
    vol2.rootPath = "/vol2";
    initialVolumes.append(vol1);
    initialVolumes.append(vol2);
    
    monitor.setVolumesProvider([initialVolumes]() {
        return initialVolumes;
    });
    
    // Call checkVolumes to set initial state and wait
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    QTest::qWait(50);
    
    // Setup mock for volume unmount (remove vol2)
    QList<VolumeMonitor::VolumeInfo> unmountedVolumes;
    unmountedVolumes.append(vol1);
    
    monitor.setVolumesProvider([unmountedVolumes]() {
        return unmountedVolumes;
    });
    
    QSignalSpy mountSpy(&monitor, &VolumeMonitor::volumeMounted);
    QSignalSpy unmountSpy(&monitor, &VolumeMonitor::volumeUnmounted);
    
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    
    QTRY_COMPARE(unmountSpy.count(), 1);
    QCOMPARE(mountSpy.count(), 0);
    QCOMPARE(unmountSpy.at(0).at(0).toString(), QString("/vol2"));
}

void TestVolumeMonitor::testSdCardPathDetection()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    
    // Create a mock SD card layout (must contain a DCIM folder)
    QString sdPath = tempDir.path();
    QDir dir(sdPath);
    QVERIFY(dir.mkpath("DCIM"));
    
    VolumeMonitor monitor;
    QSignalSpy sdChangeSpy(&monitor, &VolumeMonitor::sdCardPathChanged);
    
    // Start with empty SD card path
    QList<VolumeMonitor::VolumeInfo> volumes;
    VolumeMonitor::VolumeInfo vol1;
    vol1.rootPath = "/vol1";
    volumes.append(vol1);
    
    monitor.setVolumesProvider([volumes]() {
        return volumes;
    });
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    QTest::qWait(50);
    QVERIFY(monitor.sdCardPath().isEmpty());
    QCOMPARE(sdChangeSpy.count(), 0);
    
    // Mount the SD card volume
    QList<VolumeMonitor::VolumeInfo> volumesWithSd = volumes;
    VolumeMonitor::VolumeInfo sdVol;
    sdVol.rootPath = sdPath;
    volumesWithSd.append(sdVol);
    
    monitor.setVolumesProvider([volumesWithSd]() {
        return volumesWithSd;
    });
    
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    
    // Should detect the SD card path asynchronously
    QTRY_COMPARE(monitor.sdCardPath(), sdPath);
    QCOMPARE(sdChangeSpy.count(), 1);
    
    // Unmount the SD card volume
    monitor.setVolumesProvider([volumes]() {
        return volumes;
    });
    
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    
    // Should clear the SD card path asynchronously
    QTRY_VERIFY(monitor.sdCardPath().isEmpty());
    QCOMPARE(sdChangeSpy.count(), 2);
}

void TestVolumeMonitor::testSdCardIgnoreInvalid()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    QString mockPath = tempDir.path();
    QDir(mockPath).mkpath("DCIM");
    
    VolumeMonitor monitor;
    
    // Volume is invalid
    QList<VolumeMonitor::VolumeInfo> volumes;
    VolumeMonitor::VolumeInfo invalidVol;
    invalidVol.rootPath = mockPath;
    invalidVol.isValid = false;
    volumes.append(invalidVol);
    
    monitor.setVolumesProvider([volumes]() {
        return volumes;
    });
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    QTest::qWait(50);
    QVERIFY(monitor.sdCardPath().isEmpty());
    
    // Volume is not ready
    volumes.clear();
    VolumeMonitor::VolumeInfo notReadyVol;
    notReadyVol.rootPath = mockPath;
    notReadyVol.isReady = false;
    volumes.append(notReadyVol);
    
    monitor.setVolumesProvider([volumes]() {
        return volumes;
    });
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    QTest::qWait(50);
    QVERIFY(monitor.sdCardPath().isEmpty());
    
    // Volume is root
    volumes.clear();
    VolumeMonitor::VolumeInfo rootVol;
    rootVol.rootPath = mockPath;
    rootVol.isRoot = true;
    volumes.append(rootVol);
    
    monitor.setVolumesProvider([volumes]() {
        return volumes;
    });
    QVERIFY(QMetaObject::invokeMethod(&monitor, "checkVolumes"));
    QTest::qWait(50);
    QVERIFY(monitor.sdCardPath().isEmpty());
}

QTEST_MAIN(TestVolumeMonitor)
#include "tst_volumemonitor.moc"
