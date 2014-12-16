//
//  SharesTableViewController.h
//  WD Content
//
//  Created by Sergey Seitov on 15.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SharesTableViewControllerDelegate <NSObject>

- (void)didSelectShares:(NSArray*)nodes;
- (NSNumber*)hasNodeWithPath:(NSString*)path;

@end

@interface SharesTableViewController : UITableViewController

- (id)initWithDelegate:(id<SharesTableViewControllerDelegate>)delegate;

@end
