#pragma once

#import <UIKit/UIKit.h>

@interface TouchControllerUtils : NSObject

+ (void)setup;
+ (BOOL)isAvailable;
+ (void)processTouchesBegan:(NSSet<UITouch *> *)touches inView:(UIView *)view;
+ (void)processTouchesMoved:(NSSet<UITouch *> *)touches inView:(UIView *)view;
+ (void)processTouchesEnded:(NSSet<UITouch *> *)touches inView:(UIView *)view;
+ (void)processTouchesCancelled:(NSSet<UITouch *> *)touches inView:(UIView *)view;

@end

