#include "VideoFrameExtractor.h"
#include <QProcess>
#include <QThread>
#include <QDir>
#include <QCryptographicHash>
#include <QFileInfo>
#include <QDebug>

QImage VideoFrameExtractor::extractFrame(const QString &filePath)
{
    // Item 1 Fix: append current thread ID to prevent collisions between concurrent QThreadPool threads
    QString threadIdStr = QString::number(quintptr(QThread::currentThreadId()));
    QString hash = QCryptographicHash::hash(filePath.toUtf8(), QCryptographicHash::Md5).toHex();
    QString tempFile = QString("%1/ninjaview_thumb_%2_%3.jpg")
                       .arg(QDir::tempPath())
                       .arg(hash)
                       .arg(threadIdStr);
    
    if (QFile::exists(tempFile)) {
        QFile::remove(tempFile);
    }
    
    QString escapedPath = filePath;
    escapedPath.replace("\"", "\\\"");
    QString escapedTemp = tempFile;
    escapedTemp.replace("\"", "\\\"");

    QProcess process;
    QStringList args;
    args << "filesrc" << QString("location=\"%1\"").arg(escapedPath)
         << "!" << "decodebin"
         << "!" << "videoconvert"
         << "!" << "jpegenc"
         << "!" << "filesink" << QString("location=\"%1\"").arg(escapedTemp);
         
    process.start("gst-launch-1.0", args);
    if (!process.waitForStarted(200)) {
        qWarning() << "GStreamer: Failed to start process gst-launch-1.0. Check if GStreamer is installed and in PATH.";
        return QImage();
    }
    
    bool success = false;
    for (int i = 0; i < 40; ++i) { // 2000ms max
        QThread::msleep(50);
        if (QFile::exists(tempFile) && QFileInfo(tempFile).size() > 0) {
            success = true;
            break;
        }
        if (process.state() == QProcess::NotRunning) {
            break;
        }
    }
    
    process.kill();
    process.waitForFinished(500);
    
    if (!success) {
        qDebug() << "GStreamer pipeline failed. Output:" << process.readAllStandardOutput();
        qDebug() << "GStreamer pipeline error:" << process.readAllStandardError();
    }
    
    QImage img;
    if (success && QFile::exists(tempFile)) {
        img.load(tempFile);
        QFile::remove(tempFile);
    }
    return img;
}
