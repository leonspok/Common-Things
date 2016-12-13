//
//  NSAttributedString+Sizing.m
//  Leonspok
//
//  Created by Игорь Савельев on 29/11/2016.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import "NSAttributedString+Sizing.h"

@implementation NSAttributedString (Sizing)

- (CGSize)sizeConstraintedTo:(CGSize)constraintSize {
	NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:constraintSize];
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
	[layoutManager addTextContainer:textContainer];
	NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
	[textStorage addLayoutManager:layoutManager];
	CGRect outputRect = [layoutManager usedRectForTextContainer:textContainer];
	outputRect = CGRectIntegral(outputRect);
	return outputRect.size;
}

@end
