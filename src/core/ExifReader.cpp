#include "ExifReader.h"
#include "exif.h"
#include "ExifDatabase.h"
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QImageReader>
#include <QDateTime>
#include <QTimeZone>

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

struct Mp4Metadata {
    qint64 durationMs = 0;
    quint32 width = 0;
    quint32 height = 0;
    QDateTime creationTime;
    QString majorBrand;
};

static QString mapMajorBrand(const QString &brand)
{
    QString b = brand.trimmed().toLower();
    if (b == "qt") return "QuickTime Movie (MOV)";
    if (b == "mp41") return "MPEG-4 Video (MP4 v1)";
    if (b == "mp42") return "MPEG-4 Video (MP4 v2)";
    if (b == "isom") return "MPEG-4 Video (ISOM)";
    if (b == "avc1") return "H.264 / AVC Video";
    if (b == "mp4v") return "MPEG-4 Video";
    if (b == "m4v") return "Apple Video (M4V)";
    if (b == "hevc" || b == "hvc1") return "HEVC / H.265 Video";
    return b.isEmpty() ? "MPEG-4 Video" : QString("%1 Video").arg(brand.trimmed().toUpper());
}

static QString formatFriendlyDuration(qint64 durationMs)
{
    qint64 totalSecs = qRound(double(durationMs) / 1000.0);
    if (totalSecs <= 0) {
        if (durationMs > 0) return "1s";
        return "";
    }
    
    qint64 hours = totalSecs / 3600;
    qint64 mins = (totalSecs % 3600) / 60;
    qint64 secs = totalSecs % 60;
    
    if (hours > 0) {
        return QString("%1h %2m")
            .arg(hours)
            .arg(mins, 2, 10, QChar('0'));
    } else if (mins > 0) {
        return QString("%1m %2s")
            .arg(mins)
            .arg(secs, 2, 10, QChar('0'));
    } else {
        return QString("%1s").arg(secs);
    }
}


