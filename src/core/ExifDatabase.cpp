#include "ExifDatabase.h"
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QThread>
#include <QUrl>
#include <QFileInfo>
#include <QSet>

ExifDatabase::ExifDatabase(const QString &dbPath, QObject *parent)
    : QObject(parent)
{
    if (!dbPath.isEmpty()) {
        m_dbPath = dbPath;
    } else {
        QString appData = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir dir(appData);
        if (!dir.exists()) {
            dir.mkpath(".");
        }
        m_dbPath = appData + "/exif_cache.db";
    }
    qDebug() << "ExifDatabase: DB Path initialized to" << m_dbPath;
}

ExifDatabase::~ExifDatabase()
{
    // Close and remove all database connections created by this instance
    const QStringList connections = QSqlDatabase::connectionNames();
    for (const QString &connName : connections) {
        if (connName.startsWith("exif_db_conn_")) {
            QSqlDatabase::removeDatabase(connName);
        }
    }
}

QSqlDatabase ExifDatabase::getDatabaseConnection()
{
    QString connName = QString("exif_db_conn_%1").arg(quintptr(QThread::currentThreadId()));
    if (QSqlDatabase::contains(connName)) {
        QSqlDatabase db = QSqlDatabase::database(connName);
        if (db.isOpen()) {
            return db;
        }
    }
    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
    db.setDatabaseName(m_dbPath);
    if (!db.open()) {
        qWarning() << "ExifDatabase: Failed to open connection" << connName << "-" << db.lastError().text();
    }
    return db;
}

bool ExifDatabase::init()
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) {
        return false;
    }
    QSqlQuery query(db);
    bool ok = query.exec("CREATE TABLE IF NOT EXISTS exif_cache ("
                         "file_path TEXT PRIMARY KEY, "
                         "file_size INTEGER, "
                         "last_modified TEXT, "
                         "make TEXT, "
                         "model TEXT, "
                         "lens TEXT, "
                         "exposure TEXT, "
                         "aperture TEXT, "
                         "iso INTEGER, "
                         "datetime TEXT, "
                         "dimensions TEXT DEFAULT '', "
                         "duration TEXT DEFAULT ''"
                         ")");
    if (!ok) {
        qWarning() << "ExifDatabase: Schema creation failed -" << query.lastError().text();
        return false;
    }

    // Check and add missing columns dynamically: favorite, notes, tags, dimensions, duration
    if (query.exec("PRAGMA table_info(exif_cache)")) {
        QSet<QString> columns;
        while (query.next()) {
            columns.insert(query.value(1).toString());
        }
        if (!columns.contains("favorite")) {
            if (!query.exec("ALTER TABLE exif_cache ADD COLUMN favorite INTEGER DEFAULT 0")) {
                qWarning() << "ExifDatabase: Failed to add favorite column -" << query.lastError().text();
            }
        }
        if (!columns.contains("notes")) {
            if (!query.exec("ALTER TABLE exif_cache ADD COLUMN notes TEXT DEFAULT ''")) {
                qWarning() << "ExifDatabase: Failed to add notes column -" << query.lastError().text();
            }
        }
        if (!columns.contains("tags")) {
            if (!query.exec("ALTER TABLE exif_cache ADD COLUMN tags TEXT DEFAULT ''")) {
                qWarning() << "ExifDatabase: Failed to add tags column -" << query.lastError().text();
            }
        }
        if (!columns.contains("dimensions")) {
            if (!query.exec("ALTER TABLE exif_cache ADD COLUMN dimensions TEXT DEFAULT ''")) {
                qWarning() << "ExifDatabase: Failed to add dimensions column -" << query.lastError().text();
            }
        }
        if (!columns.contains("focal_length")) {
            if (!query.exec("ALTER TABLE exif_cache ADD COLUMN focal_length TEXT DEFAULT ''")) {
                qWarning() << "ExifDatabase: Failed to add focal_length column -" << query.lastError().text();
            }
        }
        if (!columns.contains("duration")) {
            if (!query.exec("ALTER TABLE exif_cache ADD COLUMN duration TEXT DEFAULT ''")) {
                qWarning() << "ExifDatabase: Failed to add duration column -" << query.lastError().text();
            }
        }
    } else {
        qWarning() << "ExifDatabase: Failed to query table schema info -" << query.lastError().text();
    }

    qDebug() << "ExifDatabase: Schema initialized successfully";
    return true;
}

