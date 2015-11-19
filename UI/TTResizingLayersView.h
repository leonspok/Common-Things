//
//  TTResizingLayersView.h
//  Билайн.Волна
//
//  Created by Игорь Савельев on 23/06/15.
//  Copyright (c) 2015 10tracks. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TTResizingLayersView : UIView

@property (nonatomic, strong, readonly) NSArray *resizingLayers;

- (void)addResizingLayer:(CALayer *)layer;
- (void)removeResizingLayer:(CALayer *)layer;

@end
