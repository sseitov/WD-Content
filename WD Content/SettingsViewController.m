//
//  SettingsViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 01.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "SettingsViewController.h"
#import "DataModel.h"

@interface SettingsViewController ()

@property (strong, nonatomic) NSMutableArray* authContainer;

@end

@implementation SettingsViewController

- (void)awakeFromNib
{
	self.title = @"WD Devices";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	_authContainer = [[NSMutableArray alloc] init];
	NSDictionary *auth = [[NSUserDefaults standardUserDefaults] objectForKey:@"auth"];
	if (auth) {
		for (NSString *host in auth.allKeys) {
			NSDictionary *server = [NSDictionary dictionaryWithObjectsAndKeys:
									host, @"host",
									[NSMutableDictionary dictionaryWithDictionary:[auth objectForKey:host]], @"auth", nil];
			[_authContainer addObject:server];
		}
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (_authContainer.count == 0) {
		[self setEditing:YES animated:YES];
		[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] animated:YES];
	} else {
		[self setEditing:NO animated:YES];
		[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(edit)] animated:YES];
	}
	[self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	[self setEditing:NO animated:YES];
	[self.tableView reloadData];
	[DataModel setAuth:_authContainer];
}

- (void)edit
{
	[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] animated:YES];
	[self setEditing:YES animated:YES];
	[self.tableView reloadData];
}

- (void)done
{
	[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(edit)] animated:YES];
	[self setEditing:NO animated:YES];
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (self.editing) {
		return _authContainer.count + 1;
	} else {
		return _authContainer.count > 0 ? _authContainer.count : 1;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section < _authContainer.count && _authContainer.count > 0) {
		return 44;
	} else {
		return 0;
	}
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if (section < _authContainer.count && _authContainer.count > 0) {
		UILabel *header = [[UILabel alloc] initWithFrame:CGRectZero];
		header.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		header.backgroundColor = [UIColor lightGrayColor];
		header.textColor = [UIColor whiteColor];
		header.textAlignment = NSTextAlignmentCenter;
		header.text = [[_authContainer objectAtIndex:section] valueForKey:@"host"];
		return header;
	} else {
		return nil;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (_authContainer.count > 0 || self.editing) {
		return 1;
	} else {
		return 0;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return indexPath.section < _authContainer.count ? 132 : 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"settings_cell";
	
	SettingsCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
	if (indexPath.section < _authContainer.count && _authContainer.count > 0) {
		cell.authorization = [[_authContainer objectAtIndex:indexPath.section] objectForKey:@"auth"];
	} else {
		cell.authorization = nil;
	}
	[cell setEditing:self.editing animated:NO];
	[cell.host reloadData];
	
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section < _authContainer.count) {
		return UITableViewCellEditingStyleDelete;
	} else {
		return UITableViewCellEditingStyleInsert;
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex) {
		UITextField *addr = [alertView textFieldAtIndex:0];
		
		NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"WORKGROUP", @"workgroup", @"guest", @"user", @"", @"password", nil];
		[_authContainer addObject:[NSDictionary dictionaryWithObjectsAndKeys:addr.text, @"host", auth, @"auth", nil]];
		[self.tableView reloadData];
	}
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		[_authContainer removeObjectAtIndex:indexPath.section];
        [tableView beginUpdates];
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationTop];
        [tableView endUpdates];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enter WD device IP address" message:@"xxx.xxx.xxx.xxx" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Add", nil];
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert show];
    }
}

@end
