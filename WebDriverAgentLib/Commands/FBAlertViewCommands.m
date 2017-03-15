/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBAlertViewCommands.h"

#import "FBAlert.h"
#import "FBApplication.h"
#import "FBRouteRequest.h"
#import "FBSession.h"

@implementation FBAlertViewCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/alert/text"] respondWithTarget:self action:@selector(handleAlertTextCommand:)],
    [[FBRoute POST:@"/alert/accept"] respondWithTarget:self action:@selector(handleAlertAcceptCommand:)],
    [[FBRoute POST:@"/alert/dismiss"] respondWithTarget:self action:@selector(handleAlertDismissCommand:)],
    [[FBRoute GET:@"/wda/alert/buttons"] respondWithTarget:self action:@selector(handleGetAlertButtonsCommand:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleAlertTextCommand:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  NSString *alertText = [FBAlert alertWithApplication:session.application].text;
  if (!alertText) {
    return FBResponseWithStatus(FBCommandStatusNoAlertPresent, nil);
  }
  return FBResponseWithStatus(FBCommandStatusNoError, alertText);
}

+ (id<FBResponsePayload>)handleAlertAcceptCommand:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  NSString *name = request.parameters[@"name"];

  if ([name length] != 0) {
    if (![[FBAlert alertWithApplication:session.application] clickAlertButton:name error:nil]) {
      return FBResponseWithStatus(FBCommandStatusNoAlertPresent, nil);
    }
  } else if (![[FBAlert alertWithApplication:session.application] acceptWithError:nil]) {
    return FBResponseWithStatus(FBCommandStatusNoAlertPresent, nil);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleAlertDismissCommand:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  NSString *name = request.parameters[@"name"];

  if ([name length] != 0) {
    if (![[FBAlert alertWithApplication:session.application] clickAlertButton:name error:nil]) {
      return FBResponseWithStatus(FBCommandStatusNoAlertPresent, nil);
    }
  } else if (![[FBAlert alertWithApplication:session.application] dismissWithError:nil]) {
    return FBResponseWithStatus(FBCommandStatusNoAlertPresent, nil);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetAlertButtonsCommand:(FBRouteRequest *)request {
  FBSession *session = request.session;
  FBAlert *alert = [FBAlert alertWithApplication:session.application];
  NSArray *labels = alert.labels;
  
  if (!labels) {
    return FBResponseWithStatus(FBCommandStatusNoAlertPresent, nil);
  }
  return FBResponseWithStatus(FBCommandStatusNoError, labels);
}
@end
