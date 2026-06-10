#include "FileDiscoveryService.h"
#include "ExifDatabase.h"
#include "ExifReader.h"
#include <QDir>
#include <QDirIterator>
#include <QtConcurrent>
#include <QMutexLocker>
#include <QFileInfo>

FileDiscoveryService::FileDiscoveryService(QObject *parent)
    : QObject(parent)
{
}

FileDiscoveryService::~FileDiscoveryService()
{
    if (m_activeFuture.isRunning()) {
        m_activeFuture.waitForFinished();
    }
}

void FileDiscoveryService::setDatabase(ExifDatabase *db)
{
    m_db = db;
}

void FileDiscoveryService::scanDirectory(const QString &path, bool recursive)
{
    QString localPath = path;
    if (path.startsWith("file://")) {
        localPath = QUrl(path).toLocalFile();
    }

    quint64 scanId = 0;
    {
        QMutexLocker locker(&m_scanMutex);
        m_currentScanId++;
        scanId = m_currentScanId;
    }

    if (!m_isScanning) {
        m_isScanning = true;
        emit isScanningChanged();
    }

    m_activeFuture = QtConcurrent::run([this, localPath, recursive, scanId]() {
        doScan(localPath, recursive, scanId);
    });
}

void FileDiscoveryService::doScan(const QString &path, bool recursive, quint64 scanId)
{
    QStringList paths;
    QStringList folderPaths;

    if (path.startsWith("smart://")) {
        qDebug() << "Scanning smart folder:" << path;
        QStringList allPaths;
        if (path == "smart://favorites") {
            allPaths = m_db ? m_db->getFavorites() : QStringList();
        } else if (path.startsWith("smart://tag/")) {
            QString tag = path.mid(12); // length of "smart://tag/" is 12
            allPaths = m_db ? m_db->getImagesWithTag(tag) : QStringList();
        }

        // Verify files exist on disk
        for (const QString &filePath : allPaths) {
            if (QFileInfo::exists(filePath)) {
                paths << filePath;
            }
        }
    } else {
        qDebug() << "Scanning directory:" << path << (recursive ? "(recursive)" : "");
        QDir dir(path);
        if (!dir.exists()) {
            qWarning() << "Directory does not exist:" << path;
            {
                QMutexLocker locker(&m_scanMutex);
                if (scanId != m_currentScanId) {
                    return;
                }
            }
            m_isScanning = false;
            emit isScanningChanged();
            emit scanFinished();
            return;
        }

        QStringList filters;
        filters << "*.jpg" << "*.jpeg" << "*.png" << "*.bmp" << "*.webp"
                << "*.JPG" << "*.JPEG" << "*.PNG" << "*.BMP" << "*.WEBP";

        if (recursive) {
            QDirIterator it(path, filters, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                paths << it.next();
            }
        } else {
            // Find subdirectories
            QFileInfoList dirList = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
            for (const QFileInfo &dirInfo : dirList) {
                folderPaths << dirInfo.absoluteFilePath();
            }

            // Find images
            dir.setNameFilters(filters);
            dir.setFilter(QDir::Files | QDir::NoDotAndDotDot);
            QFileInfoList list = dir.entryInfoList();
            for (const QFileInfo &fileInfo : list) {
                paths << fileInfo.absoluteFilePath();
            }
        }
    }

    qDebug() << "Found" << folderPaths.count() << "folders and" << paths.count() << "images in" << path;

    // Verify scanId before updating the model or emitting finished signals
    {
        QMutexLocker locker(&m_scanMutex);
        if (scanId != m_currentScanId) {
            qDebug() << "Ignoring completed scan with outdated ID:" << scanId << "current:" << m_currentScanId;
            return;
        }
    }

    if (!folderPaths.isEmpty()) {
        emit foldersDiscovered(folderPaths);
    }
    if (!paths.isEmpty()) {
        emit imagesDiscovered(paths);
    }

    // Asynchronously pre-index any new files in the database
    if (m_db && !paths.isEmpty()) {
        qDebug() << "FileDiscoveryService: Background indexing EXIF cache for" << paths.count() << "files...";
        ExifReader indexReader;
        int indexedCount = 0;
        for (const QString &filePath : paths) {
            // Verify scanId to stop indexing early if navigation has hopped away
            {
                QMutexLocker locker(&m_scanMutex);
                if (scanId != m_currentScanId) {
                    qDebug() << "FileDiscoveryService: Indexing aborted early due to new scan request";
                    return;
                }
            }

            QFileInfo fileInfo(filePath);
            if (fileInfo.exists() && !fileInfo.isDir()) {
                if (!m_db->isCached(filePath, fileInfo.size(), fileInfo.lastModified())) {
                    // Extract and cache
                    QVariantMap exif = indexReader.getExifData(filePath);
                    m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), exif);
                    indexedCount++;
                }
            }
        }
        if (indexedCount > 0) {
            qDebug() << "FileDiscoveryService: Background indexing complete. Cached" << indexedCount << "new files.";
        }
        emit indexingFinished();
    }
    
    m_isScanning = false;
    emit isScanningChanged();
    emit scanFinished();
}

