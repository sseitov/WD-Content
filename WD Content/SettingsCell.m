//
//  SettingsCell.m
//  WD Content
//
//  Created by Sergey Seitov on 01.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "SettingsCell.h"

@interface SettingsCell ()

@end

@implementation SettingsCell

- (void)setAuthorization:(NSMutableDictionary*)auth
{
	_authorization = auth;
	UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 22)];
	header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	header.backgroundColor = [UIColor lightGrayColor];
	header.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
	header.textColor = [UIColor whiteColor];
	header.textAlignment = NSTextAlignmentCenter;
	header.text = [_authorization valueForKey:@"host"];
	_host.tableHeaderView = header;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _authorization ? 3 : 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell;
	if (_authorization == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:nil];
		cell.textLabel.text = @"ADD DEVICE";
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	} else {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:nil];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = @"SMB Group";
				cell.detailTextLabel.text = [_authorization valueForKey:@"workgroup"];
				break;
			case 1:
				cell.textLabel.text = @"User";
				cell.detailTextLabel.text = [_authorization valueForKey:@"user"];
				break;
			case 2:
				cell.textLabel.text = @"Password";
				cell.detailTextLabel.text = [_authorization valueForKey:@"password"];
				break;
			default:
				break;
		}
	}
	return cell;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex) {
		UITextField *value = [alertView textFieldAtIndex:0];
		if ([alertView.title isEqual:@"Workgroup"]) {
			[_authorization setObject:value.text forKey:@"workgroup"];
		} else if ([alertView.title isEqual:@"User name"]) {
			[_authorization setObject:value.text forKey:@"user"];
		} else if ([alertView.title isEqual:@"Password"]) {
			[_authorization setObject:value.text forKey:@"password"];
		}
		[_host reloadData];
	}
}

- (void)willPresentAlertView:(UIAlertView *)alertView
{
	UITextField *addr = [alertView textFieldAtIndex:0];
	if ([alertView.title isEqual:@"Workgroup"]) {
		addr.text = [_authorization objectForKey:@"workgroup"];
		addr.placeholder = @"workgroup";
	} else if ([alertView.title isEqual:@"User name"]) {
		addr.text = [_authorization objectForKey:@"user"];
		addr.placeholder = @"user name";
	} else if ([alertView.title isEqual:@"Password"]) {
		addr.text = [_authorization objectForKey:@"password"];
		addr.placeholder = @"empty for guest";
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (_authorization == nil) {
		return;
	}
	NSString *title;
	switch (indexPath.row) {
		case 0:
			title = @"Workgroup";
			break;
		case 1:
			title = @"User name";
			break;
		case 2:
			title = @"Password";
			break;
		default:
			return;
	}
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:@"" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Set", nil];
	alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	[alert show];
}

@end
