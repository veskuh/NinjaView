#include "AsyncImageProvider.h"
#include "Logger.h"
#include <QImageReader>
#include <QQuickTextureFactory>
#include <QDebug>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QDir>
#include <QDirIterator>
#include <QCryptographicHash>
#include <QFileInfo>

#ifdef Q_OS_MAC
QImage extractVideoFrameMac(const QString &filePath);
#endif

#ifdef Q_OS_LINUX
#include <QProcess>
#include <QThread>
QImage extractVideoFrameLinux(const QString &filePath)
{
    QString tempFile = QDir::tempPath() + "/ninjaview_thumb_" + QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex() + ".jpg";
    if (QFile::exists(tempFile)) {
        QFile::remove(tempFile);
    }
    
    QString escapedPath = filePath;
    escapedPath.replace("\"", "\\\"");
    QString escapedTemp = tempFile;
    escapedTemp.replace("\"", "\\\"");

    QProcess process;
    QStringList args;
    args << "filesrc" << QString("location=\"%1\"").arg(escapedPath)
         << "!" << "decodebin"
         << "!" << "videoconvert"
         << "!" << "jpegenc"
         << "!" << "filesink" << QString("location=\"%1\"").arg(escapedTemp);
         
    process.start("gst-launch-1.0", args);
    if (!process.waitForStarted(200)) {
        qWarning() << "GStreamer: Failed to start process gst-launch-1.0. Check if GStreamer is installed and in PATH.";
        return QImage();
    }
    
    bool success = false;
    for (int i = 0; i < 40; ++i) { // 2000ms max
        QThread::msleep(50);
        if (QFile::exists(tempFile) && QFileInfo(tempFile).size() > 0) {
            success = true;
            break;
        }
        if (process.state() == QProcess::NotRunning) {
            break;
        }
    }
    
    process.kill();
    process.waitForFinished(500);
    
    if (!success) {
        qDebug() << "GStreamer pipeline failed. Output:" << process.readAllStandardOutput();
        qDebug() << "GStreamer pipeline error:" << process.readAllStandardError();
    }
    
    QImage img;
    if (success && QFile::exists(tempFile)) {
        img.load(tempFile);
        QFile::remove(tempFile);
    }
    return img;
}
#endif

static QMutex s_cacheMutex;

AsyncImageResponse::AsyncImageResponse(const QString &id, const QSize &requestedSize, AsyncImageProvider *provider, Logger *logger)
    : m_id(id), m_requestedSize(requestedSize), m_provider(provider), m_logger(logger)
{
    setAutoDelete(false);
}

void AsyncImageResponse::cancel()
{
    m_isCancelled = true;
}

