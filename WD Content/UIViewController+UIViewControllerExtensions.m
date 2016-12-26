//
//  UIViewController+UIViewControllerExtensions.m
//  WD Content
//
//  Created by Сергей Сейтов on 26.12.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

#import "UIViewController+UIViewControllerExtensions.h"

@implementation UIViewController (UIViewControllerExtensions)

- (void)setTitle:(NSString*)text {
	
	UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
	label.textAlignment = NSTextAlignmentCenter;
	label.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:15];
	label.text = text;
	label.textColor = [UIColor whiteColor];
	label.numberOfLines = 0;
	label.lineBreakMode = NSLineBreakByWordWrapping;
	self.navigationItem.titleView = label;
}

@end
