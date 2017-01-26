//
//  SynchroCell.h
//  WD Content
//
//  Created by Сергей Сейтов on 23.01.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SyncDelegate <NSObject>

- (void)didEnableSync:(BOOL)enable;
- (void)sync:(UIBarButtonItem*)sender;

@end

@interface SynchroCell : UITableViewCell

@property (weak, nonatomic) id<SyncDelegate> delegate;

- (void)enableSync:(BOOL)enable;

@end