void AsyncImageResponse::run()
{
    if (m_isCancelled) {
        emit finished();
        return;
    }

    // Strip query parameters to get the clean file path
    QString cleanPath = m_id;
    int queryIdx = m_id.indexOf('?');
    if (queryIdx != -1) {
        cleanPath = m_id.left(queryIdx);
    }

    QString cacheKey = QString("%1_%2x%3").arg(cleanPath).arg(m_requestedSize.width()).arg(m_requestedSize.height());
    
    // 1. Check Memory Cache
    {
        QMutexLocker locker(&s_cacheMutex);
        if (m_provider->m_cache.contains(cacheKey)) {
            m_image = *m_provider->m_cache.object(cacheKey);
            emit finished();
            return;
        }
    }

    if (m_isCancelled) {
        emit finished();
        return;
    }

    // 2. Check Disk Cache (only if not rotated in-memory)
    int rotationAngle = m_provider->inMemoryRotation(cleanPath);
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/thumbnails";
    QString hash = QCryptographicHash::hash(cleanPath.toUtf8(), QCryptographicHash::Md5).toHex();
    
    const int TARGET_DISK_THUMB_SIZE = 600;
    bool isThumbnailRequest = m_requestedSize.isValid() &&
                              m_requestedSize.width() <= TARGET_DISK_THUMB_SIZE &&
                              m_requestedSize.height() <= TARGET_DISK_THUMB_SIZE;
    QSize diskCacheSize = isThumbnailRequest ? QSize(TARGET_DISK_THUMB_SIZE, TARGET_DISK_THUMB_SIZE) : m_requestedSize;
    QString diskPath = cacheDir + "/" + hash + "_" + QString::number(diskCacheSize.width()) + "x" + QString::number(diskCacheSize.height()) + ".jpg";

    if (rotationAngle == 0) {
        if (QFile::exists(diskPath)) {
            m_image.load(diskPath);
            if (!m_image.isNull()) {
                if (m_isCancelled) {
                    emit finished();
                    return;
                }
                
                // If it was loaded at 600px but requested smaller, scale in memory
                if (isThumbnailRequest && (m_image.width() > m_requestedSize.width() || m_image.height() > m_requestedSize.height())) {
                    m_image = m_image.scaled(m_requestedSize, Qt::KeepAspectRatio);
                }

                QMutexLocker locker(&s_cacheMutex);
                m_provider->m_cache.insert(cacheKey, new QImage(m_image), m_image.sizeInBytes());
                m_provider->m_cachedKeys[cleanPath].append(cacheKey);
                emit finished();
                return;
            }
        }
    }

    if (m_isCancelled) {
        emit finished();
        return;
    }

    // 3. Decode from Source
    QString ext = QFileInfo(cleanPath).suffix().toLower();
    bool isVideo = (ext == "mp4" || ext == "mov");
    if (isVideo) {
#ifdef Q_OS_MAC
        m_image = extractVideoFrameMac(cleanPath);
#elif defined(Q_OS_LINUX)
        m_image = extractVideoFrameLinux(cleanPath);
#endif
        if (!m_image.isNull()) {
            QImage diskCachedImage = m_image;
            if (diskCacheSize.isValid()) {
                if (diskCachedImage.width() > diskCacheSize.width() || diskCachedImage.height() > diskCacheSize.height()) {
                    diskCachedImage = diskCachedImage.scaled(diskCacheSize, Qt::KeepAspectRatio);
                }
            }
            
            // Save to disk cache ONLY if it is not rotated in-memory
            if (rotationAngle == 0) {
                QDir().mkpath(cacheDir);
                diskCachedImage.save(diskPath, "JPG", 80);
            }

            // Now prepare the image for the response (m_requestedSize)
            if (isThumbnailRequest) {
                if (diskCachedImage.width() > m_requestedSize.width() || diskCachedImage.height() > m_requestedSize.height()) {
                    m_image = diskCachedImage.scaled(m_requestedSize, Qt::KeepAspectRatio);
                } else {
                    m_image = diskCachedImage;
                }
            } else {
                m_image = diskCachedImage;
            }

            // Save to memory cache
            {
                QMutexLocker locker(&s_cacheMutex);
                m_provider->m_cache.insert(cacheKey, new QImage(m_image), m_image.sizeInBytes());
                m_provider->m_cachedKeys[cleanPath].append(cacheKey);
            }
        }
    } else {
        QImageReader reader(cleanPath);
        reader.setAutoTransform(true);
        if (reader.canRead()) {
            if (diskCacheSize.isValid()) {
                QSize size = reader.size();
                if (size.width() > diskCacheSize.width() || size.height() > diskCacheSize.height()) {
                    size.scale(diskCacheSize, Qt::KeepAspectRatio);
                    reader.setScaledSize(size);
                }
            }
            
            if (m_isCancelled) {
                emit finished();
                return;
            }

            m_image = reader.read();
            
            if (m_isCancelled) {
                emit finished();
                return;
            }

            if (!m_image.isNull()) {
                // Apply in-memory rotation if applicable
                if (rotationAngle != 0) {
                    QTransform transform;
                    transform.rotate(rotationAngle);
                    m_image = m_image.transformed(transform);
                }

                // Save to disk cache ONLY if it is not rotated in-memory
                if (rotationAngle == 0) {
                    QDir().mkpath(cacheDir);
                    m_image.save(diskPath, "JPG", 80);
                }

                // Now scale m_image in memory to the actual requested size (if it's a thumbnail request)
                if (isThumbnailRequest && (m_image.width() > m_requestedSize.width() || m_image.height() > m_requestedSize.height())) {
                    m_image = m_image.scaled(m_requestedSize, Qt::KeepAspectRatio);
                }

                // Save to memory cache
                {
                    QMutexLocker locker(&s_cacheMutex);
                    m_provider->m_cache.insert(cacheKey, new QImage(m_image), m_image.sizeInBytes());
                    m_provider->m_cachedKeys[cleanPath].append(cacheKey);
                }
            }
        }
    }

    emit finished();
}