bool ExifDatabase::isCached(const QString &filePath, qint64 fileSize, const QDateTime &lastModified)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    QSqlQuery query(db);
    query.prepare("SELECT file_size, last_modified FROM exif_cache WHERE file_path = :path");
    query.bindValue(":path", filePath);
    
    if (query.exec() && query.next()) {
        qint64 size = query.value(0).toLongLong();
        QString modStr = query.value(1).toString();
        if (size == fileSize && modStr == lastModified.toString(Qt::ISODate)) {
            return true;
        }
    }
    return false;
}

QVariantMap ExifDatabase::getExifData(const QString &filePath)
{
    QVariantMap data;
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return data;

    QSqlQuery query(db);
    query.prepare("SELECT make, model, lens, exposure, aperture, iso, datetime, favorite, notes, tags, dimensions, file_size, focal_length, duration FROM exif_cache WHERE file_path = :path");
    query.bindValue(":path", filePath);

    if (query.exec() && query.next()) {
        data["Make"] = query.value(0).toString();
        data["Model"] = query.value(1).toString();
        data["Lens"] = query.value(2).toString();
        data["Exposure"] = query.value(3).toString();
        data["Aperture"] = query.value(4).toString();
        data["ISO"] = query.value(5).toInt();
        data["DateTime"] = query.value(6).toString();
        data["Favorite"] = query.value(7).toInt() == 1;
        data["Notes"] = query.value(8).toString();
        data["Tags"] = query.value(9).toString();
        data["Dimensions"] = query.value(10).toString();
        data["FocalLength"] = query.value(12).toString();
        data["Duration"] = query.value(13).toString();
        
        qint64 sizeInBytes = query.value(11).toLongLong();
        QString sizeStr;
        if (sizeInBytes >= 1024 * 1024) {
            sizeStr = QString("%1 MB").arg(double(sizeInBytes) / (1024.0 * 1024.0), 0, 'f', 2);
        } else if (sizeInBytes >= 1024) {
            sizeStr = QString("%1 KB").arg(double(sizeInBytes) / 1024.0, 0, 'f', 1);
        } else {
            sizeStr = QString("%1 B").arg(sizeInBytes);
        }
        data["FileSize"] = sizeStr;
    }
    return data;
}

