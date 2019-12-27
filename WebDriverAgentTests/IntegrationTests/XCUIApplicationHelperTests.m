/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBApplication.h"
#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "FBHomeboardApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElement+FBIsVisible.h"

@interface XCUIApplicationHelperTests : FBIntegrationTestCase
@end

@implementation XCUIApplicationHelperTests

- (void)setUp
{
  [super setUp];
  [self launchApplication];
}

- (void)testQueringSpringboard
{
  [self goToSpringBoardFirstPage];
  XCTAssertTrue([FBHomeboardApplication fb_homeboard].icons[@"Safari"].exists);
  XCTAssertTrue([FBHomeboardApplication fb_homeboard].icons[@"Calendar"].exists);
}

- (void)testTappingAppOnSpringboard
{
  [self goToSpringBoardFirstPage];
  NSError *error;
  XCTAssertTrue([[FBHomeboardApplication fb_homeboard] fb_openApplicationWithIdentifier:@"Safari" error:&error]);
  XCTAssertNil(error);
  FBAssertWaitTillBecomesTrue([FBApplication fb_activeApplication].buttons[@"URL"].exists);
}

- (void)testWaitingForSpringboard
{
  NSError *error;
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  XCTAssertTrue([[FBHomeboardApplication fb_homeboard] fb_waitUntilApplicationBoardIsVisible:&error]);
  XCTAssertNil(error);
  XCTAssertTrue([FBHomeboardApplication fb_homeboard].icons[@"Safari"].fb_isVisible);
}

- (void)testApplicationTree
{
  [self.testedApplication query];
  [self.testedApplication resolve];
  XCTAssertNotNil(self.testedApplication.fb_tree);
  XCTAssertNotNil(self.testedApplication.fb_accessibilityTree);
}

- (void)testDeactivateApplication
{
  [self.testedApplication query];
  [self.testedApplication resolve];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_deactivateWithDuration:1 error:&error]);
  XCTAssertNil(error);
  XCTAssertTrue(self.testedApplication.buttons[@"Alerts"].exists);
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Alerts"].fb_isVisible);
}

- (void)testActiveApplication
{
  XCTAssertTrue([FBApplication fb_activeApplication].buttons[@"Alerts"].fb_isVisible);
  [self goToSpringBoardFirstPage];
  XCTAssertTrue([FBApplication fb_activeApplication].icons[@"Safari"].fb_isVisible);
}

@end
