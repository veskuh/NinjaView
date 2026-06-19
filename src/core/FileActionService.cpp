#include "FileActionService.h"
#include "AsyncImageProvider.h"
#include "exif.h"
#include <QDesktopServices>
#include <QUrl>
#include <QFileInfo>
#include <QProcess>
#include <QFile>
#include <QDebug>
#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QImage>

FileActionService::FileActionService(QObject *parent) : QObject(parent)
{
}

void FileActionService::showInFolder(const QString &filePath)
{
    QString localPath = filePath;
    if (filePath.startsWith("file://")) {
        localPath = QUrl(filePath).toLocalFile();
    }

#ifdef Q_OS_MAC
    QStringList args;
    args << "-e" << "tell application \"Finder\""
         << "-e" << QString("reveal POSIX file \"%1\"").arg(localPath)
         << "-e" << "activate"
         << "-e" << "end tell";
    QProcess::execute("osascript", args);
#else
    QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(localPath).absolutePath()));
#endif
}

void FileActionService::openExternally(const QString &filePath)
{
    QString localPath = filePath;
    if (filePath.startsWith("file://")) {
        localPath = QUrl(filePath).toLocalFile();
    }
    QDesktopServices::openUrl(QUrl::fromLocalFile(localPath));
}

bool FileActionService::moveToTrash(const QString &filePath)
{
    QString localPath = filePath;
    if (filePath.startsWith("file://")) {
        localPath = QUrl(filePath).toLocalFile();
    }
    
    qDebug() << "Moving to trash:" << localPath;
    return QFile::moveToTrash(localPath);
}

void FileActionService::setImageProvider(AsyncImageProvider *provider)
{
    m_imageProvider = provider;
}

int FileActionService::rotateImage(const QString &filePath, int angle)
{
    QString localPath = filePath;
    if (filePath.startsWith("file://")) {
        localPath = QUrl(filePath).toLocalFile();
    }
    
    QFileInfo fileInfo(localPath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        qWarning() << "rotateImage: File does not exist:" << localPath;
        return -1;
    }
    
    QString ext = fileInfo.suffix().toLower();
    if (ext != "jpg" && ext != "jpeg") {
        qWarning() << "rotateImage: Only JPEG is supported for lossless rotation:" << localPath;
        return -1;
    }

    int normalizedAngle = (angle % 360 + 360) % 360;
    if (normalizedAngle != 90 && normalizedAngle != 180 && normalizedAngle != 270) {
        qWarning() << "rotateImage: Invalid angle:" << angle;
        return -1;
    }

    // Check if the file is writable
    if (!fileInfo.isWritable()) {
        qWarning() << "rotateImage: File is not writable, rotating in-memory only:" << localPath;
        if (m_imageProvider) {
            m_imageProvider->setInMemoryRotation(localPath, normalizedAngle);
        }
        emit imageRotated(localPath);
        return 1; // Read-only success
    }

    // Read the current orientation using easyexif
    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "rotateImage: Cannot open file for reading orientation:" << localPath;
        return -1;
    }
    QByteArray buffer = file.readAll();
    file.close();

    easyexif::EXIFInfo info;
    int currentOrientation = 1;
    if (info.parseFrom((unsigned char *)buffer.data(), buffer.size()) == 0) {
        currentOrientation = info.Orientation;
    }
    if (currentOrientation < 1 || currentOrientation > 8) {
        currentOrientation = 1;
    }

    // Compute the new orientation
    int steps = (normalizedAngle / 90) % 4;
    static const int cw_rot[8] = { 6, 7, 8, 5, 2, 3, 4, 1 };
    int newOrientation = currentOrientation;
    for (int i = 0; i < steps; ++i) {
        newOrientation = cw_rot[newOrientation - 1];
    }

    // Write the new orientation to the file
    if (!writeExifOrientation(localPath, newOrientation)) {
        // JPEG may have no EXIF block (e.g. freshly created or exported without metadata).
        // Fall back to an in-memory rotation so the image appears correct for this session.
        qWarning() << "rotateImage: No writable EXIF orientation tag found, using in-memory fallback:" << localPath;
        if (m_imageProvider) {
            m_imageProvider->setInMemoryRotation(localPath, normalizedAngle);
        }
        emit imageRotated(localPath);
        return 1; // In-memory-only success
    }

    // Clear any temporary in-memory rotation if the file is now successfully rotated on disk
    if (m_imageProvider) {
        m_imageProvider->clearInMemoryRotation(localPath);
    }

    emit imageRotated(localPath);
    return 0; // Success
}