bool ExifDatabase::saveExifData(const QString &filePath, qint64 fileSize, const QDateTime &lastModified, const QVariantMap &exifData)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    QSqlQuery query(db);
    
    // Check if record already exists
    query.prepare("SELECT COUNT(*) FROM exif_cache WHERE file_path = :path");
    query.bindValue(":path", filePath);
    bool exists = false;
    if (query.exec() && query.next()) {
        exists = query.value(0).toInt() > 0;
    }

    if (exists) {
        // Update existing record, preserving user favorite/notes/tags
        query.prepare("UPDATE exif_cache SET "
                      "file_size = :size, last_modified = :modified, "
                      "make = :make, model = :model, lens = :lens, "
                      "exposure = :exposure, aperture = :aperture, "
                      "iso = :iso, datetime = :datetime, dimensions = :dimensions, "
                      "focal_length = :focal_length, duration = :duration "
                      "WHERE file_path = :path");
    } else {
        // Insert new record with defaults for favorite/notes/tags
        query.prepare("INSERT INTO exif_cache "
                      "(file_path, file_size, last_modified, make, model, lens, exposure, aperture, iso, datetime, favorite, notes, tags, dimensions, focal_length, duration) "
                      "VALUES (:path, :size, :modified, :make, :model, :lens, :exposure, :aperture, :iso, :datetime, 0, '', '', :dimensions, :focal_length, :duration)");
    }

    query.bindValue(":path", filePath);
    query.bindValue(":size", fileSize);
    query.bindValue(":modified", lastModified.toString(Qt::ISODate));
    query.bindValue(":make", exifData.value("Make").toString());
    query.bindValue(":model", exifData.value("Model").toString());
    query.bindValue(":lens", exifData.value("Lens").toString());
    query.bindValue(":exposure", exifData.value("Exposure").toString());
    query.bindValue(":aperture", exifData.value("Aperture").toString());
    query.bindValue(":iso", exifData.value("ISO").toInt());
    query.bindValue(":datetime", exifData.value("DateTime").toString());
    query.bindValue(":dimensions", exifData.value("Dimensions").toString());
    query.bindValue(":focal_length", exifData.value("FocalLength").toString());
    query.bindValue(":duration", exifData.value("Duration").toString());

    bool ok = query.exec();
    if (!ok) {
        qWarning() << "ExifDatabase: Save failed for" << filePath << "-" << query.lastError().text();
    }
    return ok;
}

QStringList ExifDatabase::getUniqueCamerasForFolder(const QString &folderPath)
{
    QStringList cameras;
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return cameras;

    QSqlQuery query(db);
    bool isSmartMedia = (folderPath == "smart://media");
    if (isSmartMedia) {
        query.prepare("SELECT DISTINCT make, model FROM exif_cache WHERE (file_path LIKE :picPrefix OR file_path LIKE :movPrefix) AND make IS NOT NULL AND make != ''");
        QString picPrefix = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)) + "/%";
        QString movPrefix = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)) + "/%";
        query.bindValue(":picPrefix", picPrefix);
        query.bindValue(":movPrefix", movPrefix);
    } else {
        query.prepare("SELECT DISTINCT make, model FROM exif_cache WHERE file_path LIKE :prefix AND make IS NOT NULL AND make != ''");
        QString prefix = folderPath;
        if (prefix == "smart://pictures") {
            prefix = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
        } else if (prefix == "smart://videos") {
            prefix = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
        } else if (prefix.startsWith("file://")) {
            prefix = QUrl(prefix).toLocalFile();
        }
        prefix = QDir::cleanPath(prefix);
        if (!prefix.endsWith("/")) {
            prefix += "/";
        }
        query.bindValue(":prefix", prefix + "%");
    }

    if (query.exec()) {
        while (query.next()) {
            QString make = query.value(0).toString().trimmed();
            QString model = query.value(1).toString().trimmed();

            // Clean up name
            QString camera = make;
            if (!model.isEmpty() && !model.startsWith(make, Qt::CaseInsensitive)) {
                camera += " " + model;
            }
            if (!cameras.contains(camera)) {
                cameras << camera;
            }
        }
    } else {
        qWarning() << "ExifDatabase: Failed to query unique cameras -" << query.lastError().text();
    }
    return cameras;
}

