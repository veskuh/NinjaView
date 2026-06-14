#include "ExifReader.h"
#include "exif.h"
#include "ExifDatabase.h"
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QImageReader>

static QString cleanExifString(const std::string &s)
{
    // Use c_str() to stop at the first null byte if present
    QString res = QString::fromUtf8(s.c_str());
    QString cleaned;
    for (const QChar &c : res) {
        if (c.isPrint()) {
            cleaned.append(c);
        } else {
            break; // Stop at any non-printable character
        }
    }
    return cleaned.trimmed();
}

ExifReader::ExifReader(QObject *parent)
    : QObject(parent)
{
}

void ExifReader::setDatabase(ExifDatabase *db)
{
    m_db = db;
}

QVariantMap ExifReader::getExifData(const QString &filePath)
{
    QVariantMap data;
    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists() || fileInfo.isDir()) {
        return data;
    }

    if (m_db && m_db->isCached(filePath, fileInfo.size(), fileInfo.lastModified())) {
        data = m_db->getExifData(filePath);
        bool updated = false;
        // Backfill dimensions if they are missing from existing database record
        if (data.value("Dimensions").toString().isEmpty()) {
            QImageReader reader(filePath);
            if (reader.canRead()) {
                QSize imgSize = reader.size();
                if (imgSize.isValid()) {
                    QString dim = QString("%1x%2").arg(imgSize.width()).arg(imgSize.height());
                    data["Dimensions"] = dim;
                    updated = true;
                }
            }
        }
        // Backfill DateTime with fs timestamp if it is empty
        if (data.value("DateTime").toString().isEmpty()) {
            data["DateTime"] = fileInfo.lastModified().toString("yyyy:MM:dd HH:mm:ss");
            updated = true;
        }
        if (updated) {
            m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), data);
        }
        return data;
    }

    // Check if it is a video file to avoid reading large files into memory
    QString ext = fileInfo.suffix().toLower();
    bool isVideo = (ext == "mp4" || ext == "mov");
    if (isVideo) {
        qint64 sizeInBytes = fileInfo.size();
        QString sizeStr;
        if (sizeInBytes >= 1024 * 1024) {
            sizeStr = QString("%1 MB").arg(double(sizeInBytes) / (1024.0 * 1024.0), 0, 'f', 2);
        } else if (sizeInBytes >= 1024) {
            sizeStr = QString("%1 KB").arg(double(sizeInBytes) / 1024.0, 0, 'f', 1);
        } else {
            sizeStr = QString("%1 B").arg(sizeInBytes);
        }
        data["FileSize"] = sizeStr;
        data["DateTime"] = fileInfo.lastModified().toString("yyyy:MM:dd HH:mm:ss");
        
        if (m_db) {
            m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), data);
        }
        return data;
    }

    // Extract basic properties
    QImageReader reader(filePath);
    if (reader.canRead()) {
        QSize imgSize = reader.size();
        if (imgSize.isValid()) {
            data["Dimensions"] = QString("%1x%2").arg(imgSize.width()).arg(imgSize.height());
        }
    }

    qint64 sizeInBytes = fileInfo.size();
    QString sizeStr;
    if (sizeInBytes >= 1024 * 1024) {
        sizeStr = QString("%1 MB").arg(double(sizeInBytes) / (1024.0 * 1024.0), 0, 'f', 2);
    } else if (sizeInBytes >= 1024) {
        sizeStr = QString("%1 KB").arg(double(sizeInBytes) / 1024.0, 0, 'f', 1);
    } else {
        sizeStr = QString("%1 B").arg(sizeInBytes);
    }
    data["FileSize"] = sizeStr;
    // Fallback timestamp using last modified time
    data["DateTime"] = fileInfo.lastModified().toString("yyyy:MM:dd HH:mm:ss");

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "ExifReader: Cannot open file" << filePath;
        if (m_db) {
            m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), data);
        }
        return data;
    }

    QByteArray buffer = file.readAll();
    file.close();

    easyexif::EXIFInfo info;
    if (info.parseFrom((unsigned char *)buffer.data(), buffer.size()) != 0) {
        // No EXIF data, save basic info to cache and return
        if (m_db) {
            m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), data);
        }
        return data;
    }

    data["Make"] = cleanExifString(info.Make);
    data["Model"] = cleanExifString(info.Model);
    data["Exposure"] = info.ExposureTime > 0 ? (info.ExposureTime < 1.0 ? QString("1/%1").arg(qRound(1.0 / info.ExposureTime)) : QString("%1s").arg(info.ExposureTime)) : "0";
    data["Aperture"] = QString("f/%1").arg(info.FNumber, 0, 'f', 1);
    data["ISO"] = (int)info.ISOSpeedRatings;
    
    QString focalLength = QString("%1mm").arg(info.FocalLength, 0, 'f', 1);
    if (info.FocalLengthIn35mm > 0) {
        focalLength += QString(" (35mm: %1mm)").arg(info.FocalLengthIn35mm);
    }
    data["FocalLength"] = focalLength;
    
    QString exifDate = cleanExifString(info.DateTime);
    if (!exifDate.isEmpty()) {
        data["DateTime"] = exifDate;
    }
    
    // Improved Lens info
    QString lensModel = cleanExifString(info.LensInfo.Model);
    QString lensMake = cleanExifString(info.LensInfo.Make);
    
    QString lensInfo;
    if (!lensMake.isEmpty()) {
        lensInfo = lensMake;
    }
    if (!lensModel.isEmpty()) {
        if (!lensInfo.isEmpty() && !lensModel.startsWith(lensInfo, Qt::CaseInsensitive)) {
            lensInfo += " " + lensModel;
        } else {
            lensInfo = lensModel;
        }
    }
    
    // Fallback if LensModel is missing but we have specs
    if (lensInfo.isEmpty() && info.LensInfo.FocalLengthMin > 0) {
        if (info.LensInfo.FocalLengthMin == info.LensInfo.FocalLengthMax) {
            lensInfo = QString("%1mm").arg(info.LensInfo.FocalLengthMin);
        } else {
            lensInfo = QString("%1-%2mm").arg(info.LensInfo.FocalLengthMin).arg(info.LensInfo.FocalLengthMax);
        }
        
        if (info.LensInfo.FStopMin > 0) {
            if (info.LensInfo.FStopMin == info.LensInfo.FStopMax || info.LensInfo.FStopMax == 0) {
                lensInfo += QString(" f/%1").arg(info.LensInfo.FStopMin);
            } else {
                lensInfo += QString(" f/%1-%2").arg(info.LensInfo.FStopMin).arg(info.LensInfo.FStopMax);
            }
        }
    }
    
    data["Lens"] = lensInfo;

    if (m_db) {
        m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), data);
    }

    return data;
}
