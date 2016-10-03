//
//  SettingsCell.m
//  WD Content
//
//  Created by Sergey Seitov on 01.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "SettingsCell.h"
#import "CustomAlert.h"

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
    return 3;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:nil];
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
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (_authorization == nil) {
		return;
	}

	UIAlertController *alert;
	switch (indexPath.row) {
		case 0:
			alert = [CustomAlert alertControllerWithTitle:@"Workgroup" message:nil preferredStyle:UIAlertControllerStyleAlert];
			break;
		case 1:
			alert = [CustomAlert alertControllerWithTitle:@"User name" message:nil preferredStyle:UIAlertControllerStyleAlert];
			break;
		case 2:
			alert = [CustomAlert alertControllerWithTitle:@"Password" message:nil preferredStyle:UIAlertControllerStyleAlert];
			break;
		default:
			return;
	}
	__block UITextField *cellTextField;
	UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDestructive
														 handler:^(UIAlertAction * action) {}];
	UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Set" style:UIAlertActionStyleDefault
														  handler:^(UIAlertAction * action) {
															  switch (indexPath.row) {
																  case 0:
																	  [_authorization setObject:cellTextField.text forKey:@"workgroup"];
																	  [self.host reloadData];
																	  break;
																  case 1:
																	  [_authorization setObject:cellTextField.text forKey:@"user"];
																	  [self.host reloadData];
																	  break;
																  case 2:
																	  [_authorization setObject:cellTextField.text forKey:@"password"];
																	  [self.host reloadData];
																	  break;
																  default:
																	  break;
															  }
														  }];
	[alert addAction:cancelAction];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		switch (indexPath.row) {
			case 0:
				textField.placeholder = @"workgroup";
				textField.text = [_authorization objectForKey:@"workgroup"];
				break;
			case 1:
				textField.placeholder = @"User name";
				textField.text = [_authorization objectForKey:@"user"];
				break;
			case 2:
				textField.placeholder = @"empty for guest";
				textField.text = [_authorization objectForKey:@"password"];
				break;
			default:
				break;
		}
		textField.textAlignment = NSTextAlignmentCenter;
		textField.borderStyle = UITextBorderStyleRoundedRect;
		cellTextField = textField;
	}];
	[alert addAction:defaultAction];
	[self.controller presentViewController:alert animated:YES completion:^{
		cellTextField.frame = CGRectMake(-100, 3, 220, 32);
	}];
}

@end
