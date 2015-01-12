//
//  InfoViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 08.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "InfoViewController.h"

NSString* const UpdateInfoNotification = @"UpdateInfoNotification";

@interface InfoViewController ()

@property (strong, nonatomic) NSMutableDictionary *info;
@property (strong, nonatomic) Node* node;
@property (strong, nonatomic) NSArray *fields;

@end

@implementation InfoViewController

- (void)setInfoForNode:(Node*)node
{
	_node = node;
	_info = [[NSMutableDictionary alloc] init];
	_fields = @[@"title",@"genre",@"director",@"release_date",@"runtime",@"cast",@"overview"];
	for (NSString* key in _fields) {
		id obj = [node.info valueForKey:key];
		if (obj) {
			[_info setObject:obj forKey:key];
		}
	}
	if (node.info.thumbnail) {
		[_info setObject:node.info.thumbnail forKey:@"thumbnail"];
	}
	if (node.info.original_title) {
		[_info setObject:node.info.original_title forKey:@"original_title"];
	}
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clear)];
	self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
	self.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];
}

- (void)setInfo:(NSDictionary*)info forNode:(Node*)node
{
	_node = node;
	_info = [[NSMutableDictionary alloc] init];
	_fields = @[@"title",@"genre",@"director",@"release_date",@"runtime",@"cast",@"overview"];
	for (NSString* key in _fields) {
		id obj = [info valueForKey:key];
		if (obj) {
			if ([obj isKindOfClass:[NSNumber class]]) {
				[_info setObject:[obj stringValue] forKey:key];
			} else if ([obj isKindOfClass:[NSString class]]) {
				[_info setObject:obj forKey:key];
			}
		}
	}
	if ([info objectForKey:@"thumbnail"]) {
		[_info setObject:[info objectForKey:@"thumbnail"] forKey:@"thumbnail"];
	}
	if ([info objectForKey:@"original_title"]) {
		[_info setObject:[info objectForKey:@"original_title"] forKey:@"original_title"];
	}
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(apply)];
	self.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	self.title = @"Info";
}

- (void)done
{
	[self dismissViewControllerAnimated:YES completion:^(){}];
}

- (void)clear
{
	[[DataModel sharedInstance] clearInfoForNode:_node];
	[[NSNotificationCenter defaultCenter] postNotificationName:UpdateInfoNotification object:_node];
	[self dismissViewControllerAnimated:YES completion:^(){}];
}

- (void)apply
{
	[[DataModel sharedInstance] addInfo:_info forNode:_node];
	[[NSNotificationCenter defaultCenter] postNotificationName:UpdateInfoNotification object:_node];
	[self dismissViewControllerAnimated:YES completion:^(){}];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 7;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [_fields objectAtIndex:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0) {
		return [_info objectForKey:@"thumbnail"] ? 120 : 44;
	} else {
		CGSize maximumSize = CGSizeMake(tableView.frame.size.width, 800);
		NSString *cellString = [_info objectForKey:[_fields objectAtIndex:indexPath.section]];
		UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:14];
		CGRect rect = [cellString boundingRectWithSize:maximumSize
											   options:NSStringDrawingUsesLineFragmentOrigin
											attributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]
											   context:nil];
		return rect.size.height > 44 ? rect.size.height : 44;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	}
	cell.textLabel.text = [_info objectForKey:[_fields objectAtIndex:indexPath.section]];
	if (indexPath.section == 0) {
		if ([_info objectForKey:@"thumbnail"]) {
			cell.imageView.contentMode = UIViewContentModeScaleToFill;
			cell.imageView.image = [UIImage imageWithData:[_info objectForKey:@"thumbnail"]];
		}
		cell.detailTextLabel.text = [_info objectForKey:@"original_title"];
	}
    return cell;
}

@end
