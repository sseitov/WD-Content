//
//  CollectionViewController.h
//  WD Content
//
//  Created by Sergey Seitov on 29.11.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Node.h"
#import "SettingsViewController.h"

enum ViewMode
{
	Collection,
	Table
};

@interface CollectionViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate,
UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) Node* rootNode;

@end
