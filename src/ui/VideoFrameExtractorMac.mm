#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AppKit/AppKit.h>
#include "VideoFrameExtractor.h"
#include <QImage>
#include <QString>

QImage VideoFrameExtractor::extractFrame(const QString &filePath) {
    @autoreleasepool {
        NSURL *url = [NSURL fileURLWithPath:filePath.toNSString()];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        if (!asset) {
            return QImage();
        }
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        if (!generator) {
            return QImage();
        }
        generator.appliesPreferredTrackTransform = YES;
        
        // Extract frame at 1.0 second mark (to avoid black screen at start)
        CMTime time = CMTimeMakeWithSeconds(1.0, 600);
        NSError *error = nil;
        CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
        if (error || !imageRef) {
            // Fallback to 0.0 seconds if 1.0 seconds fails
            time = CMTimeMakeWithSeconds(0.0, 600);
            error = nil;
            imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
            if (error || !imageRef) {
                return QImage();
            }
        }
        
        // Convert CGImageRef to QImage using CGBitmapContext to guarantee RGBA8888 byte order
        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);
        QImage img(width, height, QImage::Format_RGBA8888);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(
            img.bits(),
            width,
            height,
            8,
            img.bytesPerLine(),
            colorSpace,
            kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big
        );
        CGColorSpaceRelease(colorSpace);
        
        if (!context) {
            CGImageRelease(imageRef);
            return QImage();
        }
        
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
        CGImageRelease(imageRef);
        
        return img;
    }
}
