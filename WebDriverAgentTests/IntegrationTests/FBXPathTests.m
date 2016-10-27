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
#import "XCElementSnapshot+FBHelpers.h"
#import "XCUIElement+FBFind.h"
#import "XCUIElement+FBIsVisible.h"
#import "FBXPath.h"
#import "FBXPath-Private.h"

@interface FBXPathTests : FBIntegrationTestCase
@property (nonatomic, strong) XCUIElement *testedView;
@end

@implementation FBXPathTests

- (void)setUp
{
  [super setUp];
  self.testedView = self.testedApplication.otherElements[@"MainView"];
  XCTAssertTrue(self.testedView.exists);
  [self.testedView resolve];
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

- (void)testFindMatchesInElement
{
  NSArray<id<FBElement>> *matchingSnapshots = [FBXPath findMatchesIn:(id<FBElement>)self.testedView xpathQuery:@"//XCUIElementTypeButton"];
  
  XCTAssertEqual([matchingSnapshots count], 4);
  for (id<FBElement> element in matchingSnapshots) {
    XCTAssertTrue([element.wdType isEqualToString:@"XCUIElementTypeButton"]);
  }
}


@end
