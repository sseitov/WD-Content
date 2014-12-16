//
//  InfoViewController.h
//  WD Content
//
//  Created by Sergey Seitov on 08.12.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DataModel.h"

extern NSString* const UpdateInfoNotification;

@interface InfoViewController : UITableViewController

- (id)initWithMetaInfo:(MetaInfo*)info forNode:(Node*)node;
- (id)initWithDictionary:(NSDictionary*)info forNode:(Node*)node;

@end
