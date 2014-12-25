//
//  BorderedButton.m
//  WD Content
//
//  Created by Sergey Seitov on 25.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "BorderedButton.h"

@implementation BorderedButton

- (id)initWithFrame:(CGRect)frame text:(NSString*)text
{
	self = [super initWithFrame:frame];
	if (self) {
		NSMutableAttributedString *activeText=[[NSMutableAttributedString alloc] initWithString:text];
		[activeText addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:14]
						   range:NSMakeRange(0, text.length)];
		[activeText addAttribute:NSForegroundColorAttributeName
						   value:[UIColor colorWithRed:0 green:126.0/255.0 blue:1 alpha:1]
						   range:NSMakeRange(0, text.length)];
		
		NSMutableAttributedString *disableText=[[NSMutableAttributedString alloc] initWithString:text];
		[disableText addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:14]
							range:NSMakeRange(0, text.length)];
		[disableText addAttribute:NSForegroundColorAttributeName
							value:[UIColor lightGrayColor]
							range:NSMakeRange(0, text.length)];
		
		[self setAttributedTitle:activeText forState:UIControlStateNormal];
		[self setAttributedTitle:disableText forState:UIControlStateDisabled];
		
		self.backgroundColor = [UIColor whiteColor];
		self.layer.borderWidth = 1.0;
		self.layer.masksToBounds = YES;
		self.layer.cornerRadius = 5.0;
	}
	return self;
}

- (void)setEnabled:(BOOL)enabled
{
	[super setEnabled:enabled];
	if (enabled) {
		UIColor* color = [UIColor colorWithRed:0 green:126.0/255.0 blue:1 alpha:1];
		self.layer.borderColor = color.CGColor;
	} else {
		self.layer.borderColor = [UIColor lightGrayColor].CGColor;
	}
}

@end
