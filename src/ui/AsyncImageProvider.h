#pragma once

#include <QQuickAsyncImageProvider>
#include <QCache>
#include <QImage>
#include <QThreadPool>

class Logger;

#include <atomic>

class AsyncImageProvider;

class AsyncImageResponse : public QQuickImageResponse, public QRunnable
{
public:
    AsyncImageResponse(const QString &id, const QSize &requestedSize, AsyncImageProvider *provider, Logger *logger);

    void run() override;
    QQuickTextureFactory *textureFactory() const override;
    void cancel() override;

private:
    QString m_id;
    QSize m_requestedSize;
    AsyncImageProvider *m_provider;
    Logger *m_logger;
    QImage m_image;
    std::atomic<bool> m_isCancelled{false};
};

class AsyncImageProvider : public QQuickAsyncImageProvider
{
    Q_OBJECT
    Q_PROPERTY(qint64 maxMemoryCacheSize READ maxMemoryCacheSize WRITE setMaxMemoryCacheSize NOTIFY maxMemoryCacheSizeChanged)
    friend class AsyncImageResponse;

public:
    AsyncImageProvider(Logger *logger = nullptr);
    ~AsyncImageProvider() override;
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

    void clearCache();
    Q_INVOKABLE void clearImageCache(const QString &filePath);
    
    // Cache management for Settings
    Q_INVOKABLE qint64 cacheSize() const;
    Q_INVOKABLE void clearDiskCache();
    Q_INVOKABLE QString cachePath() const;

    qint64 maxMemoryCacheSize() const;
    void setMaxMemoryCacheSize(qint64 size);

    void setInMemoryRotation(const QString &filePath, int angle);
    void clearInMemoryRotation(const QString &filePath);
    int inMemoryRotation(const QString &filePath) const;

signals:
    void maxMemoryCacheSizeChanged();

private:
    QCache<QString, QImage> m_cache;
    Logger *m_logger;
    QString m_diskCachePath;
    QHash<QString, QStringList> m_cachedKeys;
    QHash<QString, int> m_inMemoryRotations;
    QThreadPool m_threadPool;
    void ensureCacheDir();
    void clearDiskCacheForFile(const QString &cleanPath);
};