QQuickTextureFactory *AsyncImageResponse::textureFactory() const
{
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

AsyncImageProvider::AsyncImageProvider(Logger *logger)
    : m_cache(2048 * 1024 * 1024ULL), m_logger(logger) // 2 GB default
{
    m_diskCachePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/thumbnails";
    ensureCacheDir();
    // Configure thread pool to run up to 4 threads concurrently for image rendering
    m_threadPool.setMaxThreadCount(4);
}

AsyncImageProvider::~AsyncImageProvider()
{
    m_threadPool.waitForDone();
}

qint64 AsyncImageProvider::maxMemoryCacheSize() const
{
    QMutexLocker locker(&s_cacheMutex);
    return m_cache.maxCost();
}

void AsyncImageProvider::setMaxMemoryCacheSize(qint64 size)
{
    {
        QMutexLocker locker(&s_cacheMutex);
        if (m_cache.maxCost() == size)
            return;
        m_cache.setMaxCost(size);
    }
    emit maxMemoryCacheSizeChanged();
}

QQuickImageResponse *AsyncImageProvider::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    AsyncImageResponse *response = new AsyncImageResponse(id, requestedSize, this, m_logger);
    m_threadPool.start(response);
    return response;
}

void AsyncImageProvider::clearCache()
{
    QMutexLocker locker(&s_cacheMutex);
    m_cache.clear();
    m_cachedKeys.clear();
    m_inMemoryRotations.clear();
}

void AsyncImageProvider::clearImageCache(const QString &filePath)
{
    QString cleanPath = filePath;
    int queryIdx = filePath.indexOf('?');
    if (queryIdx != -1) {
        cleanPath = filePath.left(queryIdx);
    }
    
    {
        QMutexLocker locker(&s_cacheMutex);
        const QStringList keys = m_cachedKeys.take(cleanPath);
        for (const QString &key : keys) {
            m_cache.remove(key);
        }
    }
    
    clearDiskCacheForFile(cleanPath);
}

void AsyncImageProvider::clearDiskCacheForFile(const QString &cleanPath)
{
    QString hash = QCryptographicHash::hash(cleanPath.toUtf8(), QCryptographicHash::Md5).toHex();
    QString prefix = hash + "_";
    QDir dir(m_diskCachePath);
    QStringList filters;
    filters << prefix + "*.jpg";
    QStringList files = dir.entryList(filters, QDir::Files);
    for (const QString &file : files) {
        dir.remove(file);
    }
}

void AsyncImageProvider::setInMemoryRotation(const QString &filePath, int angle)
{
    QString cleanPath = filePath;
    int queryIdx = filePath.indexOf('?');
    if (queryIdx != -1) {
        cleanPath = filePath.left(queryIdx);
    }
    
    QMutexLocker locker(&s_cacheMutex);
    int currentAngle = m_inMemoryRotations.value(cleanPath, 0);
    m_inMemoryRotations[cleanPath] = (currentAngle + angle) % 360;
}

void AsyncImageProvider::clearInMemoryRotation(const QString &filePath)
{
    QString cleanPath = filePath;
    int queryIdx = filePath.indexOf('?');
    if (queryIdx != -1) {
        cleanPath = filePath.left(queryIdx);
    }
    
    QMutexLocker locker(&s_cacheMutex);
    m_inMemoryRotations.remove(cleanPath);
}

int AsyncImageProvider::inMemoryRotation(const QString &filePath) const
{
    QString cleanPath = filePath;
    int queryIdx = filePath.indexOf('?');
    if (queryIdx != -1) {
        cleanPath = filePath.left(queryIdx);
    }
    
    QMutexLocker locker(&s_cacheMutex);
    return m_inMemoryRotations.value(cleanPath, 0);
}

qint64 AsyncImageProvider::cacheSize() const
{
    qint64 total = 0;
    QDirIterator it(m_diskCachePath, QDir::Files);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }
    return total;
}

void AsyncImageProvider::clearDiskCache()
{
    clearCache();
    QDir dir(m_diskCachePath);
    dir.removeRecursively();
    ensureCacheDir();
}

QString AsyncImageProvider::cachePath() const
{
    return m_diskCachePath;
}

void AsyncImageProvider::ensureCacheDir()
{
    QDir().mkpath(m_diskCachePath);
}

