//
//  SettingsHeaderView.m
//  WD Content
//
//  Created by Sergey Seitov on 25.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "SettingsHeaderView.h"
#import "BorderedButton.h"

@implementation SettingsHeaderView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		UIView * v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 22)];
		v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		v.backgroundColor = [UIColor colorWithRed:0 green:113.0/255.0 blue:165.0/255.0 alpha:1];
		[self addSubview:v];
		
		UILabel * l = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 100, 22)];
		l.backgroundColor = [UIColor clearColor];
		l.textColor = [UIColor whiteColor];
		l.text = @"SYNCHRO";
		l.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
		[v addSubview:l];

		UIToolbar* toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 22, frame.size.width, 44)];
		toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		UILabel * ll = [[UILabel alloc] initWithFrame:CGRectMake(15, 22, 60, 44)];
		ll.backgroundColor = [UIColor clearColor];
		ll.textColor = [UIColor blackColor];
		ll.text = @"Dropbox";
		ll.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
		UIBarButtonItem* btn1 = [[UIBarButtonItem alloc] initWithCustomView:ll];

		_synchroSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
		UIBarButtonItem* btn2 = [[UIBarButtonItem alloc] initWithCustomView:_synchroSwitch];
		
		_synchroButton = [[BorderedButton alloc] initWithFrame:CGRectMake(0, 0, 120, 30) text:@"Synchronize now"];
		UIBarButtonItem* btn3 = [[UIBarButtonItem alloc] initWithCustomView:_synchroButton];

		UIBarButtonItem* space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		toolbar.items = @[btn1, btn2, space, btn3];
		[self addSubview:toolbar];
	}
	return self;
}

@end
