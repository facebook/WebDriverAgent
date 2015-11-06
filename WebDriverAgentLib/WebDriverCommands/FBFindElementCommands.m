/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBFindElementCommands.h"

#import "FBAlertViewCommands.h"
#import "FBElementCache.h"
#import "FBRouteRequest.h"
#import "FBUIAElement.h"
#import "FBWDAMacros.h"
#import "FBWDALogger.h"

#import "UIAApplication.h"
#import "UIACollectionView.h"
#import "UIAElement+WebDriverXML.h"
#import "UIAElement.h"
#import "UIATarget.h"

NSArray *elementsWithProperty(UIAElement *element, NSString *property, NSString *value, BOOL partialSearch);
void elementsWithPropertyHelper(UIAElement *element, NSString *property, NSString *value, BOOL partialSearch, NSMutableArray *result);
NSArray *elementsFromXpath(UIAElement *element, NSString *xpathQuery);


@implementation FBFindElementCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return @[
    [[FBRoute POST:@"/session/:sessionID/element"] respond: ^ id<FBResponsePayload> (FBRouteRequest *request) {
      UIAElement *element = [self.class elementUsing:request.arguments[@"using"] withValue:request.arguments[@"value"]];
      if (!element) {
        [FBWDALogger log:@"Did not find an element, returning an error."];
        return FBResponseDictionaryWithStatus(FBCommandStatusNoSuchElement, @"unable to find an element");
      }
      [FBWDALogger logFmt:@"Found element: %@", element];
      NSInteger elementID = [request.elementCache storeElement:[FBUIAElement elementWithUIAElement:element]];
      return FBResponseDictionaryWithStatus(FBCommandStatusNoError, @{
        @"ELEMENT": @(elementID),
        @"type": NSStringFromClass([element class]),
      });
    }],
    [[FBRoute POST:@"/session/:sessionID/elements"] respond: ^ id<FBResponsePayload> (FBRouteRequest *request) {
      NSArray *elements = [self.class elementsUsing:request.arguments[@"using"] withValue:request.arguments[@"value"]];

      [FBWDALogger logFmt:@"Found elements: %@", elements];
      NSMutableArray *elementsResponse = [[NSMutableArray alloc] init];
      for (UIAElement *element in elements) {
        NSInteger elementID = [request.elementCache storeElement:[FBUIAElement elementWithUIAElement:element]];
        [elementsResponse addObject:
         @{
           @"ELEMENT": @(elementID),
           @"type": NSStringFromClass([element class]),
           }
         ];
      }
      return FBResponseDictionaryWithStatus(FBCommandStatusNoError, elementsResponse);
    }],
    [[FBRoute GET:@"/session/:sessionID/uiaElement/:elementID/getVisibleCells"] respond: ^ id<FBResponsePayload> (FBRouteRequest *request) {
      NSInteger elementID = [request.parameters[@"elementID"] integerValue];
      FBUIAElement *collectionElement = [request.elementCache elementForIndex:elementID];
      UIACollectionView *collection = (UIACollectionView *)collectionElement.uiaElement;

      NSMutableArray *elementsResponse = [[NSMutableArray alloc] init];
      for (UIAElement *element in [collection visibleCells]) {
        NSInteger newID = [request.elementCache storeElement:[FBUIAElement elementWithUIAElement:element]];
        [elementsResponse addObject:
         @{
           @"ELEMENT": @(newID),
           @"type": NSStringFromClass([element class]),
           }
         ];
      }
      return FBResponseDictionaryWithStatus(FBCommandStatusNoError, elementsResponse);
    }],
    [[FBRoute POST:@"/session/:sessionID/element/:id/element"] respond: ^ id<FBResponsePayload> (FBRouteRequest *request) {
      FBUIAElement *element = [request.elementCache elementForIndex:[request.parameters[@"id"] integerValue]];
      UIAElement *foundElement = [self.class elementUsing:request.arguments[@"using"] withValue:request.arguments[@"value"] under:element.uiaElement];
      if (!foundElement) {
        [FBWDALogger log:@"Did not find an element, returning an error."];
        return FBResponseDictionaryWithStatus(FBCommandStatusNoSuchElement, @"unable to find an element");
      }
      NSInteger elementID = [request.elementCache storeElement:[FBUIAElement elementWithUIAElement:foundElement]];
      return FBResponseDictionaryWithStatus(FBCommandStatusNoError, @{
        @"ELEMENT": @(elementID),
        @"type": NSStringFromClass([foundElement class]),
      });
    }],
    [[FBRoute POST:@"/session/:sessionID/element/:id/elements"] respond: ^ id<FBResponsePayload> (FBRouteRequest *request) {
      FBUIAElement *element = [request.elementCache elementForIndex:[request.parameters[@"id"] integerValue]];
      NSArray *foundElements = [self.class elementsUsing:request.arguments[@"using"] withValue:request.arguments[@"value"] under:element.uiaElement];

      if (foundElements.count == 0) {
        return FBResponseDictionaryWithStatus(FBCommandStatusNoSuchElement, @"unable to find an element");
      }

      NSMutableArray *elementsResponse = [NSMutableArray array];
      for (UIAElement *iElement in foundElements) {
        NSInteger elementID = [request.elementCache storeElement:[FBUIAElement elementWithUIAElement:iElement]];
        [elementsResponse addObject:
         @{
           @"ELEMENT": @(elementID),
           @"type": NSStringFromClass([iElement class]),
           }
         ];
      }
      return FBResponseDictionaryWithStatus(FBCommandStatusNoError, elementsResponse);
    }]
  ];
}