bool FileActionService::writeExifOrientation(const QString &filePath, int newOrientation)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadWrite)) {
        qWarning() << "writeExifOrientation: Cannot open file for writing:" << filePath;
        return false;
    }

    QByteArray data = file.read(65536); // Read first 64KB (APP1 EXIF is always at the start)
    if (data.size() < 4) return false;

    // Check SOI marker
    if (static_cast<unsigned char>(data[0]) != 0xFF || static_cast<unsigned char>(data[1]) != 0xD8) {
        return false;
    }

    int pos = 2;
    while (pos + 4 <= data.size()) {
        unsigned char marker1 = data[pos];
        unsigned char marker2 = data[pos + 1];
        if (marker1 != 0xFF) {
            break; // Invalid JPEG structure
        }
        if (marker2 == 0xD9 || marker2 == 0xDA) {
            break; // End of header / Start of Scan
        }
        
        int length = (static_cast<int>(data[pos + 2]) << 8) | static_cast<int>(data[pos + 3]);
        
        // APP1 marker is 0xE1
        if (marker2 == 0xE1) {
            // Check Exif header: "Exif\x00\x00"
            int exifHeaderPos = pos + 4;
            if (exifHeaderPos + 6 <= data.size() && 
                data.mid(exifHeaderPos, 6) == QByteArray("Exif\0\0", 6)) {
                
                int tiffStart = exifHeaderPos + 6;
                if (tiffStart + 8 <= data.size()) {
                    QByteArray byteOrder = data.mid(tiffStart, 2);
                    bool littleEndian = false;
                    if (byteOrder == "II") {
                        littleEndian = true;
                    } else if (byteOrder == "MM") {
                        littleEndian = false;
                    } else {
                        break; // Invalid TIFF byte order
                    }
                    
                    // Read offset to 0th IFD
                    int ifdOffset = 0;
                    if (littleEndian) {
                        ifdOffset = static_cast<unsigned char>(data[tiffStart + 4]) |
                                    (static_cast<unsigned char>(data[tiffStart + 5]) << 8) |
                                    (static_cast<unsigned char>(data[tiffStart + 6]) << 16) |
                                    (static_cast<unsigned char>(data[tiffStart + 7]) << 24);
                    } else {
                        ifdOffset = (static_cast<unsigned char>(data[tiffStart + 4]) << 24) |
                                    (static_cast<unsigned char>(data[tiffStart + 5]) << 16) |
                                    (static_cast<unsigned char>(data[tiffStart + 6]) << 8) |
                                    static_cast<unsigned char>(data[tiffStart + 7]);
                    }
                    
                    int ifdPos = tiffStart + ifdOffset;
                    if (ifdPos + 2 <= data.size()) {
                        int numFields = 0;
                        if (littleEndian) {
                            numFields = static_cast<unsigned char>(data[ifdPos]) |
                                        (static_cast<unsigned char>(data[ifdPos + 1]) << 8);
                        } else {
                            numFields = (static_cast<unsigned char>(data[ifdPos]) << 8) |
                                        static_cast<unsigned char>(data[ifdPos + 1]);
                        }
                        
                        int entryPos = ifdPos + 2;
                        for (int i = 0; i < numFields; ++i) {
                            if (entryPos + 12 > data.size()) break;
                            
                            int tag = 0;
                            if (littleEndian) {
                                tag = static_cast<unsigned char>(data[entryPos]) |
                                      (static_cast<unsigned char>(data[entryPos + 1]) << 8);
                            } else {
                                tag = (static_cast<unsigned char>(data[entryPos]) << 8) |
                                      static_cast<unsigned char>(data[entryPos + 1]);
                            }
                            
                            if (tag == 0x0112) { // Orientation Tag
                                // Overwrite the orientation value (bytes 8 and 9 of the 12-byte field)
                                int valPos = entryPos + 8;
                                file.seek(valPos);
                                char valBytes[2];
                                if (littleEndian) {
                                    valBytes[0] = static_cast<char>(newOrientation & 0xFF);
                                    valBytes[1] = static_cast<char>((newOrientation >> 8) & 0xFF);
                                } else {
                                    valBytes[0] = static_cast<char>((newOrientation >> 8) & 0xFF);
                                    valBytes[1] = static_cast<char>(newOrientation & 0xFF);
                                }
                                file.write(valBytes, 2);
                                file.close();
                                return true;
                            }
                            entryPos += 12;
                        }
                    }
                }
            }
        }
        
        pos += 2 + length;
    }
    file.close();
    return false;
}

