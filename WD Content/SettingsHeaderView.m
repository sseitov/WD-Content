//
//  SettingsHeaderView.m
//  WD Content
//
//  Created by Sergey Seitov on 25.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "SettingsHeaderView.h"

@interface SettingsHeaderView ()

@property (strong, nonatomic) UIToolbar* toolbar;

@end

@implementation SettingsHeaderView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		UIView * v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 22)];
		v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		v.backgroundColor = [UIColor colorWithRed:0 green:113.0/255.0 blue:165.0/255.0 alpha:1];
		
		UILabel * l = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 100, 22)];
		l.backgroundColor = [UIColor clearColor];
		l.textColor = [UIColor whiteColor];
		l.text = @"SYNCHRO";
		l.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
		[v addSubview:l];
		
		[self addSubview:v];

		_toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 22, frame.size.width, 44)];
		_toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		UILabel * ll = [[UILabel alloc] initWithFrame:CGRectMake(15, 22, 60, 44)];
		ll.backgroundColor = [UIColor clearColor];
		ll.textColor = [UIColor blackColor];
		ll.text = @"Dropbox";
		ll.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
		UIBarButtonItem* btn1 = [[UIBarButtonItem alloc] initWithCustomView:ll];
		
		UISwitch* s = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
		[s addTarget:self action:@selector(switchSynchro:) forControlEvents:UIControlEventValueChanged];
		UIBarButtonItem* btn2 = [[UIBarButtonItem alloc] initWithCustomView:s];
		
		UIBarButtonItem* space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		
		UIBarButtonItem* btn3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
																			  target:self.delegate action:@selector(sync)];
	
		_toolbar.items = @[btn1, btn2, space, btn3];
		[self addSubview:_toolbar];
	}
	return self;
}

- (void)enableSync:(BOOL)enable
{
	UISwitch* s = (UISwitch*)[[_toolbar.items objectAtIndex:1] customView];
	s.on = enable;
	UIBarButtonItem* b = [_toolbar.items objectAtIndex:3];
	b.enabled = enable;
}

- (void)switchSynchro:(UISwitch*)sender
{
	[self enableSync:sender.on];
	[self.delegate didEnableSync:sender.on];
}

@end
