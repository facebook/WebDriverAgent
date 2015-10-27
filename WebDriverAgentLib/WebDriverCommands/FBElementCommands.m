/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBElementCommands.h"

#import <CoreImage/CoreImage.h>

#import "FBElementCache.h"
#import "FBRequest.h"
#import "FBWDAConstants.h"
#import "FBWDAMacros.h"
#import "UIAApplication.h"
#import "UIACollectionView.h"
#import "UIAKeyboard.h"
#import "UIAPickerWheel.h"
#import "UIATarget.h"

@interface FBElementCommands ()
@end

@implementation FBElementCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return @[
    [[FBRoute POST:@"/tap/:reference"] respond: ^ id<FBResponse> (FBRequest *request) {
      CGFloat x = [request.arguments[@"x"] floatValue];
      CGFloat y = [request.arguments[@"y"] floatValue];
      NSInteger elementID = [request.parameters[@"reference"] integerValue];
      UIAElement *element = [request.elementCache elementForIndex:elementID];
      if (element != nil) {
        CGRect rect = [[element valueForKey:@"rect"] CGRectValue];
        x += rect.origin.x;
        y += rect.origin.y;
      }
      [[UIATarget localTarget] tap:@{ @"x": @(x), @"y": @(y) }];
      return FBResponse.ok;
    }],
    [[FBRoute POST:@"/element/:id/click"] respond: ^ id<FBResponse> (FBRequest *request) {
      NSInteger elementID = [request.parameters[@"id"] integerValue];
      UIAElement *element = [request.elementCache elementForIndex:elementID];
      [element tap];
      return [FBResponse withElementID:elementID];
    }],
    [[FBRoute GET:@"/element/:id/displayed"] respond: ^ id<FBResponse> (FBRequest *request) {
      NSInteger elementID = [request.parameters[@"id"] integerValue];
      UIAElement *element = [request.elementCache elementForIndex:elementID];
      BOOL isVisible = [[element isVisible] boolValue];
      return [FBResponse okWith:isVisible ? @"1" : @"0"];
    }],
    [[FBRoute GET:@"/element/:id/enabled"] respond: ^ id<FBResponse> (FBRequest *request) {
      NSInteger elementID = [request.parameters[@"id"] integerValue];
      UIAElement *element = [request.elementCache elementForIndex:elementID];
      BOOL isEnabled = [[element isEnabled] boolValue];
      return [FBResponse okWith:isEnabled ? @"1" : @"0"];
    }],
    [[FBRoute POST:@"/element/:id/clear"] respond: ^ id<FBResponse> (FBRequest *request) {
      NSInteger elementID = [request.arguments[@"id"] integerValue];
      UIAElement *element = [request.elementCache elementForIndex:elementID];

      // TODO(t8077426): This is a terrible workaround to get tests in t8036026 passing.
      // It's possible that the client has allready called tap on the element.
      // If this is the case then -[UIElement setValue:] will still call 'tap'.
      // In thise case an exception will be thrown.
      if (FBWDAConstants.isIOS9OrGreater) {
        @try {
          [element setValue:@""];
        }
        @catch (NSException *exception) {
        }
      } else {
        [element setValue:@""];
      }

      return [FBResponse withElementID:elementID];
    }],
    [[FBRoute POST:@"/element/:id/value"] respond: ^ id<FBResponse> (FBRequest *request) {
      NSInteger elementID = [request.arguments[@"id"] integerValue];
      UIAElement *element = [request.elementCache elementForIndex:elementID];
      if (![[element hasKeyboardFocus] boolValue]) {
        [element tap];
      }
      NSString *textToType = [request.arguments[@"value"] componentsJoinedByString:@""];
      [self.class typeText:textToType];
      return [FBResponse withElementID:elementID];
    }],
    [[FBRoute POST:@"/keys"] respond: ^ id<FBResponse> (FBRequest *request) {
      NSString *textToType = [request.arguments[@"value"] componentsJoinedByString:@""];
      [self.class typeText:textToType];
      return FBResponse.ok;
    }],
    [[FBRoute POST:@"/uiaElement/:elementID/doubleTap"] respond: ^ id<FBResponse> (FBRequest *request) {
      UIAElement *element = [request.elementCache elementForIndex:[request.parameters[@"elementID"] integerValue]];
      [element doubleTap];
      return FBResponse.ok;
    }],
    [[FBRoute POST:@"/uiaElement/:id/touchAndHold"] respond: ^ id<FBResponse> (FBRequest *request) {
      UIAElement *element = [request.elementCache elementForIndex:[request.arguments[@"element"] integerValue]];
      [element touchAndHold:@([request.arguments[@"duration"] floatValue])];
      return FBResponse.ok;
    }],
    [[FBRoute POST:@"/uiaTarget/:id/dragfromtoforduration"] respond: ^ id<FBResponse> (FBRequest *request) {
      [[UIATarget localTarget] dragFrom:@{ @"x": request.arguments[@"fromX"], @"y": request.arguments[@"fromY"] } to:@{ @"x": request.arguments[@"toX"], @"y": request.arguments[@"toY"] } forDuration:request.arguments[@"duration"]];
      return FBResponse.ok;
    }],
    [[FBRoute GET:@"/element/:elementID/rect"] respond: ^ id<FBResponse> (FBRequest *request) {
      UIAElement *element = [request.elementCache elementForIndex:[request.parameters[@"elementID"] integerValue]];
      return [FBResponse okWith:[self.class attribute:@"rect" onElement:element]];
    }],
    [[FBRoute GET:@"/element/:id/attribute/:name"] respond: ^ id<FBResponse> (FBRequest *request) {
      NSInteger elementID = [request.parameters[@"id"] integerValue];
      UIAElement *element = [request.elementCache elementForIndex:elementID];
      id attributeValue = [self.class attribute:request.parameters[@"name"] onElement:element];
      attributeValue = attributeValue ?: [NSNull null];
      return [FBResponse okWith:attributeValue];
    }],
    [[FBRoute GET:@"/window/:windowHandle/size"] respond: ^ id<FBResponse> (FBRequest *request) {
      return [FBResponse okWith:[self.class attribute:@"rect" onElement:[UIATarget localTarget]][@"size"]];
    }],
    [[FBRoute POST:@"/uiaElement/:element/scroll"] respond: ^ id<FBResponse> (FBRequest *request) {
      UIAElement *element = [request.elementCache elementForIndex:[request.arguments[@"element"] integerValue]];

      // Using presence of arguments as a way to convey control flow seems like a pretty bad idea but it's
      // what ios-driver did and sadly, we must copy them.
      if (request.arguments[@"name"]) {
        [element scrollToElementWithName:request.arguments[@"name"]];
      } else if (request.arguments[@"direction"]) {
        NSString *direction = request.arguments[@"direction"];
        if ([direction isEqualToString:@"up"]) {
          [element scrollUp];
        } else if ([direction isEqualToString:@"down"]) {
          [element scrollDown];
        } else if ([direction isEqualToString:@"left"]) {
          [element scrollLeft];
        } else if ([direction isEqualToString:@"right"]) {
          [element scrollRight];
        }
      } else if (request.arguments[@"predicateString"]) {
        [element scrollToElementWithPredicate:request.arguments[@"predicateString"]];
      } else if (request.arguments[@"toVisible"]) {
        id rect;
        int counter = 0;
        // Calling scrollToVisible sometimes scrolls element in a way that it is still invisible.
        // This will try 10 times to scroll element till stable rect is reached.
        while (![[element rect] isEqual:rect]) {
          rect = [element rect];
          [element scrollToVisible];
          if (counter > 10) {
            break;
          }
          counter++;
        }
      }
      return FBResponse.ok;
    }],
    [[FBRoute POST:@"/uiaElement/:elementID/value"] respond: ^ id<FBResponse> (FBRequest *request) {
      UIAPickerWheel *element = (UIAPickerWheel *)[request.elementCache elementForIndex:[request.arguments[@"element"] integerValue]];
      [element selectValue:request.arguments[@"value"]];
      return FBResponse.ok;
    }],
  ];
}


#pragma mark - Helpers

+ (void)typeText:(NSString *)text
{
  UIAKeyboard *keyboard = [[[UIATarget localTarget] frontMostApp] keyboard];
  [keyboard setInterKeyDelay:0.25];
  [keyboard typeString:text];
}

+ (id)attribute:(NSString *)name onElement:(UIAElement *)element
{
  FBWDAAssertMainThread();

  if ([name isEqualToString:@"type"]) {
    return [element className];
  }
  [UIAElement pushPatience:0];
  id value = [element valueForKey:name];
  [UIAElement popPatience];

  if ([name isEqualToString:@"rect"]) {
    CGRect rect = [value CGRectValue];
    return @{
             @"origin": @{
                 @"x": @(rect.origin.x),
                 @"y": @(rect.origin.y),
                 },
             @"size": @{
                 @"width": @(rect.size.width),
                 @"height": @(rect.size.height),
                 },
             };
  }

  return value;
}

@end