QVariantMap ExifDatabase::getAvailableFiltersForFolder(const QString &folderPath)
{
    QVariantMap result;
    result["hasToday"] = false;
    result["hasThisWeek"] = false;
    result["hasThisMonth"] = false;
    result["years"] = QStringList();
    result["imageTypes"] = QStringList();

    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return result;

    QSqlQuery query(db);
    bool isSmartMedia = (folderPath == "smart://media");
    if (isSmartMedia) {
        query.prepare("SELECT file_path, last_modified, datetime FROM exif_cache WHERE (file_path LIKE :picPrefix OR file_path LIKE :movPrefix)");
        QString picPrefix = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)) + "/%";
        QString movPrefix = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)) + "/%";
        query.bindValue(":picPrefix", picPrefix);
        query.bindValue(":movPrefix", movPrefix);
    } else {
        query.prepare("SELECT file_path, last_modified, datetime FROM exif_cache WHERE file_path LIKE :prefix");
        QString prefix = folderPath;
        if (prefix == "smart://pictures") {
            prefix = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
        } else if (prefix == "smart://videos") {
            prefix = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
        } else if (prefix.startsWith("file://")) {
            prefix = QUrl(prefix).toLocalFile();
        }
        prefix = QDir::cleanPath(prefix);
        if (!prefix.endsWith("/")) {
            prefix += "/";
        }
        query.bindValue(":prefix", prefix + "%");
    }

    bool hasToday = false;
    bool hasThisWeek = false;
    bool hasThisMonth = false;
    QSet<int> yearsSet;
    QSet<QString> imageTypesSet;
    QDate current = QDate::currentDate();

    if (query.exec()) {
        while (query.next()) {
            QString filePath = query.value(0).toString();
            QString modStr = query.value(1).toString();
            QString exifStr = query.value(2).toString();

            // Extract extension
            int lastDot = filePath.lastIndexOf('.');
            if (lastDot != -1) {
                QString ext = filePath.mid(lastDot + 1).toUpper();
                if (ext == "JPEG") ext = "JPG";
                bool ok = false;
                if (folderPath == "smart://pictures") {
                    ok = (ext == "JPG" || ext == "PNG" || ext == "WEBP" || ext == "BMP");
                } else if (folderPath == "smart://videos") {
                    ok = (ext == "MP4" || ext == "MOV");
                } else {
                    ok = (ext == "JPG" || ext == "PNG" || ext == "WEBP" || ext == "BMP" || ext == "MP4" || ext == "MOV");
                }
                if (ok) {
                    imageTypesSet.insert(ext);
                }
            }

            QDateTime fileDate;
            if (!exifStr.isEmpty()) {
                QDateTime parsed = QDateTime::fromString(exifStr, "yyyy:MM:dd HH:mm:ss");
                if (parsed.isValid()) {
                    fileDate = parsed;
                }
            }
            if (!fileDate.isValid() && !modStr.isEmpty()) {
                fileDate = QDateTime::fromString(modStr, Qt::ISODate);
            }

            if (fileDate.isValid()) {
                QDate date = fileDate.date();
                if (date == current) {
                    hasToday = true;
                }
                if (date >= current.addDays(-7) && date <= current) {
                    hasThisWeek = true;
                }
                if (date.month() == current.month() && date.year() == current.year()) {
                    hasThisMonth = true;
                }
                yearsSet.insert(date.year());
            }
        }
    }

    result["hasToday"] = hasToday;
    result["hasThisWeek"] = hasThisWeek;
    result["hasThisMonth"] = hasThisMonth;

    QList<int> sortedYears = yearsSet.values();
    std::sort(sortedYears.begin(), sortedYears.end(), std::greater<int>());
    QStringList yearsList;
    for (int y : sortedYears) {
        yearsList << QString::number(y);
    }
    result["years"] = yearsList;

    QStringList imageTypesList = imageTypesSet.values();
    std::sort(imageTypesList.begin(), imageTypesList.end());
    result["imageTypes"] = imageTypesList;

    return result;
}

bool ExifDatabase::clear()
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    QSqlQuery query(db);
    bool ok = query.exec("DELETE FROM exif_cache");
    if (!ok) {
        qWarning() << "ExifDatabase: Clear failed -" << query.lastError().text();
    } else {
        qDebug() << "ExifDatabase: Database cleared successfully";
        emit favoritesChanged();
        emit notesChanged("");
        emit tagsChanged();
    }
    return ok;
}

