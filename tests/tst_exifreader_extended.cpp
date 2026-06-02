// tests/tst_exifreader_extended.cpp

#include <QtTest>
#include <QFile>
#include "ExifReader.h"

class TestExifReaderExtended : public QObject {
    Q_OBJECT
private slots:
    void testCorruptedExif();
    void testUnsupportedFormat();
};

void TestExifReaderExtended::testCorruptedExif()
{
    // This image contains known bad EXIF characters (added to test data folder)
    QString path = QStringLiteral("data/DJI_0877.JPG");
    QFile f(path);
    QVERIFY2(f.exists(), qPrintable(QString("Missing test image: %1").arg(path)));

    ExifReader reader;
    QVariantMap data = reader.getExifData(path);
    QVERIFY2(!data.isEmpty(), "EXIF data should be extracted");
    // Ensure no unprintable characters in any string value
    for (auto it = data.constBegin(); it != data.constEnd(); ++it) {
        if (it.value().typeId() == QMetaType::QString) {
            QString val = it.value().toString();
            for (const QChar &c : val) {
                QVERIFY2(c.isPrint(), qPrintable(QString("Unprintable char in key %1").arg(it.key())));
            }
        }
    }
}

void TestExifReaderExtended::testUnsupportedFormat()
{
    // Create a temporary PNG file (no EXIF support)
    QTemporaryFile tmpFile;
    tmpFile.setFileTemplate(QDir::tempPath() + "/xxxxxx.png");
    QVERIFY(tmpFile.open());
    // Write a minimal PNG header
    QByteArray pngHeader = QByteArray::fromHex("89504E470D0A1A0A");
    tmpFile.write(pngHeader);
    tmpFile.close();

    ExifReader reader;
    QVariantMap data = reader.getExifData(tmpFile.fileName());
    // Should still return basic info like FileSize, but not EXIF data
    QCOMPARE(data["FileSize"].toString(), "8 B");
    QVERIFY(!data.contains("Dimensions"));
    QVERIFY(!data.contains("Make"));
}

QTEST_MAIN(TestExifReaderExtended)
#include "tst_exifreader_extended.moc"
