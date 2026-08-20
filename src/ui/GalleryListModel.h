#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QStringList>

struct GalleryItem {
    QString path;
    bool isFolder;
    bool isVideo;
    qint64 fileSize = 0;
    QDateTime lastModified;
};

class GalleryListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        FilePathRole = Qt::UserRole + 1,
        FileNameRole,
        RawPathRole,
        IsFolderRole,
        IsVideoRole,
        FileSizeRole,
        LastModifiedRole
    };

    explicit GalleryListModel(bool populateDummy = false, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addImages(const QStringList &newPaths);
    Q_INVOKABLE void addFolders(const QStringList &newPaths);
    Q_INVOKABLE void removeImage(int index);
    Q_INVOKABLE bool updateItemPath(const QString &oldPath, const QString &newPath);
    Q_INVOKABLE void clear();
    Q_INVOKABLE QString getRawPath(int row) const;
    Q_INVOKABLE QString getFileName(int row) const;
    Q_INVOKABLE bool isFolder(int row) const;
    Q_INVOKABLE bool isVideo(int row) const;

signals:
    void countChanged();

private:
    QList<GalleryItem> m_items;
};