void FileActionService::copyToClipboard(const QString &filePath)
{
    QString localPath = filePath;
    if (filePath.startsWith("file://")) {
        localPath = QUrl(filePath).toLocalFile();
    }
    
    QFileInfo fileInfo(localPath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        qWarning() << "copyToClipboard: File does not exist:" << localPath;
        return;
    }

    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        qWarning() << "copyToClipboard: Clipboard not available";
        return;
    }

    QMimeData *mimeData = new QMimeData();

    // 1. Add file path URL
    QList<QUrl> urls;
    urls.append(QUrl::fromLocalFile(localPath));
    mimeData->setUrls(urls);

    // 2. Add text path
    mimeData->setText(localPath);

    // 3. Add image data (QImage)
    QImage image(localPath);
    if (!image.isNull()) {
        mimeData->setImageData(image);
    } else {
        qWarning() << "copyToClipboard: Failed to load image from" << localPath;
    }

    clipboard->setMimeData(mimeData);
}

void FileActionService::copyToClipboardBatch(const QStringList &filePaths)
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        qWarning() << "copyToClipboardBatch: Clipboard not available";
        return;
    }

    QMimeData *mimeData = new QMimeData();
    QList<QUrl> urls;
    QStringList localPaths;

    for (const QString &filePath : filePaths) {
        QString localPath = filePath;
        if (filePath.startsWith("file://")) {
            localPath = QUrl(filePath).toLocalFile();
        }
        
        QFileInfo fileInfo(localPath);
        if (fileInfo.exists() && fileInfo.isFile()) {
            urls.append(QUrl::fromLocalFile(localPath));
            localPaths.append(localPath);
        }
    }

    if (urls.isEmpty()) {
        delete mimeData;
        return;
    }

    // 1. Add file path URLs
    mimeData->setUrls(urls);

    // 2. Add text paths
    mimeData->setText(localPaths.join("\n"));

    // 3. Single image fallback
    if (urls.size() == 1) {
        QImage image(localPaths.first());
        if (!image.isNull()) {
            mimeData->setImageData(image);
        }
    }

    clipboard->setMimeData(mimeData);
}

int FileActionService::rotateImagesBatch(const QStringList &filePaths, int angle)
{
    int errors = 0;
    for (const QString &path : filePaths) {
        int result = rotateImage(path, angle);
        if (result == -1) {
            errors++;
        }
    }
    return errors;
}

bool FileActionService::moveFilesToTrashBatch(const QStringList &filePaths)
{
    bool allSuccess = true;
    for (const QString &filePath : filePaths) {
        QString localPath = filePath;
        if (filePath.startsWith("file://")) {
            localPath = QUrl(filePath).toLocalFile();
        }
        if (!QFile::moveToTrash(localPath)) {
            allSuccess = false;
        }
    }
    return allSuccess;
}


