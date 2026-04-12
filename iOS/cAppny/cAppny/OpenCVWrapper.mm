//
//  OpenCVWrapper.m
//  cAppny
//
//  Created by Máster Móviles on 10/4/26.
//

// OpenCVWrapper.mm
// The .mm extension tells the compiler this is Objective-C++,
// which allows mixing Objective-C and C++ (OpenCV) in the same file.

#ifdef __cplusplus
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/imgcodecs/ios.h>
#pragma clang diagnostic pop
#endif

#import "OpenCVWrapper.h"
#import <UIKit/UIKit.h>

@implementation OpenCVWrapper

+ (UIImage *)processImage:(UIImage *)image
              withBlurSize:(int)blurSize
             lowThreshold:(double)lowThreshold
            highThreshold:(double)highThreshold
             apertureSize:(int)apertureSize {

    cv::Mat src;
    UIImageToMat(image, src);

    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_RGBA2GRAY);

    cv::Mat blurred;
    cv::GaussianBlur(gray, blurred, cv::Size(blurSize, blurSize), 0);

    cv::Mat edges;
    cv::Canny(blurred, edges, lowThreshold, highThreshold, apertureSize);

    UIImage *result = MatToUIImage(edges);
    return result;
}

@end
