/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIElement+FBScrolling.h"

#import "FBRunLoopSpinner.h"
#import "FBWDALogger.h"
#import "XCElementSnapshot+Helpers.h"
#import "XCElementSnapshot-Hitpoint.h"
#import "XCElementSnapshot.h"
#import "XCEventGenerator.h"
#import "XCTestDriver.h"
#import "XCTouchGesture.h"
#import "XCTouchPath.h"
#import "XCUIApplication.h"
#import "XCUICoordinate.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement.h"

#define FBPointFuzzyEqualToPoint(point1, point2, threshold) ((fabs(point1.x - point2.x) < threshold) && (fabs(point1.y - point2.y) < threshold))

const CGFloat FBFuzzyPointThreshold = 20.f; //Smallest determined value that is not interpreted as touch
const CGFloat FBFullscreenNormalizedDistance = 1.0f;
const CGFloat FBScrollToVisibleNormalizedDistance = .5f;
const CGFloat FBScrollVelocity = 200.f;
const CGFloat FBScrollBoundingVelocityPadding = 0.0f;
const CGFloat FBScrollTouchProportion = 0.75f;
const CGFloat FBScrollCoolOffTime = 1.f;

void FBHandleScrollingErrorWithDescription(NSError **error, NSString *description);

@interface XCElementSnapshot (FBScrolling)

- (void)scrollUpByNormalizedDistance:(CGFloat)distance;
- (void)scrollDownByNormalizedDistance:(CGFloat)distance;
- (void)scrollLeftByNormalizedDistance:(CGFloat)distance;
- (void)scrollRightByNormalizedDistance:(CGFloat)distance;
- (BOOL)scrollByNormalizedVector:(CGVector)normalizedScrollVector;
- (BOOL)scrollByVector:(CGVector)vector error:(NSError **)error;

@end

@implementation XCUIElement (FBScrolling)

- (void)scrollUp
{
  [self.lastSnapshot scrollUpByNormalizedDistance:FBFullscreenNormalizedDistance];
}

- (void)scrollDown
{
  [self.lastSnapshot scrollDownByNormalizedDistance:FBFullscreenNormalizedDistance];
}

- (void)scrollLeft
{
  [self.lastSnapshot scrollLeftByNormalizedDistance:FBFullscreenNormalizedDistance];
}

- (void)scrollRight
{
  [self.lastSnapshot scrollRightByNormalizedDistance:FBFullscreenNormalizedDistance];
}

- (BOOL)scrollToVisibleWithError:(NSError **)error
{
  return [self scrollToVisibleWithNormalizedScrollDistance:FBScrollToVisibleNormalizedDistance error:error];
}

