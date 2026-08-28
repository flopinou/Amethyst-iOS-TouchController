#import "TouchControllerUtils.h"
#include <arpa/inet.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>

typedef int (*tc_ios_send_func)(const void* buf, int len);
static tc_ios_send_func tc_send = NULL;

extern int touchcontroller_ios_send(const void* buf, int len);

static NSMapTable<UITouch *, NSNumber *> *pointerIdMap = nil;
static int nextPointerId = 1;

static inline void writeInt32BE(uint8_t *buf, int offset, int32_t value) {
    uint32_t be = htonl((uint32_t)value);
    memcpy(buf + offset, &be, 4);
}

static inline void writeFloat32BE(uint8_t *buf, int offset, float value) {
    union { float f; uint32_t i; } u;
    u.f = value;
    uint32_t be = htonl(u.i);
    memcpy(buf + offset, &be, 4);
}

static void sendAddPointer(int pointerId, float x, float y) {
    uint8_t buf[16];
    writeInt32BE(buf, 0, 1);
    writeInt32BE(buf, 4, pointerId);
    writeFloat32BE(buf, 8, x);
    writeFloat32BE(buf, 12, y);
    tc_send(buf, 16);
}

static void sendRemovePointer(int pointerId) {
    uint8_t buf[8];
    writeInt32BE(buf, 0, 2);
    writeInt32BE(buf, 4, pointerId);
    tc_send(buf, 8);
}

static void sendClearPointer(void) {
    uint8_t buf[4];
    writeInt32BE(buf, 0, 3);
    tc_send(buf, 4);
}

@implementation TouchControllerUtils

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tc_send = touchcontroller_ios_send;
        if (!tc_send) {
            tc_send = (tc_ios_send_func)dlsym(RTLD_DEFAULT, "touchcontroller_ios_send");
        }

        pointerIdMap = [NSMapTable strongToStrongObjectsMapTable];
        nextPointerId = 1;
    });
}

+ (BOOL)isAvailable {
    return tc_send != NULL;
}

+ (void)processTouchesBegan:(NSSet<UITouch *> *)touches inView:(UIView *)view {
    if (!tc_send) return;

    CGFloat viewWidth = view.bounds.size.width;
    CGFloat viewHeight = view.bounds.size.height;

    if (viewWidth <= 0 || viewHeight <= 0) return;

    for (UITouch *touch in touches) {
        if (touch.type == UITouchTypeIndirectPointer) continue;

        int pointerId = nextPointerId++;
        [pointerIdMap setObject:@(pointerId) forKey:touch];

        CGPoint loc = [touch locationInView:view];
        float normX = (float)(loc.x / viewWidth);
        float normY = (float)(loc.y / viewHeight);

        sendAddPointer(pointerId, normX, normY);
    }
}

+ (void)processTouchesMoved:(NSSet<UITouch *> *)touches inView:(UIView *)view {
    if (!tc_send) return;

    CGFloat viewWidth = view.bounds.size.width;
    CGFloat viewHeight = view.bounds.size.height;

    if (viewWidth <= 0 || viewHeight <= 0) return;

    for (UITouch *touch in touches) {
        if (touch.type == UITouchTypeIndirectPointer) continue;

        NSNumber *pidNum = [pointerIdMap objectForKey:touch];
        if (!pidNum) {
            continue;
        }

        CGPoint loc = [touch locationInView:view];
        float normX = (float)(loc.x / viewWidth);
        float normY = (float)(loc.y / viewHeight);

        sendAddPointer(pidNum.intValue, normX, normY);
    }
}

+ (void)processTouchesEnded:(NSSet<UITouch *> *)touches inView:(UIView *)view {
    if (!tc_send) return;

    NSUInteger trackedEndingCount = 0;

    for (UITouch *touch in touches) {
        if ([pointerIdMap objectForKey:touch]) {
            trackedEndingCount++;
        }
    }

    BOOL allTouchesEnding =
        (trackedEndingCount >= pointerIdMap.count) &&
        (pointerIdMap.count > 0);

    if (allTouchesEnding) {
        sendClearPointer();
        [pointerIdMap removeAllObjects];
    } else {
        for (UITouch *touch in touches) {
            NSNumber *pidNum = [pointerIdMap objectForKey:touch];
            if (!pidNum) continue;

            sendRemovePointer(pidNum.intValue);
            [pointerIdMap removeObjectForKey:touch];
        }
    }
}

+ (void)processTouchesCancelled:(NSSet<UITouch *> *)touches inView:(UIView *)view {
    if (!tc_send) return;

    sendClearPointer();
    [pointerIdMap removeAllObjects];
}

@end