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
#import "LeftMenuVC.h"

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

#define WAIT(a) [a lock]; [a wait]; [a unlock]
#define SIGNAL(a) [a lock]; [a signal]; [a unlock]

- (void)refreshHosts:(void (^)(NSArray*))result
{
	[MBProgressHUD showHUDAddedTo:self.view animated:YES];
	NSCondition* next = [[NSCondition alloc] init];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
		[DataModel setAuth:_authContainer];
		NSMutableArray* errors = [NSMutableArray new];
		for (NSMutableDictionary* host in _authContainer) {
			if ([[host objectForKey:@"validated"] boolValue] == NO) {
				[self updateHost:host result:^(NSArray* items, NSString* err) {
					if (err) {
						[DataModel removeHost:host];
						[errors addObject:err];
					} else {
						for (KxSMBItem *item in items) {
							[[DataModel sharedInstance] newNodeForItem:item withParent:nil];
						}
						[DataModel setHost:host];
					}
					SIGNAL(next);
				}];
				WAIT(next);
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			result(errors);
		});

	});
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

- (void)updateHost:(NSMutableDictionary*)host result:(void (^)(NSArray*, NSString*))result
{
	id res = [[DataModel sharedInstance].provider fetchAtPath:[NSString stringWithFormat:@"smb://%@", [host objectForKey:@"host"]]];
	NSString* err = nil;
	NSMutableArray* items = [NSMutableArray new];
	NSMutableArray* folders = [NSMutableArray new];
	if ([res isKindOfClass:[NSError class]]) {
		err = [NSString stringWithFormat:@"Error connect to %@", [host objectForKey:@"host"]];
	} else {
		if ([res isKindOfClass:[NSArray class]]) {
			for (KxSMBItem* item in res) {
				[items addObject:item];
				[folders addObject:item.path];
			}
		} else if ([res isKindOfClass:[KxSMBItem class]]) {
			KxSMBItem* item = (KxSMBItem*)res;
			[items addObject:item];
			[folders addObject:item.path];
		}
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!err) {
			[host setObject:folders forKey:@"folders"];
		}
		result(items, err);
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
		NSDictionary* host = [_authContainer objectAtIndex:indexPath.section];
		[DataModel removeHost:host];
		[[NSNotificationCenter defaultCenter] postNotificationName:UpdateMenuNotification object:self];
		[_authContainer removeObjectAtIndex:indexPath.section];
        [tableView beginUpdates];
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationTop];
        [tableView endUpdates];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enter WD device IP address" message:@"xxx.xxx.xxx.xxx" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Add", nil];
		alert.tag = 1;
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert show];
    }
}

@end
