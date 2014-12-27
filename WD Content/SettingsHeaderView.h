//
//  SettingsHeaderView.h
//  WD Content
//
//  Created by Sergey Seitov on 25.12.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SyncDelegate <NSObject>

- (void)didEnableSync:(BOOL)enable;
- (void)sync;

@end

@interface SettingsHeaderView : UIView

@property (weak, nonatomic) id<SyncDelegate> delegate;

- (void)enableSync:(BOOL)enable;

@end
