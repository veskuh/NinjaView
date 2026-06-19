#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantMap>
#include <QDateTime>

class ExifDatabase : public QObject
{
    Q_OBJECT
public:
    explicit ExifDatabase(const QString &dbPath = QString(), QObject *parent = nullptr);
    ~ExifDatabase();

    bool init();

    bool isCached(const QString &filePath, qint64 fileSize, const QDateTime &lastModified);
    Q_INVOKABLE QVariantMap getExifData(const QString &filePath);
    bool saveExifData(const QString &filePath, qint64 fileSize, const QDateTime &lastModified, const QVariantMap &exifData);
    Q_INVOKABLE QStringList getUniqueCamerasForFolder(const QString &folderPath);
    Q_INVOKABLE QVariantMap getAvailableFiltersForFolder(const QString &folderPath);
    Q_INVOKABLE bool clear();

    // Favorites, Notes, and Tags API
    Q_INVOKABLE bool setFavorite(const QString &filePath, bool favorite);
    Q_INVOKABLE bool isFavorite(const QString &filePath);
    Q_INVOKABLE bool setNotes(const QString &filePath, const QString &notes);
    Q_INVOKABLE QString getNotes(const QString &filePath);
    Q_INVOKABLE bool setTags(const QString &filePath, const QString &tags);
    Q_INVOKABLE QString getTags(const QString &filePath);
    Q_INVOKABLE QStringList getAllTags();
    
    Q_INVOKABLE bool setFavoriteBatch(const QStringList &filePaths, bool favorite);
    Q_INVOKABLE bool setTagsBatch(const QStringList &filePaths, const QString &tags, bool append);
    Q_INVOKABLE bool setNotesBatch(const QStringList &filePaths, const QString &notes, bool append);
    Q_INVOKABLE bool updateCommonTagsBatch(const QStringList &filePaths, const QString &newCommonTags, const QString &oldCommonTags);
    
    // Internal smart-folder helpers
    QStringList getFavorites();
    QStringList getImagesWithTag(const QString &tag);

signals:
    void favoritesChanged();
    void notesChanged(const QString &filePath);
    void tagsChanged();

private:
    QSqlDatabase getDatabaseConnection();
    bool ensureRecordExists(const QString &filePath, QSqlQuery &query);
    QString m_dbPath;
};