static Mp4Metadata readMp4Metadata(const QString &filePath)
{
    Mp4Metadata meta;
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) return meta;
    
    // Read first 128KB
    QByteArray data = file.read(128 * 1024);
    
    // 1. Read ftyp major brand
    int ftypIdx = data.indexOf("ftyp");
    if (ftypIdx != -1 && ftypIdx + 8 <= data.size()) {
        meta.majorBrand = QString::fromLatin1(data.mid(ftypIdx + 4, 4));
    }
    
    // Search for mvhd and tkhd in the first 128KB.
    int mvhdIdx = data.indexOf("mvhd");
    int tkhdIdx = data.indexOf("tkhd");
    
    // If either is missing, check the last 128KB of the file
    if ((mvhdIdx == -1 || tkhdIdx == -1) && file.size() > 128 * 1024) {
        if (file.seek(file.size() - 128 * 1024)) {
            QByteArray endData = file.readAll();
            if (mvhdIdx == -1) {
                int idx = endData.indexOf("mvhd");
                if (idx != -1) {
                    data = endData;
                    mvhdIdx = idx;
                    tkhdIdx = endData.indexOf("tkhd");
                }
            }
        }
    }
    
    // Parse mvhd (duration & creation time)
    if (mvhdIdx != -1 && mvhdIdx + 32 <= data.size()) {
        int offset = mvhdIdx + 4; // points to version
        quint8 version = (quint8)data.at(offset);
        
        quint32 timescale = 0;
        quint64 duration = 0;
        quint64 creationSeconds = 0;
        
        if (version == 0) {
            if (offset + 20 <= data.size()) {
                const uchar* p = (const uchar*)data.constData() + offset + 4;
                creationSeconds = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
                
                p = (const uchar*)data.constData() + offset + 12;
                timescale = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
                
                p = (const uchar*)data.constData() + offset + 16;
                duration = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
            }
        } else if (version == 1) {
            if (offset + 32 <= data.size()) {
                const uchar* p = (const uchar*)data.constData() + offset + 4;
                creationSeconds = ((quint64)p[0] << 56) | ((quint64)p[1] << 48) | ((quint64)p[2] << 40) | ((quint64)p[3] << 32)
                                 | ((quint64)p[4] << 24) | ((quint64)p[5] << 16) | ((quint64)p[6] << 8) | p[7];
                
                p = (const uchar*)data.constData() + offset + 20;
                timescale = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
                
                p = (const uchar*)data.constData() + offset + 24;
                duration = ((quint64)p[0] << 56) | ((quint64)p[1] << 48) | ((quint64)p[2] << 40) | ((quint64)p[3] << 32)
                         | ((quint64)p[4] << 24) | ((quint64)p[5] << 16) | ((quint64)p[6] << 8) | p[7];
            }
        }
        
        if (timescale > 0 && duration > 0) {
            meta.durationMs = (duration * 1000) / timescale;
        }
        
        if (creationSeconds > 0) {
            QDateTime epoch(QDate(1904, 1, 1), QTime(0, 0, 0), QTimeZone::fromSecondsAheadOfUtc(0));
            meta.creationTime = epoch.addSecs(creationSeconds);
        }
    }
    
    // Parse tkhd (video track dimensions)
    int currentTkhd = tkhdIdx;
    while (currentTkhd != -1) {
        int offset = currentTkhd + 4; // points to version
        if (offset < data.size()) {
            quint8 version = (quint8)data.at(offset);
            
            quint32 width = 0;
            quint32 height = 0;
            
            if (version == 0) {
                if (offset + 84 <= data.size()) {
                    const uchar* p = (const uchar*)data.constData() + offset + 76;
                    width = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
                    p = (const uchar*)data.constData() + offset + 80;
                    height = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
                }
            } else if (version == 1) {
                if (offset + 96 <= data.size()) {
                    const uchar* p = (const uchar*)data.constData() + offset + 88;
                    width = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
                    p = (const uchar*)data.constData() + offset + 92;
                    height = ((quint32)p[0] << 24) | ((quint32)p[1] << 16) | ((quint32)p[2] << 8) | p[3];
                }
            }
            
            width >>= 16;  // Fixed-point 16.16
            height >>= 16; // Fixed-point 16.16
            
            if (width > 0 && height > 0) {
                meta.width = width;
                meta.height = height;
                break; // Found the video track
            }
        }
        
        // Find next tkhd
        currentTkhd = data.indexOf("tkhd", currentTkhd + 4);
    }
    
    return meta;
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

    QString ext = fileInfo.suffix().toLower();
    bool isVideo = (ext == "mp4" || ext == "mov");

    if (m_db && m_db->isCached(filePath, fileInfo.size(), fileInfo.lastModified())) {
        QVariantMap cachedData = m_db->getExifData(filePath);
        if (!cachedData.isEmpty() && !cachedData.value("FileSize").toString().isEmpty()) {
            data = cachedData;
            bool updated = false;
            
            if (isVideo) {
                // Backfill dimensions if missing
                if (data.value("Dimensions").toString().isEmpty()) {
                    Mp4Metadata meta = readMp4Metadata(filePath);
                    if (meta.width > 0 && meta.height > 0) {
                        data["Dimensions"] = QString("%1x%2").arg(meta.width).arg(meta.height);
                        updated = true;
                    }
                }
                // Backfill duration if missing
                if (data.value("Duration").toString().isEmpty()) {
                    Mp4Metadata meta = readMp4Metadata(filePath);
                    if (meta.durationMs > 0) {
                        data["Duration"] = formatFriendlyDuration(meta.durationMs);
                        updated = true;
                    }
                }
                // Backfill brand/model if missing
                if (data.value("Model").toString().isEmpty()) {
                    Mp4Metadata meta = readMp4Metadata(filePath);
                    if (!meta.majorBrand.isEmpty()) {
                        data["Model"] = mapMajorBrand(meta.majorBrand);
                        data["Make"] = "Video File";
                        updated = true;
                    }
                }
            } else {
                // Photo: backfill dimensions if missing
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
            }
            
            // Backfill DateTime with fs timestamp if it is empty
            if (data.value("DateTime").toString().isEmpty()) {
                data["DateTime"] = fileInfo.lastModified().toString("yyyy:MM:dd HH:mm:ss");
                updated = true;
            }
            
            if (updated) {
                m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), data);
            }
            
            data["IsVideo"] = isVideo;
            return data;
        }
    }

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
        
        Mp4Metadata meta = readMp4Metadata(filePath);
        if (!meta.majorBrand.isEmpty()) {
            data["Model"] = mapMajorBrand(meta.majorBrand);
            data["Make"] = "Video File";
        } else {
            data["Model"] = "Video File";
            data["Make"] = "";
        }
        
        if (meta.width > 0 && meta.height > 0) {
            data["Dimensions"] = QString("%1x%2").arg(meta.width).arg(meta.height);
        } else {
            data["Dimensions"] = "";
        }
        
        if (meta.creationTime.isValid()) {
            data["DateTime"] = meta.creationTime.toLocalTime().toString("yyyy:MM:dd HH:mm:ss");
        } else {
            data["DateTime"] = fileInfo.lastModified().toString("yyyy:MM:dd HH:mm:ss");
        }
        
        if (meta.durationMs > 0) {
            data["Duration"] = formatFriendlyDuration(meta.durationMs);
        } else {
            data["Duration"] = "";
        }
        
        if (m_db) {
            m_db->saveExifData(filePath, fileInfo.size(), fileInfo.lastModified(), data);
        }
        data["IsVideo"] = isVideo;
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
        data["IsVideo"] = isVideo;
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
        data["IsVideo"] = isVideo;
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

    data["IsVideo"] = isVideo;
    return data;
}
