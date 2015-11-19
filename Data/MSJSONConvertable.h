//
//  MSJSONConvertable.h
//  Music Sense
//
//  Created by Игорь Савельев on 01/10/15.
//  Copyright © 2015 10tracks. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MSJSONConvertable <NSObject>

- (id)initWithJSON:(NSDictionary *)json;
- (void)updateWithJSON:(NSDictionary *)json;

+ (NSArray *)createObjectsFromJSON:(NSArray *)jsonObjects;

@end
