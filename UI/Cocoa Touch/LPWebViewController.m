//
//  LPWebViewController.m
//  Leonspok
//
//  Created by Игорь Савельев on 19/03/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import "LPWebViewController.h"

@interface LPWebViewController ()
@property (weak, nonatomic) IBOutlet UIButton *reloadButton;
@property (weak, nonatomic) IBOutlet UILabel *titleView;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@end

@implementation LPWebViewController {
    BOOL (^resposeHandler)(NSURL *url);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id)initWithTitle:(NSString *)title
            request:(NSURLRequest *)urlRequest
 andResponseHandler:(BOOL(^)(NSURL *url))responseHandler {
    self = [self initWithNibName:NSStringFromClass(self.class) bundle:nil];
    if (self) {
        self.title = title;
        _urlRequest = urlRequest;
        resposeHandler = responseHandler;
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_titleView setText:self.title];
    
    [_webView loadRequest:_urlRequest];
    _webView.delegate = self;
}

- (IBAction)selfDismiss:(id)sender {
    [[self presentingViewController] dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)reload:(id)sender {
    [_webView loadRequest:_urlRequest];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    
    if (resposeHandler) {
        return resposeHandler(url);
    }
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
