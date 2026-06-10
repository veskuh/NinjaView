#pragma once

#include <QObject>
#include <QStringList>
#include <atomic>
#include <QMutex>
#include <QFuture>

class ExifDatabase;

class FileDiscoveryService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)

public:
    explicit FileDiscoveryService(QObject *parent = nullptr);
    ~FileDiscoveryService();

    void setDatabase(ExifDatabase *db);

    Q_INVOKABLE void scanDirectory(const QString &path, bool recursive = false);
    bool isScanning() const { return m_isScanning.load(); }

signals:
    void imagesDiscovered(const QStringList &paths);
    void foldersDiscovered(const QStringList &paths);
    void scanFinished();
    void isScanningChanged();
    void indexingFinished();

private:
    void doScan(const QString &path, bool recursive, quint64 scanId);
    std::atomic<bool> m_isScanning{false};
    quint64 m_currentScanId{0};
    mutable QMutex m_scanMutex;
    ExifDatabase *m_db{nullptr};
    QFuture<void> m_activeFuture;
};
