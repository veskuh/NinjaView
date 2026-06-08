#include "VolumeMonitor.h"
#include <QDebug>
#include <QDir>
#include <QtConcurrent>

VolumeMonitor::VolumeMonitor(QObject *parent)
    : QObject(parent)
{
    // Start initial scan asynchronously immediately to avoid blocking main thread at startup
    QTimer::singleShot(0, this, &VolumeMonitor::checkVolumes);

    QTimer *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &VolumeMonitor::checkVolumes);
    timer->start(3000); // Check every 3 seconds for better responsiveness
}

void VolumeMonitor::checkVolumes()
{
    if (m_isChecking) return;
    m_isChecking = true;

    auto watcher = new QFutureWatcher<QList<VolumeInfo>>(this);
    connect(watcher, &QFutureWatcher<QList<VolumeInfo>>::finished, this, [this, watcher]() {
        QList<VolumeInfo> currentVolumeInfos = watcher->result();
        watcher->deleteLater();
        
        processVolumes(currentVolumeInfos);
        m_isChecking = false;
    });

    QFuture<QList<VolumeInfo>> future = QtConcurrent::run([this]() {
        return getMountedVolumes();
    });
    watcher->setFuture(future);
}

void VolumeMonitor::processVolumes(const QList<VolumeInfo> &volumeInfos)
{
    QStringList currentVolumes;
    for (const VolumeInfo &storage : volumeInfos) {
        if (storage.isValid && storage.isReady) {
            currentVolumes << storage.rootPath;
        }
    }

    bool changed = false;

    // Find new volumes
    for (const QString &path : currentVolumes) {
        if (!m_lastVolumes.contains(path)) {
            qDebug() << "Volume mounted:" << path;
            emit volumeMounted(path);
            changed = true;
        }
    }

    // Find unmounted volumes
    for (const QString &path : m_lastVolumes) {
        if (!currentVolumes.contains(path)) {
            qDebug() << "Volume unmounted:" << path;
            emit volumeUnmounted(path);
            changed = true;
        }
    }

    m_lastVolumes = currentVolumes;
    
    // Always call updateSdCardPath to verify if the path changed
    updateSdCardPath(volumeInfos);
}

void VolumeMonitor::updateSdCardPath(const QList<VolumeInfo> &volumeInfos)
{
    QString bestPath;
    
    for (const VolumeInfo &storage : volumeInfos) {
        if (!storage.isValid || !storage.isReady || storage.isRoot) {
            continue;
        }
        
        QString path = storage.rootPath;
        if (path.isEmpty() || path == "/") {
            continue;
        }
        
        // Strategy: Look for DCIM folder which is standard for cameras
        QDir dcimDir(path + "/DCIM");
        if (dcimDir.exists()) {
            bestPath = path;
            break; 
        }
    }
    
    if (m_sdCardPath != bestPath) {
        m_sdCardPath = bestPath;
        qDebug() << "SD Card Path updated:" << m_sdCardPath;
        emit sdCardPathChanged();
    }
}

QList<VolumeMonitor::VolumeInfo> VolumeMonitor::getMountedVolumes() const
{
    if (m_volumesProvider) {
        return m_volumesProvider();
    }

    QList<VolumeInfo> list;
    for (const QStorageInfo &storage : QStorageInfo::mountedVolumes()) {
        VolumeInfo info;
        info.rootPath = storage.rootPath();
        info.isValid = storage.isValid();
        info.isReady = storage.isReady();
        info.isRoot = storage.isRoot();
        list.append(info);
    }
    return list;
}
