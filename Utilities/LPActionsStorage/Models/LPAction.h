//
//  LPAction.h
//  Tele2 Music
//
//  Created by Игорь Савельев on 31/05/2017.
//  Copyright © 2017 Warefly. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(unsigned int, LPActionState) {
	LPActionStateCreated		= 0,
	LPActionStateCancelled		= 1,
	LPActionStateSent			= 2,
	LPActionStatePending		= 3
};

@interface LPAction : NSObject

@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDate *dateCreated;
@property (nonatomic, strong) NSDate *dateSent;
@property (nonatomic) LPActionState state;

@property (nonatomic, strong) NSMutableDictionary<NSString *, id<NSCoding>> *additionalData;

- (void)setAdditionalDataObject:(id<NSCoding>)object forKey:(NSString *)key;

+ (instancetype)createNewWithCategory:(NSString *)category name:(NSString *)name additionalData:(NSDictionary<NSString *, id<NSCoding>> *)additionalData;

@end
