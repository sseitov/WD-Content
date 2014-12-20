//
//  LeftMenuVC.m
//  AMSlideMenu
//
// The MIT License (MIT)
//
// Created by : arturdev
// Copyright (c) 2014 SocialObjects Software. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE

#import "LeftMenuVC.h"
#import "DataModel.h"
#import "Notifications.h"

@interface LeftMenuVC()

@property (strong, nonatomic) NSMutableArray *rows;

@end

@implementation LeftMenuVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0 && ![UIApplication sharedApplication].isStatusBarHidden)
    {
        self.tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
    }
	_rows = [NSMutableArray new];
	[self createFoldersList:[DataModel auth]];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleUpdateMenu:) name:UpdateMenuNotification object:nil];
}

- (void)createFoldersList:(NSArray*)auth
{
	[_rows removeAllObjects];
	for (NSDictionary *host in auth) {
		NSArray* folders = [host objectForKey:@"folders"];
		if (folders.count > 0) {
			[_rows addObjectsFromArray:folders];
		}
	}
}

- (void)handleUpdateMenu:(NSNotification*)note
{
	[self createFoldersList:[DataModel auth]];
	[self.tableView reloadData];
}

#pragma mark - UITableView delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section) {
		return [_rows count];
	} else {
		return 1;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
		cell.backgroundColor = [UIColor clearColor];
		cell.contentView.backgroundColor = [UIColor clearColor];
		cell.textLabel.textColor = [UIColor whiteColor];
	}
	if (indexPath.section) {
		cell.textLabel.text = [_rows[indexPath.row] lastPathComponent];
	} else {
		cell.textLabel.text = @"WD Devices";
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section) {
		[self performSegueWithIdentifier:@"Content" sender:indexPath];
	} else  {
		[self performSegueWithIdentifier:@"Devices" sender:nil];
	}
}

@end
