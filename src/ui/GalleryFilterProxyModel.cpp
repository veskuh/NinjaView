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

    // Sorting is applied explicitly via sort(); with dynamic sorting disabled the
    // order survives the invalidateFilter() calls made by the individual filter setters.
    setDynamicSortFilter(false);

    // Natural filename ordering: case-insensitive, numeric-aware ("img2" < "img10")
    QLocale defaultLocale;
    if (defaultLocale.language() == QLocale::C) {
        m_collator.setLocale(QLocale(QLocale::English));
    } else {
        m_collator.setLocale(defaultLocale);
    }
    m_collator.setCaseSensitivity(Qt::CaseInsensitive);
    m_collator.setNumericMode(true);
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
        m_newFiles.clear();
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

void GalleryFilterProxyModel::setMediaTypeFilter(const QString &mediaType)
{
    if (m_mediaTypeFilter != mediaType) {
        m_mediaTypeFilter = mediaType;
        emit mediaTypeFilterChanged();
        invalidateFilter();
    }
}

void GalleryFilterProxyModel::setShowNewOnly(bool show)
{
    if (m_showNewOnly != show) {
        m_showNewOnly = show;
        emit showNewOnlyChanged();
        invalidateFilter();
    }
}

void GalleryFilterProxyModel::setSortBy(const QString &sortBy)
{
    if (sortBy != "name" && sortBy != "date" && sortBy != "size" && sortBy != "dimensions") {
        return;
    }
    if (m_sortBy != sortBy) {
        m_sortBy = sortBy;
        emit sortByChanged();
    }
    // (Re)apply sorting even if the key stayed the same, so the first
    // header click engages sorting from the unsorted initial state.
    sort(0, m_sortOrder);
}

void GalleryFilterProxyModel::setSortOrder(int order)
{
    Qt::SortOrder newOrder = (order == Qt::DescendingOrder) ? Qt::DescendingOrder : Qt::AscendingOrder;
    if (m_sortOrder != newOrder) {
        m_sortOrder = newOrder;
        emit sortOrderChanged();
    }
    sort(0, m_sortOrder);
}

void GalleryFilterProxyModel::clear()
{
    m_newFiles.clear();
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

bool GalleryFilterProxyModel::isVideo(int row) const
{
    auto srcModel = qobject_cast<GalleryListModel*>(sourceModel());
    if (srcModel) {
        QModelIndex proxyIndex = this->index(row, 0);
        QModelIndex sourceIndex = mapToSource(proxyIndex);
        if (sourceIndex.isValid()) {
            return srcModel->isVideo(sourceIndex.row());
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

    // Apply mediaTypeFilter
    if (m_mediaTypeFilter != "All") {
        bool isVideoFile = srcModel->isVideo(source_row);
        if (m_mediaTypeFilter == "Photos" && isVideoFile) {
            return false;
        }
        if (m_mediaTypeFilter == "Videos" && !isVideoFile) {
            return false;
        }
    }

    QString filePath = srcModel->getRawPath(source_row);
    QFileInfo fileInfo(filePath);

    // Apply showNewOnly filter (unindexed files are considered new)
    bool isNewFile = false;
    if (m_db) {
        if (m_newFiles.contains(filePath)) {
            isNewFile = true;
        } else if (!m_db->isCached(filePath, fileInfo.size(), fileInfo.lastModified())) {
            m_newFiles.insert(filePath);
            isNewFile = true;
        }
    }

    if (m_showNewOnly && !isNewFile) {
        return false;
    }

    // Apply smart folder type filtering (Pictures library has images only, Videos has movies only)
    if (m_currentFolderPath == "smart://pictures" || m_currentFolderPath == "smart://videos") {
        QString ext = fileInfo.suffix().toUpper();
        if (ext == "JPEG") ext = "JPG";
        if (m_currentFolderPath == "smart://pictures") {
            if (ext != "JPG" && ext != "PNG" && ext != "WEBP" && ext != "BMP") {
                return false;
            }
        } else if (m_currentFolderPath == "smart://videos") {
            if (ext != "MP4" && ext != "MOV") {
                return false;
            }
        }
    }

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
    if (m_filterType == "JPG" || m_filterType == "PNG" || m_filterType == "WEBP" || m_filterType == "BMP" || m_filterType == "MP4" || m_filterType == "MOV") {
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

bool GalleryFilterProxyModel::lessThan(const QModelIndex &source_left, const QModelIndex &source_right) const
{
    const QAbstractItemModel *src = sourceModel();
    if (!src) {
        return QSortFilterProxyModel::lessThan(source_left, source_right);
    }

    const bool leftFolder = src->data(source_left, GalleryListModel::IsFolderRole).toBool();
    const bool rightFolder = src->data(source_right, GalleryListModel::IsFolderRole).toBool();
    // Folders stay on top in both sort orders
    if (leftFolder != rightFolder) {
        return m_sortOrder == Qt::AscendingOrder ? leftFolder : rightFolder;
    }

    if (m_sortBy == "size") {
        const qint64 leftSize = src->data(source_left, GalleryListModel::FileSizeRole).toLongLong();
        const qint64 rightSize = src->data(source_right, GalleryListModel::FileSizeRole).toLongLong();
        if (leftSize != rightSize) {
            return leftSize < rightSize;
        }
    } else if (m_sortBy == "date") {
        const QDateTime leftDate = src->data(source_left, GalleryListModel::LastModifiedRole).toDateTime();
        const QDateTime rightDate = src->data(source_right, GalleryListModel::LastModifiedRole).toDateTime();
        if (leftDate != rightDate) {
            return leftDate < rightDate;
        }
    } else if (m_sortBy == "dimensions") {
        QString leftVal, rightVal;
        if (m_db) {
            bool leftVideo = src->data(source_left, GalleryListModel::IsVideoRole).toBool();
            QVariantMap leftExif = m_db->getExifData(src->data(source_left, GalleryListModel::RawPathRole).toString());
            leftVal = leftVideo ? leftExif.value("Duration").toString() : leftExif.value("Dimensions").toString();

            bool rightVideo = src->data(source_right, GalleryListModel::IsVideoRole).toBool();
            QVariantMap rightExif = m_db->getExifData(src->data(source_right, GalleryListModel::RawPathRole).toString());
            rightVal = rightVideo ? rightExif.value("Duration").toString() : rightExif.value("Dimensions").toString();
        }
        if (leftVal != rightVal) {
            return m_collator.compare(leftVal, rightVal) < 0;
        }
    }

    // Primary key for "name", deterministic tie-break for the other keys
    const QString leftName = src->data(source_left, GalleryListModel::FileNameRole).toString();
    const QString rightName = src->data(source_right, GalleryListModel::FileNameRole).toString();
    return m_collator.compare(leftName, rightName) < 0;
}

void GalleryFilterProxyModel::invalidateFilter()
{
    QSortFilterProxyModel::invalidateFilter();
}
