#include "GalleryListModel.h"
#include <QFileInfo>
#include <QUrl>

GalleryListModel::GalleryListModel(bool populateDummy, QObject *parent)
    : QAbstractListModel(parent)
{
    if (populateDummy) {
        // Dummy data for initial structure testing
        QStringList dummyPaths;
        for (int i = 1; i <= 10; ++i) {
            dummyPaths << QString("/fake/path/image_%1.jpg").arg(i);
        }
        addImages(dummyPaths);
    }
}

int GalleryListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.count();
}

QVariant GalleryListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_items.count())
        return QVariant();

    const GalleryItem &item = m_items.at(index.row());

    switch (role) {
    case FilePathRole:
        return QUrl::fromLocalFile(item.path);
    case FileNameRole:
        return QFileInfo(item.path).fileName();
    case RawPathRole:
        return item.path;
    case IsFolderRole:
        return item.isFolder;
    case IsVideoRole:
        return item.isVideo;
    case Qt::DisplayRole:
        return QFileInfo(item.path).fileName();
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> GalleryListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[FilePathRole] = "filePath";
    roles[FileNameRole] = "fileName";
    roles[RawPathRole] = "rawPath";
    roles[IsFolderRole] = "isFolder";
    roles[IsVideoRole] = "isVideo";
    return roles;
}

void GalleryListModel::addImages(const QStringList &newPaths)
{
    if (newPaths.isEmpty())
        return;

    beginInsertRows(QModelIndex(), m_items.count(), m_items.count() + newPaths.count() - 1);
    for (const QString &path : newPaths) {
        QString ext = QFileInfo(path).suffix().toUpper();
        bool isVideo = (ext == "MP4" || ext == "MOV");
        m_items.append({path, false, isVideo});
    }
    endInsertRows();
    emit countChanged();
}

void GalleryListModel::addFolders(const QStringList &newPaths)
{
    if (newPaths.isEmpty())
        return;

    beginInsertRows(QModelIndex(), 0, newPaths.count() - 1);
    for (int i = newPaths.count() - 1; i >= 0; --i) {
        m_items.insert(0, {newPaths.at(i), true, false});
    }
    endInsertRows();
    emit countChanged();
}

void GalleryListModel::removeImage(int index)
{
    if (index < 0 || index >= m_items.count())
        return;

    beginRemoveRows(QModelIndex(), index, index);
    m_items.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

void GalleryListModel::clear()
{
    beginResetModel();
    m_items.clear();
    endResetModel();
    emit countChanged();
}

QString GalleryListModel::getRawPath(int row) const
{
    if (row < 0 || row >= m_items.count())
        return QString();
    return m_items.at(row).path;
}

QString GalleryListModel::getFileName(int row) const
{
    if (row < 0 || row >= m_items.count())
        return QString();
    return QFileInfo(m_items.at(row).path).fileName();
}

bool GalleryListModel::isFolder(int row) const
{
    if (row < 0 || row >= m_items.count())
        return false;
    return m_items.at(row).isFolder;
}

bool GalleryListModel::isVideo(int row) const
{
    if (row < 0 || row >= m_items.count())
        return false;
    return m_items.at(row).isVideo;
}
