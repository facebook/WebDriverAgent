/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBDebugCommands.h"

#import <UIKit/UIKit.h>

#import "FBRequest.h"
#import "UIAApplication.h"
#import "UIAElement.h"
#import "UIATarget.h"
#import "UIAXElement.h"

static NSDictionary *InfoForElement(UIAElement *element, BOOL verbose);

@implementation FBDebugCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return @[
    [[FBRoute GET:@"/tree"].sessionNotRequired respond: ^ id<FBResponse> (FBRequest *request) {
      return [self handleTreeCommandWithParams:request];
    }],
    [[FBRoute GET:@"/source"] respond: ^ id<FBResponse> (FBRequest *request) {
      return [self handleTreeCommandWithParams:request];
    }],
  ];
}

#pragma mark - Helpers

+ (id<FBResponse>)handleTreeCommandWithParams:(FBRequest *)params
{
  BOOL verbose = [params.parameters[@"verbose"] boolValue];
  NSDictionary *info = [self.class JSONTreeForTargetWithVerbose:verbose];
  return [FBResponse okWith:@{ @"tree": info }];
}

+ (NSDictionary *)JSONTreeForTargetWithVerbose:(BOOL)verbose
{
  [UIAElement pushPatience:0];
  NSDictionary *info = InfoForElement([[UIATarget localTarget] frontMostApp], verbose);
  [UIAElement popPatience];

  return info;
}

@end

static id ValueOrNull(id value) {
  return value ?: [NSNull null];
}

static NSDictionary *DictionaryFromCGRect(CGRect rect) {
  return @{
    @"x": @(CGRectGetMinX(rect)),
    @"y": @(CGRectGetMinY(rect)),
    @"width": @(CGRectGetWidth(rect)),
    @"height": @(CGRectGetHeight(rect)),
  };
}

static NSDictionary *InfoForElement(UIAElement *element, BOOL verbose)
{
  NSMutableDictionary *info = [[NSMutableDictionary alloc] init];

  info[@"type"] = NSStringFromClass([element class]);
  info[@"name"] = ValueOrNull([element name]);
  info[@"value"] = ValueOrNull([element value]);
  info[@"label"] = ValueOrNull([element label]);

  if ([element isEnabled]) {
    info[@"isEnabled"] = [[element isEnabled] stringValue];
  }
  if ([element isVisible]) {
    info[@"isVisible"] = [[element isVisible] stringValue];
  }
  if ([element attributes]) {
    NSDictionary *attributes = [element attributes];
    info[@"attributes"] = [NSDictionary dictionaryWithObjects:[[attributes allValues] valueForKey:@"description"] forKeys:[attributes allKeys]];
  }

  if (verbose) {
    if ([element uiaxElement]) {
      info[@"uiaxAttributes"] = [[[element uiaxElement] valuesForAllKnownAttributes] description];
    }
  }

  NSArray *childElements = [element elements];
  if ([childElements count]) {
    info[@"children"] = [[NSMutableArray alloc] init];
    for (UIAElement *childElement in childElements) {
      [info[@"children"] addObject:InfoForElement(childElement, verbose)];
    }
  }
  info[@"rect"] = DictionaryFromCGRect([[element rect] CGRectValue]);

  return info;
}
