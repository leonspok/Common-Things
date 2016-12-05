//
//  LPAudioPlayerItem.h
//  Leonspok
//
//  Created by Игорь Савельев on 05/12/2016.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LPAudioPlayerItem : NSObject

@property (nonatomic, strong, nonnull) NSString *uid;
@property (nonatomic, strong, nullable) NSString *title;
@property (nonatomic, strong, nullable) NSString *artistTitle;
@property (nonatomic, strong, nullable) NSString *albumTitle;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, strong, nullable) NSURL *coverImageURL;
@property (nonatomic, strong, nullable) NSURL *streamingURL;

@property (nonatomic, strong, nullable) id itemObject;

@end
