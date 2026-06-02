#include "GalleryFilterProxyModel.h"
#include "GalleryListModel.h"
#include "ExifDatabase.h"
#include <QFileInfo>
#include <QDate>
#include <QDebug>

GalleryFilterProxyModel::GalleryFilterProxyModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &GalleryFilterProxyModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &GalleryFilterProxyModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &GalleryFilterProxyModel::countChanged);
}

int GalleryFilterProxyModel::rowCount(const QModelIndex &parent) const
{
    return QSortFilterProxyModel::rowCount(parent);
}

void GalleryFilterProxyModel::setFilterType(const QString &type)
{
    if (m_filterType != type) {
        m_filterType = type;
        emit filterTypeChanged();
        invalidateFilter();
    }
}

void GalleryFilterProxyModel::setCameraFilter(const QString &camera)
{
    if (m_cameraFilter != camera) {
        m_cameraFilter = camera;
        emit cameraFilterChanged();
        invalidateFilter();
    }
}

void GalleryFilterProxyModel::setCurrentFolderPath(const QString &path)
{
    if (m_currentFolderPath != path) {
        m_currentFolderPath = path;
        emit currentFolderPathChanged();
        invalidateFilter();
    }
}

void GalleryFilterProxyModel::setSearchQuery(const QString &query)
{
    if (m_searchQuery != query) {
        m_searchQuery = query;
        emit searchQueryChanged();
        invalidateFilter();
    }
}

void GalleryFilterProxyModel::clear()
{
    auto srcModel = qobject_cast<GalleryListModel*>(sourceModel());
    if (srcModel) {
        srcModel->clear();
    }
}

void GalleryFilterProxyModel::removeImage(int index)
{
    auto srcModel = qobject_cast<GalleryListModel*>(sourceModel());
    if (srcModel) {
        QModelIndex proxyIndex = this->index(index, 0);
        QModelIndex sourceIndex = mapToSource(proxyIndex);
        if (sourceIndex.isValid()) {
            srcModel->removeImage(sourceIndex.row());
        }
    }
}

QString GalleryFilterProxyModel::getRawPath(int row) const
{
    auto srcModel = qobject_cast<GalleryListModel*>(sourceModel());
    if (srcModel) {
        QModelIndex proxyIndex = this->index(row, 0);
        QModelIndex sourceIndex = mapToSource(proxyIndex);
        if (sourceIndex.isValid()) {
            return srcModel->getRawPath(sourceIndex.row());
        }
    }
    return QString();
}

QString GalleryFilterProxyModel::getFileName(int row) const
{
    auto srcModel = qobject_cast<GalleryListModel*>(sourceModel());
    if (srcModel) {
        QModelIndex proxyIndex = this->index(row, 0);
        QModelIndex sourceIndex = mapToSource(proxyIndex);
        if (sourceIndex.isValid()) {
            return srcModel->getFileName(sourceIndex.row());
        }
    }
    return QString();
}

bool GalleryFilterProxyModel::isFolder(int row) const
{
    auto srcModel = qobject_cast<GalleryListModel*>(sourceModel());
    if (srcModel) {
        QModelIndex proxyIndex = this->index(row, 0);
        QModelIndex sourceIndex = mapToSource(proxyIndex);
        if (sourceIndex.isValid()) {
            return srcModel->isFolder(sourceIndex.row());
        }
    }
    return false;
}

