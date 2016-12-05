//
//  LPAudioPlayerItem.m
//  Leonspok
//
//  Created by Игорь Савельев on 05/12/2016.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import "LPAudioPlayerItem.h"

@implementation LPAudioPlayerItem

- (BOOL)isEqual:(id)object {
	if (!object) {
		return NO;
	}
	if (object == self) {
		return YES;
	}
	if ([object isKindOfClass:self.class]) {
		LPAudioPlayerItem *other = object;
		if (!self.itemObject || ![self.itemObject respondsToSelector:@selector(isEqual:)]) {
			return [self.uid isEqual:other.uid];
		} else {
			return [self.itemObject isEqual:other.itemObject];
		}
	}
	return NO;
}

- (NSUInteger)hash {
	if (!self.itemObject || ![self.itemObject respondsToSelector:@selector(hash)]) {
		return [self.uid hash];
	}
	return [self.itemObject hash];
}

@end