- (BOOL)scrollToVisibleWithNormalizedScrollDistance:(CGFloat)normalizedScrollDistance error:(NSError **)error
{
  [self resolve];
  if (self.isFBVisible) {
    return YES;
  }
  XCElementSnapshot *scrollView = [self.lastSnapshot fb_parentMatchingType:XCUIElementTypeScrollView];
  scrollView = scrollView ?: [self.lastSnapshot fb_parentMatchingType:XCUIElementTypeTable];
  scrollView = scrollView ?: [self.lastSnapshot fb_parentMatchingType:XCUIElementTypeCollectionView];

  XCElementSnapshot *targetCellSnapshot = self.parentCellSnapshot;
  NSArray<XCElementSnapshot *> *cellSnapshots = [scrollView fb_descendantsMatchingType:XCUIElementTypeCell];
  if (cellSnapshots.count == 0) {
    // In some cases XCTest will not report Cell Views. In that case grabbing descendants and trying to figure out scroll directon from them.
    cellSnapshots = scrollView._allDescendants;
  }
  NSArray<XCElementSnapshot *> *visibleCellSnapshots = [cellSnapshots filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isFBVisible == YES"]];

  if (visibleCellSnapshots.count < 2) {
    FBHandleScrollingErrorWithDescription(error, [NSString stringWithFormat:@"Failed to perform scroll with visible cell count %lu", (unsigned long)visibleCellSnapshots.count]);
    return NO;
  }
  XCElementSnapshot *lastSnapshot = visibleCellSnapshots.lastObject;
  NSUInteger targetCellIndex = [cellSnapshots indexOfObject:targetCellSnapshot];
  NSUInteger visibleCellIndex = [cellSnapshots indexOfObject:lastSnapshot];

  XCElementSnapshot *firsVisibleCell = visibleCellSnapshots.firstObject;
  XCElementSnapshot *lastVisibleCell = visibleCellSnapshots.lastObject;
  CGVector cellGrowthVector = CGVectorMake(firsVisibleCell.frame.origin.x - lastVisibleCell.frame.origin.x,
                                       firsVisibleCell.frame.origin.y - lastVisibleCell.frame.origin.y
                                       );

  const BOOL isVerticalScroll = (ABS(cellGrowthVector.dy) > ABS(cellGrowthVector.dx));

  const NSUInteger maxScrollCount = 25;
  NSUInteger scrollCount = 0;

  XCElementSnapshot *prescrollSnapshot = self.lastSnapshot;
  // Scrolling till cell is visible and got corrent value of frames
  while (![self isEquivalentElementSnapshotVisible:prescrollSnapshot] && scrollCount < maxScrollCount) {
    if (targetCellIndex < visibleCellIndex) {
      isVerticalScroll ? [scrollView scrollUpByNormalizedDistance:normalizedScrollDistance] : [scrollView scrollLeftByNormalizedDistance:normalizedScrollDistance];
    }
    else {
      isVerticalScroll ? [scrollView scrollDownByNormalizedDistance:normalizedScrollDistance] : [scrollView scrollRightByNormalizedDistance:normalizedScrollDistance];
    }
    [self resolve]; // Resolve is needed for correct visibility
    scrollCount++;
  }

  if (scrollCount >= maxScrollCount) {
    FBHandleScrollingErrorWithDescription(error, @"Failed to perform scroll with visible cell due to max scroll count reached");
    return NO;
  }

  // Cell is now visible, but it might be only partialy visible, scrolling till whole frame is visible
  targetCellSnapshot = self.parentCellSnapshot;
  CGVector scrollVector = CGVectorMake(targetCellSnapshot.visibleFrame.size.width - targetCellSnapshot.frame.size.width,
                                       targetCellSnapshot.visibleFrame.size.height - targetCellSnapshot.frame.size.height
                                       );
  if (![scrollView scrollByVector:scrollVector error:error]) {
    return NO;
  }
  return YES;
}

- (BOOL)isEquivalentElementSnapshotVisible:(XCElementSnapshot *)snapshot
{
  if (self.isFBVisible) {
    return YES;
  }
  [self.application resolve];
  for (XCElementSnapshot *elementSnapshot in self.application.lastSnapshot._allDescendants.copy) {
    // We are comparing pre-scroll snapshot so frames are irrelevant.
    if ([snapshot _framelessFuzzyMatchesElement:elementSnapshot] && elementSnapshot.isFBVisible) {
      return YES;
    }
  }
  return NO;
}

- (XCElementSnapshot *)parentCellSnapshot
{
  XCElementSnapshot *targetCellSnapshot = self.lastSnapshot;
  if (self.elementType != XCUIElementTypeCell) {
    targetCellSnapshot = [self.lastSnapshot fb_parentMatchingType:XCUIElementTypeCell];
  }
  return targetCellSnapshot;
}

@end


@implementation XCElementSnapshot (FBScrolling)

- (void)scrollUpByNormalizedDistance:(CGFloat)distance
{
  [self scrollByNormalizedVector:CGVectorMake(0.0, distance)];
}

- (void)scrollDownByNormalizedDistance:(CGFloat)distance
{
  [self scrollByNormalizedVector:CGVectorMake(0.0, -distance)];
}

- (void)scrollLeftByNormalizedDistance:(CGFloat)distance
{
  [self scrollByNormalizedVector:CGVectorMake(distance, 0.0)];
}

- (void)scrollRightByNormalizedDistance:(CGFloat)distance
{
  [self scrollByNormalizedVector:CGVectorMake(-distance, 0.0)];
}


- (BOOL)scrollByNormalizedVector:(CGVector)normalizedScrollVector
{
  CGVector scrollVector = CGVectorMake(CGRectGetWidth(self.frame) * normalizedScrollVector.dx,
                                       CGRectGetHeight(self.frame) * normalizedScrollVector.dy
                                       );
  return [self scrollByVector:scrollVector error:nil];
}

- (BOOL)scrollByVector:(CGVector)vector error:(NSError **)error
{
  CGVector scrollBoundingVector = CGVectorMake(CGRectGetWidth(self.frame) * FBScrollTouchProportion - FBScrollBoundingVelocityPadding,
                                               CGRectGetHeight(self.frame)* FBScrollTouchProportion - FBScrollBoundingVelocityPadding
                                               );
  scrollBoundingVector.dx = (CGFloat)copysign(scrollBoundingVector.dx, vector.dx);
  scrollBoundingVector.dy = (CGFloat)copysign(scrollBoundingVector.dy, vector.dy);

  NSUInteger scrollLimit = 100;
  BOOL shouldFinishScrolling = NO;
  while (!shouldFinishScrolling) {
    CGVector scrollVector = CGVectorMake(0, 0);
    scrollVector.dx = fabs(vector.dx) > fabs(scrollBoundingVector.dx) ? scrollBoundingVector.dx : vector.dx;
    scrollVector.dy = fabs(vector.dy) > fabs(scrollBoundingVector.dy) ? scrollBoundingVector.dy : vector.dy;
    vector = CGVectorMake(vector.dx - scrollVector.dx, vector.dy - scrollVector.dy);
    shouldFinishScrolling = (vector.dx == 0.0 & vector.dy == 0.0 || --scrollLimit == 0);
    if (![self scrollAncestorScrollViewByVectorWithinScrollViewFrame:scrollVector error:error]){
      return NO;
    }
  }
  return YES;
}

- (CGVector)hitPointOffsetForScrollingVector:(CGVector)scrollingVector
{
  return
    CGVectorMake(
      CGRectGetMinX(self.frame) + CGRectGetWidth(self.frame) * (scrollingVector.dx < 0.0f ? FBScrollTouchProportion : (1 - FBScrollTouchProportion)),
      CGRectGetMinY(self.frame) + CGRectGetHeight(self.frame) * (scrollingVector.dy < 0.0f ? FBScrollTouchProportion : (1 - FBScrollTouchProportion))
    );
}

- (BOOL)scrollAncestorScrollViewByVectorWithinScrollViewFrame:(CGVector)vector error:(NSError **)error
{
  CGVector hitpointOffset = [self hitPointOffsetForScrollingVector:vector];

  XCUICoordinate *appCoordinate = [[XCUICoordinate alloc] initWithElement:self.application normalizedOffset:CGVectorMake(0.0, 0.0)];
  XCUICoordinate *startCoordinate = [[XCUICoordinate alloc] initWithCoordinate:appCoordinate pointsOffset:hitpointOffset];
  XCUICoordinate *endCoordinate = [[XCUICoordinate alloc] initWithCoordinate:startCoordinate pointsOffset:vector];

  if (FBPointFuzzyEqualToPoint(startCoordinate.screenPoint, endCoordinate.screenPoint, FBFuzzyPointThreshold)) {
    return YES;
  }

  double offset = 0.3; // Waiting before scrolling helps to make it more stable
  double scrollingTime = MAX(fabs(vector.dx), fabs(vector.dy))/FBScrollVelocity;
  XCTouchPath *touchPath = [[XCTouchPath alloc] initWithTouchDown:startCoordinate.screenPoint orientation:self.application.interfaceOrientation offset:offset];
  offset += MAX(scrollingTime, 0.1); // Setting Minimum scrolling time to avoid testmanager complaining about timing
  [touchPath liftUpAtPoint:endCoordinate.screenPoint offset:offset];

  XCTouchGesture *gesture = [[XCTouchGesture alloc] initWithName:@"FBScroll"];
  [gesture addTouchPath:touchPath];

  __block BOOL didSucceed = NO;
  __block NSError *innerError;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)()){
    [[XCTestDriver sharedTestDriver].managerProxy _XCT_performTouchGesture:gesture completion:^(NSError *scrollingError) {
      innerError = scrollingError;
      didSucceed = (scrollingError == nil);
      completion();
    }];
  }];
  if (error) {
    *error = innerError;
  }
  // Tapping cells immediately after scrolling may fail due to way UIKit is handling touches.
  // We should wait till scroll view cools off, before continuing
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:FBScrollCoolOffTime]];
  return didSucceed;
}

@end

void FBHandleScrollingErrorWithDescription(NSError **error, NSString *description)
{
  if (error) {
    *error = [NSError errorWithDomain:@"com.facebook.WebDriverAgent.ScrollToVisible" code:0 userInfo:@{NSLocalizedDescriptionKey : description}];
  }
}
