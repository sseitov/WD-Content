//
//  SettingsViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 01.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "SettingsViewController.h"
#import "DataModel.h"
#import "MBProgressHUD.h"
#import "Notifications.h"

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
	[self loadContainer];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (_authContainer.count == 0) {
		[self setEditing:YES animated:YES];
		[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] animated:YES];
	} else {
		[self setEditing:NO animated:YES];
		[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(edit)] animated:YES];
	}
	[self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	[self setEditing:NO animated:YES];
}

- (void)loadContainer
{
	[_authContainer removeAllObjects];
	NSArray *auth = [DataModel auth];
	if (auth.count > 0) {
		[_authContainer addObjectsFromArray:auth];
	}
}

- (void)edit
{
	[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] animated:YES];
	[self setEditing:YES animated:YES];
	[self.tableView reloadData];
}

- (void)refreshHosts:(void (^)(NSArray*))result
{
	[DataModel setAuth:_authContainer];
	NSMutableArray* errors = [NSMutableArray new];
	for (NSMutableDictionary* host in _authContainer) {
		[self updateHost:host error:^(NSString* err) {
			if (err) {
				[DataModel removeHost:host];
				[errors addObject:err];
			} else {
				[DataModel setHost:host];
			}
			if ([host isEqual:[_authContainer lastObject]]) {
				result(errors);
			}
		}];
	}
}

- (void)done
{
	[self refreshHosts:^(NSArray* errors) {
		if (errors.count > 0) {
			NSString* error = errors.count > 1 ? @"Error connect to some hosts!" : [errors objectAtIndex:0];
			UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error"
															message:error
														   delegate:nil
												  cancelButtonTitle:@"Ok"
												  otherButtonTitles:nil, nil];
			[alert show];
		}
		[self loadContainer];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:UpdateMenuNotification object:self];

		if (_authContainer.count > 0) {
			[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(edit)] animated:YES];
			[self setEditing:NO animated:YES];
		} else if (errors.count == 0) {
			UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error"
															message:@"It is necessary to add at least one device!"
														   delegate:nil
												  cancelButtonTitle:@"Ok"
												  otherButtonTitles:nil, nil];
			[alert show];
		}
		[self.tableView reloadData];
	}];
	
}

- (void)updateHost:(NSMutableDictionary*)host error:(void (^)(NSString*))error
{
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
		id result = [[DataModel sharedInstance].provider fetchAtPath:[NSString stringWithFormat:@"smb://%@", [host objectForKey:@"host"]]];
		NSString* err = nil;
		if ([result isKindOfClass:[NSError class]]) {
			err = [NSString stringWithFormat:@"Error connect to %@", [host objectForKey:@"host"]];
		} else {
			NSMutableArray* folders = [NSMutableArray new];
			if ([result isKindOfClass:[NSArray class]]) {
				for (KxSMBItem* item in result) {
					[folders addObject:item.path];
				}
			} else if ([result isKindOfClass:[KxSMBItem class]]) {
				KxSMBItem* item = (KxSMBItem*)result;
				[folders addObject:item.path];
			}
			[host setObject:folders forKey:@"folders"];
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			error(err);
		});
	});
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
		cell.authorization = [_authContainer objectAtIndex:indexPath.section];
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
		
		NSMutableDictionary *auth = [NSMutableDictionary dictionaryWithObjectsAndKeys:addr.text, @"host", @"WORKGROUP", @"workgroup", @"guest", @"user", @"", @"password", nil];
		[_authContainer addObject:auth];
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
