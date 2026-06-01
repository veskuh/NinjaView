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

signals:
    void imageRotated(const QString &filePath);

private:
    bool writeExifOrientation(const QString &filePath, int newOrientation);
    AsyncImageProvider *m_imageProvider{nullptr};
};

