
#import "XCUIElement+CBXCoordinateGestures.h"
#import "FBMathUtils.h"
#import "XCUIElement+FBUtilities.h"
#import "XCElementSnapshot-Hitpoint.h"
#import "XCEventGenerator.h"
#import "XCSynthesizedEventRecord.h"
#import "FBLogger.h"

// Determined by the width of a two-finger touch.
static float const CBX_FINGER_WIDTH = 78.0f /* Adding some buffer */ + 2.0f;
static float const CBX_HALF_FINGER = CBX_FINGER_WIDTH / 2.0f;

@implementation XCUIElement (CBXCoordinateGestures)

- (BOOL)cbx_tapAtCoordinate:(CGPoint)point withError:(NSError **)error {
    return [self tapAtCoordinate:point withError:error];
}

- (BOOL)cbx_twoFingerTapAtCoordinate:(CGPoint)point withError:(NSError * _Nullable __autoreleasing *)error {
    return [self generateEvent:^(XCEventGenerator *eventGenerator, XCEventGeneratorHandler handlerBlock) {
        CGPoint hitPoint = FBInvertPointForApplication(point, self.application.frame.size, self.application.interfaceOrientation);
        
        /*
         The theory is that we should provide a rect just large enough to fit two fingers but
         centered around the desired point.
         */
        CGRect twoFingerTapRect = CGRectMake(hitPoint.x - CBX_HALF_FINGER,
                                             hitPoint.y - CBX_HALF_FINGER,
                                             CBX_FINGER_WIDTH,
                                             CBX_FINGER_WIDTH);
        
        SEL tapper = @selector(twoFingerTapInRect:orientation:handler:);
        if ([eventGenerator respondsToSelector:tapper]) {
            [eventGenerator twoFingerTapInRect:twoFingerTapRect
                                   orientation:self.interfaceOrientation
                                       handler:handlerBlock];
        } else {
            //If we're here, we need to pick two points to touch.
            //TODO: something more intelligent.
            CGPoint one, two;
            one = CGPointMake(point.x - CBX_HALF_FINGER, point.y);
            two = CGPointMake(point.x + CBX_HALF_FINGER, point.y);
            NSValue *p1 = [NSValue valueWithCGPoint:one],
                    *p2 = [NSValue valueWithCGPoint:two];
            [FBLogger logFmt:@"'%@' unavailable, manually tapping %@ and %@",
                             NSStringFromSelector(tapper),
                             p1,
                             p2];
            [eventGenerator tapAtTouchLocations:@[p1, p2]
                                   numberOfTaps:1
                                    orientation:self.interfaceOrientation
                                        handler:handlerBlock];
        }
    } error:error];
}

- (BOOL)cbx_pinchAtCoordinate:(CGPoint)point
                        scale:(double)scale
                     velocity:(double)velocity
                    withError:(NSError * _Nullable __autoreleasing *)error {
    return [self generateEvent:^(XCEventGenerator *eventGenerator, XCEventGeneratorHandler handlerBlock) {
        CGPoint hitPoint = FBInvertPointForApplication(point, self.application.frame.size, self.application.interfaceOrientation);
        /*
            TODO: The theory here is that we want a localized rect around the desired point.
            The question is... how big should the rect be?
            Current working theory: should fit at least two fingers
         */
        CGRect twoFingerTapRect = CGRectMake(hitPoint.x - CBX_HALF_FINGER,
                                             hitPoint.y - CBX_HALF_FINGER,
                                             CBX_FINGER_WIDTH,
                                             CBX_FINGER_WIDTH);
        
        SEL pincher = @selector(pinchInRect:withScale:velocity:orientation:handler:);
        if ([eventGenerator respondsToSelector:pincher]) {
            [eventGenerator pinchInRect:twoFingerTapRect
                              withScale:scale
                               velocity:velocity
                            orientation:self.interfaceOrientation
                                handler:handlerBlock];
        } else {
            [FBLogger logFmt:@"Error: Unable to synthesize event, XCEventGenerator does not respond to %@", NSStringFromSelector(pincher)];
        }
    } error:error];
}

@end
