/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import <WebDriverAgentLib/FBAlert.h>

#import "FBTVIntegrationTestCase.h"
#import "FBTestMacros.h"

@interface FBRAlertTests : FBTVIntegrationTestCase
@end

@implementation FBRAlertTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAlertsPage];
  });
}

- (void)tearDown
{
  [super tearDown];
  [[FBAlert alertWithApplication:self.testedApplication] dismissWithError:nil];
}

- (void)showApplicationAlert
{
  [self select: self.testedApplication.buttons[FBShowAlertButtonName]];
  XCUIElementQuery* query = self.testedApplication.alerts;
  FBAssertWaitTillBecomesTrue(query.count != 0);
}

- (void)showApplicationSheet
{
  [self select: self.testedApplication.buttons[FBShowSheetAlertButtonName]];
  FBAssertWaitTillBecomesTrue(self.testedApplication.sheets.count != 0);
}

- (void)testAlertException
{
  XCTAssertThrowsSpecificNamed([FBAlert throwRequestedItemObstructedByAlertException], NSException, FBAlertObstructingElementException);
}

- (void)testAlertPresence
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertFalse(alert.isPresent);
  [self showApplicationAlert];
  XCTAssertTrue(alert.isPresent);
}

- (void)testAlertText
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.text);
  [self showApplicationAlert];
  XCTAssertTrue([alert.text containsString:@"Magic"]);
  XCTAssertTrue([alert.text containsString:@"Should read"]);
}

- (void)testAlertLabels
{
  FBAlert* alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.buttonLabels);
  [self showApplicationAlert];
  XCTAssertNotNil(alert.buttonLabels);
  XCTAssertEqual(1, alert.buttonLabels.count);
  XCTAssertEqualObjects(@"Will do", alert.buttonLabels[0]);
}

- (void)testSelectAlertButton
{
  FBAlert* alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertFalse([alert clickAlertButton:@"Invalid" error:nil]);
  [self showApplicationAlert];
  XCTAssertFalse([alert clickAlertButton:@"Invalid" error:nil]);
  XCTAssertTrue([alert clickAlertButton:@"Will do" error:nil]);
}

- (void)testAcceptingAlert
{
  NSError *error;
  [self showApplicationAlert];
  XCTAssertTrue([[FBAlert alertWithApplication:self.testedApplication] acceptWithError:&error]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  XCTAssertNil(error);
}

- (void)testDismissingAlert
{
  NSError *error;
  [self showApplicationAlert];
  XCTAssertTrue([[FBAlert alertWithApplication:self.testedApplication] dismissWithError:&error]);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count == 0);
  XCTAssertNil(error);
}

- (void)testAlertElement
{
  [self showApplicationAlert];
  XCUIElement *alertElement = [FBAlert alertWithApplication:self.testedApplication].alertElement;
  XCTAssertTrue(alertElement.exists);
  XCTAssertTrue(alertElement.elementType == XCUIElementTypeAlert);
}

- (void)testFilteringObstructedElements
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCUIElement *showAlertButton = self.testedApplication.buttons[FBShowAlertButtonName];
  XCUIElement *acceptAlertButton = self.testedApplication.buttons[@"Will do"];
  [self showApplicationAlert];
  
  NSArray *filteredElements = [alert filterObstructedElements:@[showAlertButton, acceptAlertButton]];
  XCTAssertEqualObjects(filteredElements, @[acceptAlertButton]);
}

- (void)testCameraRollAlert
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.text);
  [self select: self.testedApplication.buttons[@"Create Photo Lib access Alert"]];
  FBAssertWaitTillBecomesTrue(alert.isPresent);
  
  XCTAssertTrue([alert.text containsString:@"Would Like to Access Your Photos"]);
}

- (void)testGPSAccessAlert
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  XCTAssertNil(alert.text);
  
  [self select: self.testedApplication.buttons[@"Create GPS access Alert"]];
  FBAssertWaitTillBecomesTrue(alert.isPresent);
  
  XCTAssertTrue([alert.text containsString:@"to access your location"]);
  XCTAssertTrue([alert.text containsString:@"Yo Yo"]);
}

- (void)testSheetAlert
{
  FBAlert *alert = [FBAlert alertWithApplication:self.testedApplication];
  BOOL isIpad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
  [self showApplicationSheet];
  XCUIElement *showSheetButton = self.testedApplication.buttons[FBShowSheetAlertButtonName];
  //On iphone this filterObstructedElements will throw an exception.
  if (isIpad) {
    NSArray *filteredElements = [alert filterObstructedElements:@[showSheetButton]];
    XCTAssertEqualObjects(filteredElements, @[showSheetButton]);
  } else {
    XCTAssertThrowsSpecificNamed([alert filterObstructedElements:@[showSheetButton]], NSException, FBAlertObstructingElementException, @"should throw FBAlertObstructingElementException");
  }
}

@end
