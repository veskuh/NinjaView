#pragma once

#include <QCollator>
#include <QSortFilterProxyModel>
#include <QString>
#include <QDateTime>
#include <QSet>

class ExifDatabase;

class GalleryFilterProxyModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(QString filterType READ filterType WRITE setFilterType NOTIFY filterTypeChanged)
    Q_PROPERTY(QString cameraFilter READ cameraFilter WRITE setCameraFilter NOTIFY cameraFilterChanged)
    Q_PROPERTY(QString currentFolderPath READ currentFolderPath WRITE setCurrentFolderPath NOTIFY currentFolderPathChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(QString mediaTypeFilter READ mediaTypeFilter WRITE setMediaTypeFilter NOTIFY mediaTypeFilterChanged)
    Q_PROPERTY(bool showNewOnly READ showNewOnly WRITE setShowNewOnly NOTIFY showNewOnlyChanged)
    Q_PROPERTY(QString sortBy READ sortBy WRITE setSortBy NOTIFY sortByChanged)
    Q_PROPERTY(int sortOrder READ sortOrder WRITE setSortOrder NOTIFY sortOrderChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    explicit GalleryFilterProxyModel(QObject *parent = nullptr);

    QString filterType() const { return m_filterType; }
    void setFilterType(const QString &type);

    QString cameraFilter() const { return m_cameraFilter; }
    void setCameraFilter(const QString &camera);

    QString currentFolderPath() const { return m_currentFolderPath; }
    void setCurrentFolderPath(const QString &path);

    QString searchQuery() const { return m_searchQuery; }
    void setSearchQuery(const QString &query);

    QString mediaTypeFilter() const { return m_mediaTypeFilter; }
    void setMediaTypeFilter(const QString &mediaType);

    bool showNewOnly() const { return m_showNewOnly; }
    void setShowNewOnly(bool show);

    /*! Sort key: "name", "date" or "size". Applied on top of the current filter. */
    QString sortBy() const { return m_sortBy; }
    void setSortBy(const QString &sortBy);

    /*! Qt::AscendingOrder or Qt::DescendingOrder as int for QML. */
    int sortOrder() const { return static_cast<int>(m_sortOrder); }
    void setSortOrder(int order);

    void setDatabase(ExifDatabase *db) { m_db = db; }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;

    Q_INVOKABLE void clear();
    Q_INVOKABLE void removeImage(int index);
    Q_INVOKABLE QString getRawPath(int row) const;
    Q_INVOKABLE QString getFileName(int row) const;
    Q_INVOKABLE bool isFolder(int row) const;
    Q_INVOKABLE bool isVideo(int row) const;

public Q_SLOTS:
    void invalidateFilter();

signals:
    void filterTypeChanged();
    void cameraFilterChanged();
    void currentFolderPathChanged();
    void searchQueryChanged();
    void mediaTypeFilterChanged();
    void showNewOnlyChanged();
    void sortByChanged();
    void sortOrderChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int source_row, const QModelIndex &source_parent) const override;
    bool lessThan(const QModelIndex &source_left, const QModelIndex &source_right) const override;

private:
    QString m_filterType{"All"};
    QString m_cameraFilter{""};
    QString m_currentFolderPath{""};
    QString m_searchQuery{""};
    QString m_mediaTypeFilter{"All"};
    bool m_showNewOnly{false};
    QString m_sortBy{"name"};
    Qt::SortOrder m_sortOrder{Qt::AscendingOrder};
    QCollator m_collator;
    mutable QSet<QString> m_newFiles;
    ExifDatabase *m_db{nullptr};

    bool matchDate(const QDateTime &dateTime, const QString &type) const;
};
