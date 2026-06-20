#pragma once

#include <QImage>
#include <QString>

class VideoFrameExtractor
{
public:
    static QImage extractFrame(const QString &filePath);
};