#pragma mark - Helpers

+ (UIAElement *)elementUsing:(NSString *)usingText withValue:(NSString *)value
{
  FBWDAAssertMainThread();
  NSArray *elements = [self elementsUsing:usingText withValue:value];
  return [elements count] ? elements[0] : nil;
}

+ (NSArray *)elementsUsing:(NSString *)usingText withValue:(NSString *)value
{
  FBWDAAssertMainThread();

  UIAApplication *frontMostApp = [[UIATarget localTarget] frontMostApp];
  return [self elementsUsing:usingText withValue:value under:frontMostApp];
}

+ (UIAElement *)elementUsing:(NSString *)usingText withValue:(NSString *)value under:(UIAElement *)element
{
  FBWDAAssertMainThread();

  return [[self elementsUsing:usingText withValue:value under:element] firstObject];
}

+ (NSArray *)elementsUsing:(NSString *)usingText withValue:(NSString *)value under:(UIAElement *)element
{
  FBWDAAssertMainThread();

  NSArray *elements;
  BOOL partialSearch = [usingText isEqualToString:@"partial link text"];
  if (partialSearch || [usingText isEqualToString:@"link text"]) {
    NSArray *components = [value componentsSeparatedByString:@"="];
    elements = elementsWithProperty(element, components[0], components[1], partialSearch);
  } else if ([usingText isEqualToString:@"name"]) {
    elements = elementsWithProperty(element, @"name", value, NO);
  } else if ([usingText isEqualToString:@"class name"]) {
    elements = elementsWithProperty(element, @"className", value, NO);
  } else if ([usingText isEqualToString:@"xpath"]) {
    elements = elementsFromXpath(element, value);
  }
  return [FBAlertViewCommands filterElementsObstructedByAlertView:elements];
}

+ (UIAElement *)elementOfClassOnSimulator:(NSString *)UIAutomationClassName
{
  FBWDAAssertMainThread();
  NSArray *elements = [self elementsOfClassOnSimulator:UIAutomationClassName];
  return [elements count] ? elements[0] : nil;
}

+ (NSArray *)elementsOfClassOnSimulator:(NSString *)UIAutomationClassName
{
  FBWDAAssertMainThread();
  UIAApplication *app = [[UIATarget localTarget] frontMostApp];
  NSArray *elements = elementsWithProperty(app, @"className", UIAutomationClassName, NO);
  return elements;
}

+ (BOOL)isElement:(UIAElement *)element underElement:(UIAElement *)parentElement
{
  NSArray *elements = elementsFromXpath(parentElement, @".//*");
  return [elements containsObject:element];
}

@end


NSArray *elementsWithProperty(UIAElement *element, NSString *property, NSString *value, BOOL partialSearch)
{
  [UIAElement pushPatience:0];

  NSMutableArray *elements = [NSMutableArray array];
  elementsWithPropertyHelper(element, property, value, partialSearch, elements);

  [UIAElement popPatience];

  return elements;
}

void elementsWithPropertyHelper(UIAElement *element, NSString *property, NSString *value, BOOL partialSearch, NSMutableArray *result)
{
  if (partialSearch) {
    NSString *text = [element valueForKey:property];
    // Sometimes UIAElement's property is a NSValue boolean instead of an NSString, so let's make sure it's actually a string.
    BOOL isString = [text isKindOfClass:[NSString class]];
    if (isString && [text rangeOfString:value].location != NSNotFound) {
      [result addObject:element];
    }
  } else {
    if ([[element valueForKey:property] isEqual:value]) {
      [result addObject:element];
    }
  }

  NSArray *childElements = [element elements];
  if ([childElements count]) {
    for (UIAElement *childElement in childElements) {
      elementsWithPropertyHelper(childElement, property, value, partialSearch, result);
    }
  }
}

NSArray *elementsFromXpath(UIAElement *element, NSString *xpathQuery)
{
  return [element childrenFromXpathQuery:xpathQuery];
}
