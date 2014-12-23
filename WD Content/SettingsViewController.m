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
#import "AppDelegate.h"

@interface SettingsViewController ()

@property (strong, nonatomic) NSMutableArray* authContainer;
@property (strong, nonatomic) UISwitch* synchroSwitch;

@end

@implementation SettingsViewController

- (void)awakeFromNib
{
	self.title = @"WD Devices";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleUpdateDB:) name:UpdateDBNotification object:nil];

	UIView* tableHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 66)];
	tableHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	UIView * v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 22)];
	v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	v.backgroundColor = [UIColor colorWithRed:0 green:113.0/255.0 blue:165.0/255.0 alpha:1];
	UILabel * l = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 100, 22)];
	l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	l.textColor = [UIColor whiteColor];
	l.text = @"SYNCHRO";
	l.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
	[v addSubview:l];
	[tableHeader addSubview:v];
	
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:nil];
	cell.frame = CGRectMake(0, 22, self.tableView.frame.size.width, 44);
	cell.textLabel.text = @"Dropbox";
	cell.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	_synchroSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.tableView.frame.size.width-70, 7, 0, 30)];
	_synchroSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	_synchroSwitch.on = [DataModel enableSynchro];
	[_synchroSwitch addTarget:self action:@selector(doSynchro:) forControlEvents:UIControlEventValueChanged];
	[cell.contentView addSubview:_synchroSwitch];

	[tableHeader addSubview:cell];
	
	self.tableView.tableHeaderView = tableHeader;
	
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

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return @"Devices";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.editing) {
		return _authContainer.count + 1;
	} else {
		return _authContainer.count > 0 ? _authContainer.count : 1;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return indexPath.row < _authContainer.count ? 154 : 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"settings_cell";
	
	if (indexPath.row < _authContainer.count && _authContainer.count > 0) {
		SettingsCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
		cell.authorization = [_authContainer objectAtIndex:indexPath.section];
		[cell.host reloadData];
		[cell setEditing:self.editing animated:NO];
		return cell;
	} else {
		UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:nil];
		cell.textLabel.text = @"ADD DEVICE";
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row < _authContainer.count) {
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
		NSDictionary* host = [_authContainer objectAtIndex:indexPath.row];
		[DataModel removeHost:host];
		[[NSNotificationCenter defaultCenter] postNotificationName:UpdateMenuNotification object:self];
		[_authContainer removeObjectAtIndex:indexPath.section];
        [tableView beginUpdates];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
        [tableView endUpdates];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Enter WD device IP address" message:@"xxx.xxx.xxx.xxx" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Add", nil];
		alert.tag = 1;
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert show];
    }
}

#pragma mark - synchronization

- (void)doSynchro:(UISwitch*)sender
{
	if (sender.on) {
		AppDelegate* app = (AppDelegate*)[UIApplication sharedApplication].delegate;
		[app sync:self];
	} else {
		[DataModel setEnableSynchro:NO];
	}
}

- (void)handleUpdateDB:(NSNotification*)note
{
	NSNumber* result = (NSNumber*)note.object;
	_synchroSwitch.on = [result boolValue];
}

@end
