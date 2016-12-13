//
//  LPRoundedView.m
//  Leonspok
//
//  Created by Игорь Савельев on 18/09/15.
//  Copyright © 2015 Leonspok. All rights reserved.
//

#import "LPRoundedView.h"

@implementation LPRoundedView

- (void)layoutSubviews {
    [super layoutSubviews];
    [self.layer setMasksToBounds:YES];
    [self.layer setCornerRadius:MIN(self.frame.size.height, self.frame.size.width)/2];
}

@end
