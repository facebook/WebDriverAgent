/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCElementSnapshot+Helpers.h"

#import "WebDriverAgentLib/FBFindElementCommands.h"

#import "FBRunLoopSpinner.h"
#import "FBWDALogger.h"
#import "FBXPathCreator.h"
#import "XCAXClient_iOS.h"
#import "XCTestDriver.h"

inline static BOOL valuesAreEqual(id value1, id value2);

extern const NSString *const XC_kAXXCAttributeIsVisible;
extern const NSString *const XC_kAXXCAttributeIsElement;
NSArray *XCAXAccessibilityAttributesForStringAttributes(NSArray *list);

NSNumber *FB_XCAXAIsVisibleAttribute;
NSNumber *FB_XCAXAIsElementAttribute;

@implementation XCElementSnapshot (Helpers)

+ (void)load
{
  NSArray<NSNumber *> *accessibilityAttributes = XCAXAccessibilityAttributesForStringAttributes(@[XC_kAXXCAttributeIsVisible, XC_kAXXCAttributeIsElement]);
  FB_XCAXAIsVisibleAttribute = accessibilityAttributes[0];
  FB_XCAXAIsElementAttribute = accessibilityAttributes[1];
}

+ (XCElementSnapshot *)fb_snapshotForAccessibilityElement:(XCAccessibilityElement *)accessibilityElement
{
  __block XCElementSnapshot *snapshot;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)()){
    [[XCTestDriver sharedTestDriver].managerProxy _XCT_snapshotForElement:accessibilityElement
                                                               attributes:[[XCAXClient_iOS sharedClient] defaultAttributes]
                                                               parameters: [[XCAXClient_iOS sharedClient] defaultParameters]
                                                                    reply:^(XCElementSnapshot *iSnapshot, NSError *error) {
                                                                      if (error) {
                                                                        [FBWDALogger logFmt:@"Error: %@", error];
                                                                      }
                                                                      snapshot = iSnapshot;
                                                                      completion();
                                                                    }];
  }];
  return snapshot;
}

- (NSArray<XCElementSnapshot *> *)fb_descendantsMatchingType:(XCUIElementType)type
{
  return [FBFindElementCommands descendantsOfElementSnapshot:self withXPathQuery:[FBXPathCreator xpathWithSubelementsOfType:type]];
}

- (XCElementSnapshot *)fb_parentMatchingType:(XCUIElementType)type
{
  XCElementSnapshot *snapshot = self.parent;
  while (snapshot && snapshot.elementType != type) {
    snapshot = snapshot.parent;
  }
  return snapshot;
}

- (id)fb_attributeValue:(NSNumber *)attribute
{
  NSDictionary *attributesResult = [[XCAXClient_iOS sharedClient] attributesForElementSnapshot:self attributeList:@[attribute]];
  return attributesResult[attribute];
}

- (XCElementSnapshot *)fb_mainWindow
{
  NSArray<XCElementSnapshot *> *mainWindows = [self descendantsByFilteringWithBlock:^BOOL(XCElementSnapshot *snapshot) {
    return snapshot.isMainWindow;
  }];
  return mainWindows.lastObject;
}

- (BOOL)fb_framelessFuzzyMatchesElement:(XCElementSnapshot *)snapshot
{
  return self.elementType == snapshot.elementType &&
    valuesAreEqual(self.identifier, snapshot.identifier) &&
    valuesAreEqual(self.title, snapshot.title) &&
    valuesAreEqual(self.label, snapshot.label) &&
    valuesAreEqual(self.value, snapshot.value) &&
    valuesAreEqual(self.placeholderValue, snapshot.placeholderValue);
}

@end

inline static BOOL valuesAreEqual(id value1, id value2)
{
  return value1 == value2 || [value1 isEqual:value2];
}
