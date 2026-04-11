//
//  OpenCVWrapper.h
//  cAppny
//
//  Created by Máster Móviles on 10/4/26.
//

#ifndef OpenCVWrapper_h
#define OpenCVWrapper_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject

+ (UIImage *)processImage:(UIImage *)image
              withBlurSize:(int)blurSize
             lowThreshold:(double)lowThreshold
            highThreshold:(double)highThreshold
             apertureSize:(int)apertureSize;

@end

#endif /* OpenCVWrapper_h */
