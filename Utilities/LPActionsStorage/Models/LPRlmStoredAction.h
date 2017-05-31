//
//  LPRlmStorageAction.h
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import <Realm/Realm.h>

@interface LPRlmStoredAction : RLMObject

@property NSString *uid;
@property NSString *category;
@property NSString *name;
@property NSDate *dateCreated;
@property NSDate *dateSent;
@property int state;
@property NSData *additionalData;

@end

RLM_ARRAY_TYPE(WFRlmStoredAction)