bool ExifDatabase::ensureRecordExists(const QString &filePath, QSqlQuery &query)
{
    query.prepare("SELECT COUNT(*) FROM exif_cache WHERE file_path = :path");
    query.bindValue(":path", filePath);
    if (query.exec() && query.next() && query.value(0).toInt() > 0) {
        return true; // Already exists
    }

    // Doesn't exist, retrieve filesystem info and create a basic record
    QFileInfo fileInfo(filePath);
    query.prepare("INSERT INTO exif_cache "
                  "(file_path, file_size, last_modified, make, model, lens, exposure, aperture, iso, datetime, favorite, notes, tags, dimensions, focal_length, duration) "
                  "VALUES (:path, :size, :modified, '', '', '', '', '', 0, '', 0, '', '', '', '', '')");
    query.bindValue(":path", filePath);
    query.bindValue(":size", fileInfo.exists() ? fileInfo.size() : 0);
    query.bindValue(":modified", fileInfo.exists() ? fileInfo.lastModified().toString(Qt::ISODate) : QDateTime::currentDateTime().toString(Qt::ISODate));
    return query.exec();
}

bool ExifDatabase::setFavorite(const QString &filePath, bool favorite)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    QSqlQuery query(db);
    if (!ensureRecordExists(filePath, query)) return false;

    query.prepare("UPDATE exif_cache SET favorite = :fav WHERE file_path = :path");
    query.bindValue(":fav", favorite ? 1 : 0);
    query.bindValue(":path", filePath);
    bool ok = query.exec();
    if (ok) {
        emit favoritesChanged();
    }
    return ok;
}

bool ExifDatabase::isFavorite(const QString &filePath)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    QSqlQuery query(db);
    query.prepare("SELECT favorite FROM exif_cache WHERE file_path = :path");
    query.bindValue(":path", filePath);
    if (query.exec() && query.next()) {
        return query.value(0).toInt() == 1;
    }
    return false;
}

bool ExifDatabase::setNotes(const QString &filePath, const QString &notes)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    QSqlQuery query(db);
    if (!ensureRecordExists(filePath, query)) return false;

    query.prepare("UPDATE exif_cache SET notes = :notes WHERE file_path = :path");
    query.bindValue(":notes", notes);
    query.bindValue(":path", filePath);
    bool ok = query.exec();
    if (ok) {
        emit notesChanged(filePath);
    }
    return ok;
}

QString ExifDatabase::getNotes(const QString &filePath)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return "";

    QSqlQuery query(db);
    query.prepare("SELECT notes FROM exif_cache WHERE file_path = :path");
    query.bindValue(":path", filePath);
    if (query.exec() && query.next()) {
        return query.value(0).toString();
    }
    return "";
}

bool ExifDatabase::setTags(const QString &filePath, const QString &tags)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    QSqlQuery query(db);
    if (!ensureRecordExists(filePath, query)) return false;

    // Clean tags: trim whitespace and normalize commas
    QStringList cleanedList;
    for (const QString &tag : tags.split(',')) {
        QString trimmed = tag.trimmed();
        if (!trimmed.isEmpty()) {
            cleanedList << trimmed;
        }
    }
    QString cleanedTags = cleanedList.join(",");

    query.prepare("UPDATE exif_cache SET tags = :tags WHERE file_path = :path");
    query.bindValue(":tags", cleanedTags);
    query.bindValue(":path", filePath);
    bool ok = query.exec();
    if (ok) {
        emit tagsChanged();
    }
    return ok;
}

QString ExifDatabase::getTags(const QString &filePath)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return "";

    QSqlQuery query(db);
    query.prepare("SELECT tags FROM exif_cache WHERE file_path = :path");
    query.bindValue(":path", filePath);
    if (query.exec() && query.next()) {
        return query.value(0).toString();
    }
    return "";
}

