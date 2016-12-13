//
//  NSAttributedString+Sizing.h
//  Leonspok
//
//  Created by Игорь Савельев on 29/11/2016.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (Sizing)

- (CGSize)sizeConstraintedTo:(CGSize)constraintSize;

@end
