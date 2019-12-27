/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTVIntegrationTestCase.h"

#import "FBHomeboardApplication.h"
#import "FBTestMacros.h"
#import "FBConfiguration.h"
#import "FBMacros.h"
#import "FBRunLoopSpinner.h"
#import "XCUIDevice+FBRotation.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIApplication+FBFocused.h"
#import "XCUIElement+FBTVFocuse.h"
#import "XCUIElement+FBUtilities.h"

NSString *const FBShowAlertButtonName = @"Create App Alert";
NSString *const FBShowSheetAlertButtonName = @"Create Sheet Alert";
NSString *const FBShowAlertForceTouchButtonName = @"Create Alert (Force Touch)";

@interface FBTVIntegrationTestCase ()
@property (nonatomic, strong) XCUIApplication *testedApplication;
@property (nonatomic, strong, getter = homeboard) FBHomeboardApplication *homeboard;
@end

@implementation FBTVIntegrationTestCase

- (void)setUp
{
  [super setUp];
  [FBConfiguration disableRemoteQueryEvaluation];
  [FBConfiguration disableAttributeKeyPathAnalysis];
  self.continueAfterFailure = NO;
  self.testedApplication = [XCUIApplication new];
}

- (FBHomeboardApplication*) homeboard {
  return [FBHomeboardApplication fb_homeboard];
}

- (void)launchApplication
{
  [self.testedApplication launch];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Alerts"].fb_isVisible);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  
  // Force resolving XCUIApplication
  [self.testedApplication query];
  [self.testedApplication resolve];
}

- (void)goToAttributesPage
{
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonDown];
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonSelect];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"Select me"].fb_isVisible);
}

- (void)goToNavigationPage
{
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonDown];
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonDown];
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonSelect];
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[@"Select template"].fb_isVisible);
}

- (void)goToAlertsPage
{
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonSelect];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[FBShowAlertButtonName].fb_isVisible);
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[FBShowSheetAlertButtonName].fb_isVisible);
}

- (void)goToHeadBoardPage
{
  [[XCUIRemote sharedRemote] pressButton:XCUIRemoteButtonHome];
  FBAssertWaitTillBecomesTrue([FBHomeboardApplication fb_homeboard].icons[@"Settings"].exists);
}

- (void)goToScrollPageWithCells:(BOOL)showCells
{
  [self select:self.testedApplication.buttons[@"Scrolling"]];
  FBAssertWaitTillBecomesTrue(self.testedApplication.buttons[@"TableView"].fb_isVisible);
  [self select:self.testedApplication.buttons[showCells ? @"TableView": @"ScrollView"]];
  FBAssertWaitTillBecomesTrue(self.testedApplication.staticTexts[@"3"].fb_isVisible);
}

- (void)select:(XCUIElement*) element
{
  [self.testedApplication fb_waitUntilSnapshotIsStable];
  NSError *error;
  [element fb_selectWithError:&error];
  XCTAssertNil(error);
}

@end
