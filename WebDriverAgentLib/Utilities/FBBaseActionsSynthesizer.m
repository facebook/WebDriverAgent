/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBBaseActionsSynthesizer.h"

#import "FBErrorBuilder.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "XCElementSnapshot.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCElementSnapshot+FBHitPoint.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "XCUIElement+FBUtilities.h"


@implementation FBBaseGestureItem

+ (NSString *)actionName
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override this method in subclasses"] build];
  return nil;
}

- (BOOL)addToEventPath:(XCPointerEventPath*)eventPath index:(NSUInteger)index error:(NSError **)error
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override this method in subclasses"] build];
  return NO;
}

- (BOOL)increaseDuration:(double)value
{
  self.duration += value;
  return YES;
}

- (CGPoint)hitpointWithElement:(nullable XCUIElement *)element positionOffset:(nullable NSValue *)positionOffset
{
  CGPoint hitPoint;
  if (nil == element) {
    // Only absolute offset is defined
    hitPoint = [positionOffset CGPointValue];
  } else {
    if (nil == positionOffset) {
      // Only element to tap is defined
      // Calculating the default hitpoint
      XCElementSnapshot *snapshot = element.fb_lastSnapshot;
      hitPoint = snapshot.fb_hitPoint;
      if (CGPointEqualToPoint(hitPoint, CGPointMake(-1, -1))) {
        hitPoint = [snapshot.suggestedHitpoints.lastObject CGPointValue];
      }
      return hitPoint;
    } else {
      // Relative element offset is defined
      CGPoint offsetValue = [positionOffset CGPointValue];
      hitPoint = CGPointMake(element.frame.origin.x + offsetValue.x, element.frame.origin.y + offsetValue.y);
    }
  }
  if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0")) {
    /*
     Since iOS 10.0 XCTest has a bug when it always returns portrait coordinates for UI elements
     even if the device is not in portait mode. That is why we need to recalculate them manually
     based on the current orientation value
     */
    hitPoint = FBInvertPointForApplication(hitPoint, self.application.frame.size, self.application.interfaceOrientation);
  }
  return hitPoint;
}

@end


@implementation FBBaseGestureItemsChain

- (instancetype)init
{
  self = [super init];
  if (self) {
    _items = [NSMutableArray array];
    _durationOffset = 0.0;
  }
  return self;
}

- (void)addItem:(FBBaseGestureItem *)item __attribute__((noreturn))
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override this method in subclasses"] build];
}

- (nullable XCPointerEventPath *)asEventPathWithError:(NSError **)error
{
  if (0 == self.items.count) {
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:@"Action items list cannot be empty"] build];
    }
    return nil;
  }
  
  XCPointerEventPath *result = [[XCPointerEventPath alloc] initForTouchAtPoint:self.items.firstObject.atPosition offset:0.0];
  NSUInteger index = 0;
  for (FBBaseGestureItem *item in self.items.copy) {
    if (![item addToEventPath:result index:index++ error:error]) {
      return nil;
    }
  }
  return result;
}

@end


@implementation FBBaseActionsSynthesizer

- (instancetype)initWithActions:(NSArray *)actions forApplication:(XCUIApplication *)application elementCache:(nullable FBElementCache *)elementCache error:(NSError **)error
{
  self = [super init];
  if (self) {
    if ((nil == actions || 0 == actions.count) && error) {
      *error = [[FBErrorBuilder.builder withDescription:@"Actions list cannot be empty"] build];
      return nil;
    }
    _actions = actions;
    _application = application;
    _elementCache = elementCache;
  }
  return self;
}

- (nullable XCSynthesizedEventRecord *)synthesizeWithError:(NSError **)error
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override synthesizeWithError method in subclasses"] build];
  return nil;
}

@end
