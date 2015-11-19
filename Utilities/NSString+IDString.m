//
//  NSString+IDString.m
//  Fair Enough
//
//  Created by Игорь Савельев on 26/04/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "NSString+IDString.h"
#import "NSString+MD5.h"

@implementation NSString (IDString)

+ (instancetype)IDStringForClass:(Class)class {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970]*1000.0f;
    NSString *string = [NSString stringWithFormat:@"%@_%f", NSStringFromClass(class), timestamp];
    return [string MD5String];
}

@end
