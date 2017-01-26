//
//  SettingsViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 01.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "SettingsViewController.h"
#import "DataModel.h"
#import "SVProgressHUD.h"
#import "LeftMenuVC.h"
#import "AppDelegate.h"
#import "DropboxClient.h"
#import "SynchroCell.h"
#import "WD_Content-Swift.h"
#import "UIViewController+UIViewControllerExtensions.h"

@interface SettingsViewController () <SyncDelegate, HostBrowserControllerDelegate>
{
	DropboxClient* _authDropboxClient;
	DropboxClient* _contentDropboxClient;
}

@property (nonatomic, readonly) DropboxClient* authDropboxClient;
@property (nonatomic, readonly) DropboxClient* contentDropboxClient;
@property (retain) SynchroCell* synchroCell;

@end

@implementation SettingsViewController

- (DropboxClient*)authDropboxClient
{
	if (!_authDropboxClient) {
		_authDropboxClient = [[DropboxClient alloc] initForFile:Auth];
		_authDropboxClient.actionView = self.view;
	}
	return _authDropboxClient;
}

- (DropboxClient*)contentDropboxClient
{
	if (!_contentDropboxClient) {
		_contentDropboxClient = [[DropboxClient alloc] initForFile:Content];
		_contentDropboxClient.actionView = self.view;
	}
	return _contentDropboxClient;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[self setTitle:@"WD Devices"];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleFinishAuthSynchro:) name:FinishAuthSynchroNotification object:nil];
	[nc addObserver:self selector:@selector(handleFinishContentSynchro:) name:FinishContentSynchroNotification object:nil];
	[nc addObserver:self selector:@selector(handleErrrorDBAccount:) name:ErrorDBAccountNotification object:nil];
	
	self.synchroCell = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0) {
		return @"Synchronization";
	} else {
		return @"Devices";
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0) {
		return 1;
	} else {
		return [DataModel auth].count;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 30;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0) {
		if (self.synchroCell == nil) {
			self.synchroCell = [self.tableView dequeueReusableCellWithIdentifier:@"synchro_cell" forIndexPath:indexPath];
			[self.synchroCell enableSync:[[DBSession sharedSession] isLinked]];
			self.synchroCell.delegate = self;
		}
		return self.synchroCell;
	} else {
		UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
		cell.textLabel.font = [UIFont fontWithName: @"HelveticaNeue" size:15];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		NSDictionary* auth = [[DataModel auth] objectAtIndex:indexPath.row];
		cell.textLabel.text = [auth valueForKey:@"host"];
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.textLabel.textColor = [UIColor blackColor];
		return cell;
		return cell;
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return (indexPath.section > 0);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0) {
		return;
	}
	
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [tableView beginUpdates];
		NSDictionary* host = [[DataModel auth] objectAtIndex:indexPath.row];
		[DataModel removeHost:host];
		[[NSNotificationCenter defaultCenter] postNotificationName:UpdateMenuNotification object:self];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
		[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"initialIndex"];
        [tableView endUpdates];
    }
}

#pragma mark - SyncDelegate

- (void)didEnableSync:(BOOL)enable
{
	if (enable) {
		if (![[DBSession sharedSession] isLinked]) {
			[[DBSession sharedSession] linkFromController:self];
		}
	} else {
		[[DBSession sharedSession] unlinkAll];
	}
}

- (void)sync:(UIBarButtonItem*)sender
{
	[SVProgressHUD showWithStatus:@"Synchronize..."];

	if (IS_PAD) {
		self.authDropboxClient.actionButton = sender;
	}
	[self.authDropboxClient sync];
}

#pragma mark - synchronization

- (void)handleFinishAuthSynchro:(NSNotification*)note
{
	NSNumber* result = (NSNumber*)note.object;
	if ([result boolValue] == YES) {
		if (note.userInfo) {	// download from dropbox
			DBMetadata* meta = [note.userInfo objectForKey:@"meta"];
			[DataModel setLastAuthModified:meta.lastModifiedDate];
		}
		[self.tableView reloadData];
		[self.contentDropboxClient sync];
	}
	[self.contentDropboxClient sync];
}

- (void)handleFinishContentSynchro:(NSNotification*)note
{
	NSNumber* result = (NSNumber*)note.object;
	[SVProgressHUD dismiss];
	if ([result boolValue] == YES) {
		if (note.userInfo) {	// download from dropbox
			[[DataModel sharedInstance] updateDB];
			DBMetadata* meta = [note.userInfo objectForKey:@"meta"];
			[DataModel setLastModified:meta.lastModifiedDate];
			[[NSNotificationCenter defaultCenter] postNotificationName:UpdateMenuNotification object:self];
		}
	}
}

- (void)handleErrrorDBAccount:(NSNotification*)note
{
	if (self.synchroCell != nil) {
		[self.synchroCell enableSync:NO];
	}
}

#pragma mark - navigation

- (IBAction)browse:(UIBarButtonItem*)sender {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"Add Device" preferredStyle:UIAlertControllerStyleActionSheet];
	[alert addAction:[UIAlertAction actionWithTitle:@"Browse local" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self performSegueWithIdentifier:@"browse" sender:nil];
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Add manually" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self performSegueWithIdentifier:@"add" sender:nil];
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive handler:nil]];
	if (IS_PAD) {
		[alert setModalPresentationStyle:UIModalPresentationPopover];
		UIPopoverPresentationController* popover = alert.popoverPresentationController;
		popover.barButtonItem = sender;
		[self presentViewController:alert animated:YES completion:nil];
	} else {
		[self presentViewController:alert animated:YES completion:nil];
	}
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqual:@"browse"]) {
		UINavigationController * nav = segue.destinationViewController;
		HostBrowserController * controller = (HostBrowserController*)nav.topViewController;
		controller.delegate = self;
	} else 	if ([segue.identifier isEqual:@"add"]) {
		UINavigationController * nav = segue.destinationViewController;
		AddHostController * controller = (AddHostController*)nav.topViewController;
		controller.delegate = self;
	}

}

- (void)addHost:(NSString *)path content:(NSArray<NSString *> *)content user:(NSString *)user password:(NSString *)password {
	[self dismissViewControllerAnimated:YES completion:^{
		NSMutableDictionary* host = [NSMutableDictionary dictionary];
		[host setObject:path forKey:@"host"];
		[host setObject:content forKey:@"folders"];
		[host setObject:@"WORKGROUP" forKey:@"workgroup"];
		if (user != nil) {
			[host setObject:user forKey:@"user"];
		} else {
			[host setObject:@"guest" forKey:@"user"];
		}
		if (password != nil) {
			[host setObject:password forKey:@"password"];
		} else {
			[host setObject:@"" forKey:@"password"];
		}
		[DataModel addHost:host];
		[self.tableView reloadData];
	}];
}

@end
