#pragma once

#include <QObject>
#include <QString>

class AsyncImageProvider;

class FileActionService : public QObject
{
    Q_OBJECT
public:
    explicit FileActionService(QObject *parent = nullptr);

    void setImageProvider(AsyncImageProvider *provider);

    Q_INVOKABLE void showInFolder(const QString &filePath);
    Q_INVOKABLE void openExternally(const QString &filePath);
    Q_INVOKABLE bool moveToTrash(const QString &filePath);
    Q_INVOKABLE int rotateImage(const QString &filePath, int angle);
    Q_INVOKABLE void copyToClipboard(const QString &filePath);
    Q_INVOKABLE void copyToClipboardBatch(const QStringList &filePaths);
    Q_INVOKABLE int rotateImagesBatch(const QStringList &filePaths, int angle);
    Q_INVOKABLE bool moveFilesToTrashBatch(const QStringList &filePaths);
    Q_INVOKABLE void importToApplePhotos(const QStringList &filePaths);

signals:
    void imageRotated(const QString &filePath);
    void importFinished(bool success, const QString &errorMessage);

private:
    bool writeExifOrientation(const QString &filePath, int newOrientation);
    AsyncImageProvider *m_imageProvider{nullptr};
};

