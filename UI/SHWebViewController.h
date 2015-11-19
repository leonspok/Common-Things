//
//  TTWebViewController.h
//  tentracks-ios
//
//  Created by Игорь Савельев on 19/03/14.
//  Copyright (c) 2014 10tracks. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SHWebViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, strong) NSURLRequest *urlRequest;

- (id)initWithTitle:(NSString *)title
            request:(NSURLRequest *)urlRequest
 andResponseHandler:(BOOL(^)(NSURL *url))responseHandler;

- (IBAction)reload:(id)sender;

@end
