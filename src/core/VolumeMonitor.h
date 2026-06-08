#pragma once

#include <QObject>
#include <QStorageInfo>
#include <QTimer>
#include <QStringList>
#include <functional>
#include <QFutureWatcher>

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
    QString sdCardPath() const { return m_sdCardPath; }

    void setVolumesProvider(std::function<QList<VolumeInfo>()> provider) { m_volumesProvider = provider; }

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

    QList<VolumeInfo> getMountedVolumes() const;
    void processVolumes(const QList<VolumeInfo> &volumeInfos);
    void updateSdCardPath(const QList<VolumeInfo> &volumeInfos);
};
