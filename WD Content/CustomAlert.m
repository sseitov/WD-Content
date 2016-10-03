//
//  CustomAlert.m
//  WD Content
//
//  Created by Сергей Сейтов on 03.10.16.
//  Copyright © 2016 Sergey Seitov. All rights reserved.
//

#import "CustomAlert.h"

@interface CustomAlert ()

@end

@implementation CustomAlert

- (void)viewDidLoad {
    [super viewDidLoad];
	
	for (int i=0; i<self.textFields.count; i++) {
		UITextField* field = self.textFields[i];
		field.superview.superview.layer.frame = CGRectZero;
		field.superview.superview.layer.borderWidth = 2;
		field.superview.superview.layer.borderColor = [UIColor whiteColor].CGColor;
		field.frame = CGRectMake(-100, 3, 220, 32);
	}
}

@end
