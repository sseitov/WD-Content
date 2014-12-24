//
//  SettingsHeaderView.m
//  WD Content
//
//  Created by Sergey Seitov on 25.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "SettingsHeaderView.h"

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

		UILabel * ll = [[UILabel alloc] initWithFrame:CGRectMake(15, 22, 100, 44)];
		ll.backgroundColor = [UIColor clearColor];
		ll.textColor = [UIColor blackColor];
		ll.text = @"Dropbox";
		ll.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
		[self addSubview:ll];
		
		_synchroSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(80, 29, 0, 30)];
		[self addSubview:_synchroSwitch];
		
		_synchroButton = [UIButton buttonWithType:UIButtonTypeSystem];
		_synchroButton.frame = CGRectMake(frame.size.width-140, 29, 120, 30);
		_synchroButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[_synchroButton setTitle:@"Synchronize now" forState:UIControlStateNormal];
		[self addSubview:_synchroButton];
	}
	return self;
}

@end
