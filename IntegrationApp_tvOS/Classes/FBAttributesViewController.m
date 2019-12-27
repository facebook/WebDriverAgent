/**
 * Copyright (c) 2018-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBAttributesViewController.h"

@interface FBAttributesViewController ()

@end

@implementation FBAttributesViewController

- (IBAction)didSelectButton:(UIButton *)button
{
  button.selected = !button.selected;
}

@end