QStringList ExifDatabase::getAllTags()
{
    QStringList allTags;
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return allTags;

    QSqlQuery query(db);
    query.prepare("SELECT tags FROM exif_cache WHERE tags IS NOT NULL AND tags != ''");
    QSet<QString> tagSet;
    if (query.exec()) {
        while (query.next()) {
            QString tagsStr = query.value(0).toString();
            for (const QString &tag : tagsStr.split(',')) {
                QString trimmed = tag.trimmed();
                if (!trimmed.isEmpty()) {
                    tagSet.insert(trimmed);
                }
            }
        }
    }
    allTags = tagSet.values();
    std::sort(allTags.begin(), allTags.end());
    return allTags;
}

QStringList ExifDatabase::getFavorites()
{
    QStringList paths;
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return paths;

    QSqlQuery query(db);
    query.prepare("SELECT file_path FROM exif_cache WHERE favorite = 1");
    if (query.exec()) {
        while (query.next()) {
            paths << query.value(0).toString();
        }
    }
    return paths;
}

QStringList ExifDatabase::getImagesWithTag(const QString &tag)
{
    QStringList paths;
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return paths;

    QSqlQuery query(db);
    query.prepare("SELECT file_path FROM exif_cache WHERE ',' || tags || ',' LIKE :pattern");
    query.bindValue(":pattern", "%," + tag.trimmed() + ",%");
    if (query.exec()) {
        while (query.next()) {
            paths << query.value(0).toString();
        }
    }
    return paths;
}

bool ExifDatabase::setFavoriteBatch(const QStringList &filePaths, bool favorite)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    db.transaction();
    QSqlQuery query(db);
    for (const QString &path : filePaths) {
        if (!ensureRecordExists(path, query)) continue;
        query.prepare("UPDATE exif_cache SET favorite = :fav WHERE file_path = :path");
        query.bindValue(":fav", favorite ? 1 : 0);
        query.bindValue(":path", path);
        query.exec();
    }
    bool ok = db.commit();
    if (ok) {
        emit favoritesChanged();
    }
    return ok;
}

bool ExifDatabase::setTagsBatch(const QStringList &filePaths, const QString &tags, bool append)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    // Clean and normalize the tags input first
    QStringList inputList;
    for (const QString &tag : tags.split(',')) {
        QString trimmed = tag.trimmed();
        if (!trimmed.isEmpty()) {
            inputList << trimmed;
        }
    }
    QString cleanedInput = inputList.join(",");

    db.transaction();
    QSqlQuery query(db);
    for (const QString &path : filePaths) {
        if (!ensureRecordExists(path, query)) continue;
        
        QString newTagsStr = cleanedInput;
        if (append) {
            QSqlQuery getQuery(db);
            getQuery.prepare("SELECT tags FROM exif_cache WHERE file_path = :path");
            getQuery.bindValue(":path", path);
            QString currentTags;
            if (getQuery.exec() && getQuery.next()) {
                currentTags = getQuery.value(0).toString().trimmed();
            }
            
            if (!currentTags.isEmpty()) {
                QStringList currentList = currentTags.split(',', Qt::SkipEmptyParts);
                for (const QString &t : inputList) {
                    if (!currentList.contains(t, Qt::CaseInsensitive)) {
                        currentList.append(t);
                    }
                }
                newTagsStr = currentList.join(",");
            }
        }
        
        query.prepare("UPDATE exif_cache SET tags = :tags WHERE file_path = :path");
        query.bindValue(":tags", newTagsStr);
        query.bindValue(":path", path);
        query.exec();
    }
    bool ok = db.commit();
    if (ok) {
        emit tagsChanged();
    }
    return ok;
}

