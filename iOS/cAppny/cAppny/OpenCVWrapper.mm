//
//  OpenCVWrapper.m
//  cAppny
//
//  Created by Máster Móviles on 10/4/26.
//

// OpenCVWrapper.mm
// The .mm extension tells the compiler this is Objective-C++,
// which allows mixing Objective-C and C++ (OpenCV) in the same file.

// The order of imports here is critical.
// opencv.hpp must come BEFORE any Apple headers in a .mm file,
// because OpenCV defines some macros that conflict with Apple's
// if Apple headers load first.

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#endif

#import "OpenCVWrapper.h"

@implementation OpenCVWrapper

+ (UIImage *)processImage:(UIImage *)image
              withBlurSize:(int)blurSize
             lowThreshold:(double)lowThreshold
            highThreshold:(double)highThreshold
             apertureSize:(int)apertureSize {
    return image;
}

@end
