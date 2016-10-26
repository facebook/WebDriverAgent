/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "XCUIElement.h"
#import "XCUIElement+FBFind.h"
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIElement+FBIsVisible.h"
#import "FBXPath.h"
#import "FBXPath-Private.h"

@interface XCUIElementFBFindTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *testedView;
@end

@implementation XCUIElementFBFindTests

- (void)setUp
{
  [super setUp];
  self.testedView = self.testedApplication.otherElements[@"MainView"];
  XCTAssertTrue(self.testedView.exists);
  [self.testedView resolve];
}

- (void)testDescendantsWithClassName
{
  NSSet<NSString *> *expectedLabels = [NSSet setWithArray:@[
    @"Alerts",
    @"Attributes",
    @"Scrolling",
    @"Deadlock app",
  ]];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingClassName:@"XCUIElementTypeButton"];
  XCTAssertEqual(matchingSnapshots.count, expectedLabels.count);
  NSArray<NSString *> *labels = [matchingSnapshots valueForKeyPath:@"@distinctUnionOfObjects.label"];
  XCTAssertEqualObjects([NSSet setWithArray:labels], expectedLabels);

  NSArray<NSNumber *> *types = [matchingSnapshots valueForKeyPath:@"@distinctUnionOfObjects.elementType"];
  XCTAssertEqual(types.count, 1, @"matchingSnapshots should contain only one type");
  XCTAssertEqualObjects(types.lastObject, @(XCUIElementTypeButton), @"matchingSnapshots should contain only one type");
}

- (void)testDescendantsWithIdentifier
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingIdentifier:@"Alerts"];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testDescendantsWithXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButton[@label='Alerts']"];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testSingleDescendantWithXPathQuery
{
  XCUIElement *matchingSnapshot = [self.testedView fb_firstDescendantMatchingXPathQuery:@"//XCUIElementTypeButton"];
  XCTAssertNotNil(matchingSnapshot);
  XCTAssertEqual(matchingSnapshot.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshot.label, @"Alerts");
}

- (void)testSingleDescendantXMLRepresentation
{
  XCUIElement *matchingSnapshot = [self.testedView fb_firstDescendantMatchingXPathQuery:@"//XCUIElementTypeButton"];

  xmlDocPtr doc;
  xmlTextWriterPtr writer = xmlNewTextWriterDoc(&doc, 0);
  NSMutableDictionary *elementStore = [NSMutableDictionary dictionary];
  int buffersize;
  xmlChar *xmlbuff;
  int rc = [FBXPath getSnapshotAsXML:(id<FBElement>)matchingSnapshot writer:writer elementStore:elementStore];
  if (0 == rc) {
    xmlDocDumpFormatMemory(doc, &xmlbuff, &buffersize, 1);
  }
  xmlFreeTextWriter(writer);
  xmlFreeDoc(doc);
  XCTAssertEqual(rc, 0);
  
  NSString *resultXml = [NSString stringWithCString:(const char*)xmlbuff encoding:NSUTF8StringEncoding];
  NSString *expectedXml = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<XCUIElementTypeButton type=\"XCUIElementTypeButton\" name=\"Alerts\" label=\"Alerts\" visible=\"true\" enabled=\"true\" x=\"137\" y=\"93\" width=\"101\" height=\"30\" private_indexPath=\"top\"/>\n";
  XCTAssertTrue([resultXml isEqualToString: expectedXml]);
}

- (void)testSingleDescendantWithXPathQueryNoMatches
{
  XCUIElement *matchingSnapshot = [self.testedView fb_firstDescendantMatchingXPathQuery:@"//XCUIElementTypeButtonnn"];
  XCTAssertNil(matchingSnapshot);
}

- (void)testSingleLastDescendantWithXPathQuery
{
  XCUIElement *matchingSnapshot = [self.testedView fb_firstDescendantMatchingXPathQuery:@"(//XCUIElementTypeButton)[last()]"];
  XCTAssertNotNil(matchingSnapshot);
  XCTAssertEqual(matchingSnapshot.elementType, XCUIElementTypeButton);
}

- (void)testDescendantsWithXPathQueryNoMatches
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButton[@label='Alerts1']"];
  XCTAssertEqual(matchingSnapshots.count, 0);
}

- (void)testDescendantsWithComplexXPathQuery
{
    NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//*[@label='Scrolling']/preceding::*[boolean(string(@label))]"];
    XCTAssertEqual(matchingSnapshots.count, 3);
}

- (void)testDescendantsWithWrongXPathQuery
{
    XCTAssertThrowsSpecificNamed([self.testedView fb_descendantsMatchingXPathQuery:@"//*[blabla(@label, Scrolling')]"], NSException,
                                 XCElementSnapshotInvalidXPathException);
}

- (void)testFirstDescendantWithWrongXPathQuery
{
  XCTAssertThrowsSpecificNamed([self.testedView fb_firstDescendantMatchingXPathQuery:@"//*[blabla(@label, Scrolling')]"], NSException,
                               XCElementSnapshotInvalidXPathException);
}

- (void)testVisibleDescendantWithXPathQuery
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingXPathQuery:@"//XCUIElementTypeButton[@name='Alerts' and @enabled='true' and @visible='true']"];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertTrue(matchingSnapshots.lastObject.isEnabled);
  XCTAssertTrue(matchingSnapshots.lastObject.fb_isVisible);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testInvisibleDescendantWithXPathQuery
{
  [self goToAttributesPage];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedApplication fb_descendantsMatchingXPathQuery:@"//XCUIElementTypePageIndicator[@visible='false']"];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypePageIndicator);
  XCTAssertFalse(matchingSnapshots.lastObject.fb_isVisible);
}

- (void)testDescendantsWithPredicateString
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label = 'Alerts'"];
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingPredicate:predicate];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testDescendantsWithPropertyStrict
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingProperty:@"label" value:@"Alert" partialSearch:NO];
  XCTAssertEqual(matchingSnapshots.count, 0);
  matchingSnapshots = [self.testedView fb_descendantsMatchingProperty:@"label" value:@"Alerts" partialSearch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

- (void)testDescendantsWithPropertyPartial
{
  NSArray<XCUIElement *> *matchingSnapshots = [self.testedView fb_descendantsMatchingProperty:@"label" value:@"Alerts" partialSearch:NO];
  XCTAssertEqual(matchingSnapshots.count, 1);
  XCTAssertEqual(matchingSnapshots.lastObject.elementType, XCUIElementTypeButton);
  XCTAssertEqualObjects(matchingSnapshots.lastObject.label, @"Alerts");
}

@end
