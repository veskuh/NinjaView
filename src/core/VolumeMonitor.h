#pragma once

#include <QObject>
#include <QStorageInfo>
#include <QTimer>
#include <QStringList>
#include <functional>
#include <QFutureWatcher>
#include <QFuture>

class VolumeMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sdCardPath READ sdCardPath NOTIFY sdCardPathChanged)

public:
    struct VolumeInfo {
        QString rootPath;
        bool isValid = true;
        bool isReady = true;
        bool isRoot = false;
    };

    explicit VolumeMonitor(QObject *parent = nullptr);
    ~VolumeMonitor();

    QString sdCardPath() const { return m_sdCardPath; }

    void setVolumesProvider(std::function<QList<VolumeInfo>()> provider) { m_volumesProvider = provider; }

    void stopMonitoring();
    void waitForCheckFinished();

signals:
    void volumeMounted(const QString &path);
    void volumeUnmounted(const QString &path);
    void sdCardPathChanged();

private slots:
    void checkVolumes();

private:
    QStringList m_lastVolumes;
    QString m_sdCardPath;
    std::function<QList<VolumeInfo>()> m_volumesProvider;
    bool m_isChecking{false};

    QTimer *m_timer{nullptr};
    QTimer *m_singleShotTimer{nullptr};
    QFuture<QList<VolumeInfo>> m_activeFuture;

    QList<VolumeInfo> getMountedVolumes() const;
    void processVolumes(const QList<VolumeInfo> &volumeInfos);
    void updateSdCardPath(const QList<VolumeInfo> &volumeInfos);
};

