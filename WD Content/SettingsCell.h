//
//  SettingsCell.h
//  WD Content
//
//  Created by Sergey Seitov on 01.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SettingsCell;

@interface SettingsCell : UITableViewCell<UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UITableView *host;

@property (weak, nonatomic, setter=setAuthorization:) NSMutableDictionary *authorization;

@end
