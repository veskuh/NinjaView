#pragma once

#include <QSortFilterProxyModel>
#include <QString>
#include <QDateTime>

class ExifDatabase;

class GalleryFilterProxyModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(QString filterType READ filterType WRITE setFilterType NOTIFY filterTypeChanged)
    Q_PROPERTY(QString cameraFilter READ cameraFilter WRITE setCameraFilter NOTIFY cameraFilterChanged)
    Q_PROPERTY(QString currentFolderPath READ currentFolderPath WRITE setCurrentFolderPath NOTIFY currentFolderPathChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
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

    void setDatabase(ExifDatabase *db) { m_db = db; }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;

    Q_INVOKABLE void clear();
    Q_INVOKABLE void removeImage(int index);
    Q_INVOKABLE QString getRawPath(int row) const;
    Q_INVOKABLE QString getFileName(int row) const;
    Q_INVOKABLE bool isFolder(int row) const;

public Q_SLOTS:
    void invalidateFilter();

signals:
    void filterTypeChanged();
    void cameraFilterChanged();
    void currentFolderPathChanged();
    void searchQueryChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int source_row, const QModelIndex &source_parent) const override;

private:
    QString m_filterType{"All"};
    QString m_cameraFilter{""};
    QString m_currentFolderPath{""};
    QString m_searchQuery{""};
    ExifDatabase *m_db{nullptr};

    bool matchDate(const QDateTime &dateTime, const QString &type) const;
};
