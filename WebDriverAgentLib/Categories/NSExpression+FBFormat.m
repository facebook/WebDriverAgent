/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "NSExpression+FBFormat.h"
#import "FBElementUtils.h"

@implementation NSExpression (FBFormat)

+ (instancetype)fb_wdExpressionWithExpression:(NSExpression *)input
{
  if ([input expressionType] != NSKeyPathExpressionType) {
    return input;
  }
  NSString *actualPropName = [input keyPath];
  NSUInteger dotPos = [actualPropName rangeOfString:@"."].location;
  if (NSNotFound != dotPos) {
    actualPropName = [actualPropName substringToIndex:dotPos];
    NSString *suffix = [actualPropName substringFromIndex:dotPos];
    return [NSExpression expressionForKeyPath:[NSString stringWithFormat:@"%@.%@", [FBElementUtils wdAttributeNameForAttributeName:actualPropName], suffix]];
  }
  return [NSExpression expressionForKeyPath:[FBElementUtils wdAttributeNameForAttributeName:actualPropName]];
}

@end
