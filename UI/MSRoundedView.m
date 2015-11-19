//
//  MSRoundedView.m
//  Music Sense
//
//  Created by Игорь Савельев on 18/09/15.
//  Copyright © 2015 10tracks. All rights reserved.
//

#import "MSRoundedView.h"

@implementation MSRoundedView

- (void)layoutSubviews {
    [super layoutSubviews];
    [self.layer setMasksToBounds:YES];
    [self.layer setCornerRadius:MIN(self.frame.size.height, self.frame.size.width)/2];
}

@end
