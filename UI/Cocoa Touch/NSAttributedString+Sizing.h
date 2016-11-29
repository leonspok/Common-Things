//
//  NSAttributedString+Sizing.h
//  Impulsive Vibes
//
//  Created by Игорь Савельев on 29/11/2016.
//  Copyright © 2016 MusicSense. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (Sizing)

- (CGSize)sizeConstraintedTo:(CGSize)constraintSize;

@end