bool GalleryFilterProxyModel::filterAcceptsRow(int source_row, const QModelIndex &source_parent) const
{
    Q_UNUSED(source_parent);
    auto srcModel = qobject_cast<GalleryListModel*>(sourceModel());
    if (!srcModel) return false;

    // Folders are accepted unless we are in a smart folder
    if (srcModel->isFolder(source_row)) {
        if (m_currentFolderPath.startsWith("smart://")) {
            return false;
        }
        if (!m_searchQuery.isEmpty()) {
            return srcModel->getFileName(source_row).contains(m_searchQuery, Qt::CaseInsensitive);
        }
        return true;
    }

    QString filePath = srcModel->getRawPath(source_row);

    // Apply search query criteria for files
    if (!m_searchQuery.isEmpty()) {
        bool matches = false;

        // 1. Filename match
        QString fileName = srcModel->getFileName(source_row);
        if (fileName.contains(m_searchQuery, Qt::CaseInsensitive)) {
            matches = true;
        }

        // 2. Notes and tags match
        if (!matches && m_db) {
            QString notes = m_db->getNotes(filePath);
            if (notes.contains(m_searchQuery, Qt::CaseInsensitive)) {
                matches = true;
            }

            if (!matches) {
                QString tags = m_db->getTags(filePath);
                if (tags.contains(m_searchQuery, Qt::CaseInsensitive)) {
                    matches = true;
                }
            }
        }

        if (!matches) {
            return false;
        }
    }

    // Apply smart folder criteria
    if (m_currentFolderPath == "smart://favorites") {
        bool isFav = m_db ? m_db->isFavorite(filePath) : false;
        if (m_db && !isFav) {
            return false;
        }
    } else if (m_currentFolderPath.startsWith("smart://tag/")) {
        QString tag = m_currentFolderPath.mid(12); // "smart://tag/" is 12 chars
        if (m_db) {
            QString tagsStr = m_db->getTags(filePath);
            QStringList tagList = tagsStr.split(',');
            bool hasTag = false;
            for (const QString &t : tagList) {
                if (t.trimmed().compare(tag, Qt::CaseInsensitive) == 0) {
                    hasTag = true;
                    break;
                }
            }
            if (!hasTag) {
                return false;
            }
        }
    }

    if (m_filterType == "All") {
        return true;
    }

    QFileInfo fileInfo(filePath);
    
    QDateTime fileDate = fileInfo.lastModified();
    QVariantMap exif;

    if (m_db) {
        exif = m_db->getExifData(filePath);
        QString dateStr = exif.value("DateTime").toString();
        if (!dateStr.isEmpty()) {
            QDateTime parsed = QDateTime::fromString(dateStr, "yyyy:MM:dd HH:mm:ss");
            if (parsed.isValid()) {
                fileDate = parsed;
            }
        }
    }

    if (m_filterType == "Today" || m_filterType == "This Week" || m_filterType == "This Month") {
        return matchDate(fileDate, m_filterType);
    }

    bool isYear = false;
    int filterYear = m_filterType.toInt(&isYear);
    if (isYear) {
        return (fileDate.isValid() && fileDate.date().year() == filterYear);
    }

    QString ext = fileInfo.suffix().toUpper();
    if (ext == "JPEG") ext = "JPG";
    if (m_filterType == "JPG" || m_filterType == "PNG" || m_filterType == "WEBP" || m_filterType == "BMP") {
        return (ext == m_filterType);
    }

    if (m_filterType == "Camera") {
        if (m_db && !m_cameraFilter.isEmpty()) {
            QString make = exif.value("Make").toString();
            QString model = exif.value("Model").toString();
            QString camera = make;
            if (!model.isEmpty() && !model.startsWith(make, Qt::CaseInsensitive)) {
                camera += " " + model;
            }
            return (camera.trimmed().compare(m_cameraFilter.trimmed(), Qt::CaseInsensitive) == 0);
        }
    }

    return true;
}

bool GalleryFilterProxyModel::matchDate(const QDateTime &dateTime, const QString &type) const
{
    QDate date = dateTime.date();
    QDate current = QDate::currentDate();

    if (type == "Today") {
        return (date == current);
    }
    if (type == "This Week") {
        return (date >= current.addDays(-7) && date <= current);
    }
    if (type == "This Month") {
        return (date.month() == current.month() && date.year() == current.year());
    }
    return true;
}

void GalleryFilterProxyModel::invalidateFilter()
{
    QSortFilterProxyModel::invalidateFilter();
}
