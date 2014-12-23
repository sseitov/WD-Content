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
#import "CollectionViewController.h"
#import	"AMSlideMenuMainViewController.h"
#import "AMSlideMenuLeftMenuSegue.h"
#import "SharesTableViewController.h"

NSString* const UpdateMenuNotification = @"UpdateMenuNotification";

@interface LeftMenuVC() <SharesTableViewControllerDelegate>

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
	[_rows addObjectsFromArray:[[DataModel sharedInstance] nodesByRoot:nil]];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleUpdateMenu:) name:UpdateMenuNotification object:nil];
}

- (void)handleUpdateMenu:(NSNotification*)note
{
	[_rows removeAllObjects];
	[_rows addObjectsFromArray:[[DataModel sharedInstance] nodesByRoot:nil]];
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
	}
	if (indexPath.section) {
		Node* node = _rows[indexPath.row];
		cell.textLabel.text = node.name;
		cell.imageView.image = [UIImage imageWithData:node.image];
	} else {
		cell.textLabel.text = @"WD Devices";
	}
	
	return cell;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if (section) {
		UIView* v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 44)];
		v.backgroundColor = [UIColor colorWithRed:0 green:113.0/255.0 blue:165.0/255.0 alpha:1];
		UIButton* b = [UIButton buttonWithType:UIButtonTypeContactAdd];
		b.tintColor = [UIColor whiteColor];
		b.frame = CGRectMake(210, 0, 44, 44);
		[b addTarget:self action:@selector(doEdit) forControlEvents:UIControlEventTouchDown];
		[v addSubview:b];
		
		UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 100, 44)];
		l.backgroundColor = [UIColor clearColor];
		l.textColor = [UIColor whiteColor];
		l.text = @"FOLDERS";
		l.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
		[v addSubview:l];
		
		return v;
	} else {
		UIView* v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 44)];
		v.backgroundColor = [UIColor colorWithRed:0 green:113.0/255.0 blue:165.0/255.0 alpha:1];
		
		UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 100, 44)];
		l.backgroundColor = [UIColor clearColor];
		l.textColor = [UIColor whiteColor];
		l.text = @"SETTINGS";
		l.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
		[v addSubview:l];
		
		return v;
	}
}

- (void)doEdit
{
	[self performSegueWithIdentifier:@"Shares" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"Content"])
	{
		UINavigationController *vc = [segue destinationViewController];
		NSIndexPath* indexPath = [self.tableView indexPathForSelectedRow];
		if (indexPath) {
			[DataModel setLastIndex:indexPath];
		} else {
			AMSlideMenuLeftMenuSegue* seq = (AMSlideMenuLeftMenuSegue*)sender;
			AMSlideMenuMainViewController* mainVC = seq.sourceViewController;
			indexPath = mainVC.initialIndexPathForLeftMenu;
		}
		Node* node = [_rows objectAtIndex:indexPath.row];
		CollectionViewController* collection = (CollectionViewController*)vc.topViewController;
		collection.rootNode = node;
	} else if ([[segue identifier] isEqualToString:@"Shares"]) {
		UINavigationController *vc = [segue destinationViewController];
		SharesTableViewController* shares = (SharesTableViewController*)vc.topViewController;
		shares.sharesDelegate = self;
		shares.initialNodes = _rows;
	}
}

- (void)didSelectShares:(NSArray*)shares
{
	[self dismissViewControllerAnimated:NO completion:^() {
		if (shares) {
			for (NSDictionary* row in shares) {
				KxSMBItem* item = [row objectForKey:@"item"];
				NSNumber* checked = [row objectForKey:@"checked"];
				Node* node = [[DataModel sharedInstance] nodeByPath:item.path];
				if ([checked boolValue] == YES && !node) {
					[[DataModel sharedInstance] newNodeForItem:item withParent:nil];
				} else if ([checked boolValue] == NO && node) {
					[[DataModel sharedInstance] deleteNode:node];
				}
			}
			[_rows removeAllObjects];
			[_rows addObjectsFromArray:[[DataModel sharedInstance] nodesByRoot:nil]];
			[self.tableView reloadData];
		}
		[self.mainVC openLeftMenu];
	}];
}

- (NSNumber*)hasNodeWithPath:(NSString*)path
{
	for (Node* n in _rows) {
		if ([n.path isEqual:path]) {
			return [NSNumber numberWithBool:YES];
		}
	}
	return [NSNumber numberWithBool:NO];
}

@end
