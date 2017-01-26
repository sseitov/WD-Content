//
//  UIViewController+UIViewControllerExtensions.h
//  WD Content
//
//  Created by Сергей Сейтов on 26.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface UIViewController (UIViewControllerExtensions)

- (void)setTitle:(NSString*)text;
- (void)errorMessage:(NSString*)message;

@end