bool ExifDatabase::setNotesBatch(const QStringList &filePaths, const QString &notes, bool append)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    db.transaction();
    QSqlQuery query(db);
    for (const QString &path : filePaths) {
        if (!ensureRecordExists(path, query)) continue;
        
        QString newNotes = notes;
        if (append) {
            QSqlQuery getQuery(db);
            getQuery.prepare("SELECT notes FROM exif_cache WHERE file_path = :path");
            getQuery.bindValue(":path", path);
            QString currentNotes;
            if (getQuery.exec() && getQuery.next()) {
                currentNotes = getQuery.value(0).toString();
            }
            if (!currentNotes.isEmpty()) {
                newNotes = currentNotes + "\n" + notes;
            }
        }
        
        query.prepare("UPDATE exif_cache SET notes = :notes WHERE file_path = :path");
        query.bindValue(":notes", newNotes);
        query.bindValue(":path", path);
        query.exec();
    }
    bool ok = db.commit();
    if (ok) {
        emit notesChanged("");
    }
    return ok;
}

bool ExifDatabase::updateCommonTagsBatch(const QStringList &filePaths, const QString &newCommonTags, const QString &oldCommonTags)
{
    QSqlDatabase db = getDatabaseConnection();
    if (!db.isOpen()) return false;

    // Clean and split tags
    QStringList oldTags;
    for (const QString &t : oldCommonTags.split(',')) {
        QString trimmed = t.trimmed();
        if (!trimmed.isEmpty()) oldTags << trimmed;
    }

    QStringList newTags;
    for (const QString &t : newCommonTags.split(',')) {
        QString trimmed = t.trimmed();
        if (!trimmed.isEmpty()) newTags << trimmed;
    }

    // Find tags to add: in newTags but not in oldTags (case-insensitive)
    QStringList tagsToAdd;
    for (const QString &t : newTags) {
        bool found = false;
        for (const QString &ot : oldTags) {
            if (ot.compare(t, Qt::CaseInsensitive) == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            tagsToAdd << t;
        }
    }

    // Find tags to remove: in oldTags but not in newTags (case-insensitive)
    QStringList tagsToRemove;
    for (const QString &ot : oldTags) {
        bool found = false;
        for (const QString &nt : newTags) {
            if (nt.compare(ot, Qt::CaseInsensitive) == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            tagsToRemove << ot;
        }
    }

    // If there is nothing to add and nothing to remove, we don't need to do anything
    if (tagsToAdd.isEmpty() && tagsToRemove.isEmpty()) {
        return true;
    }

    db.transaction();
    QSqlQuery query(db);
    for (const QString &path : filePaths) {
        if (!ensureRecordExists(path, query)) continue;

        // Fetch current tags
        QSqlQuery getQuery(db);
        getQuery.prepare("SELECT tags FROM exif_cache WHERE file_path = :path");
        getQuery.bindValue(":path", path);
        QString currentTagsStr;
        if (getQuery.exec() && getQuery.next()) {
            currentTagsStr = getQuery.value(0).toString().trimmed();
        }

        QStringList currentTags = currentTagsStr.split(',', Qt::SkipEmptyParts);
        for (int i = 0; i < currentTags.size(); ++i) {
            currentTags[i] = currentTags[i].trimmed();
        }

        // Remove tags in tagsToRemove (case-insensitive)
        for (const QString &tr : tagsToRemove) {
            for (int i = currentTags.size() - 1; i >= 0; --i) {
                if (currentTags[i].compare(tr, Qt::CaseInsensitive) == 0) {
                    currentTags.removeAt(i);
                }
            }
        }

        // Add tags in tagsToAdd (avoiding case-insensitive duplicates)
        for (const QString &ta : tagsToAdd) {
            bool exists = false;
            for (const QString &ct : currentTags) {
                if (ct.compare(ta, Qt::CaseInsensitive) == 0) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                currentTags.append(ta);
            }
        }

        QString updatedTagsStr = currentTags.join(",");

        query.prepare("UPDATE exif_cache SET tags = :tags WHERE file_path = :path");
        query.bindValue(":tags", updatedTagsStr);
        query.bindValue(":path", path);
        query.exec();
    }

    bool commitOk = db.commit();
    if (commitOk) {
        emit tagsChanged();
    }
    return commitOk;
}

