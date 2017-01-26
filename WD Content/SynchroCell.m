//
//  SynchroCell.m
//  WD Content
//
//  Created by Сергей Сейтов on 23.01.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import "SynchroCell.h"

@interface SynchroCell ()

@property (weak, nonatomic) IBOutlet UISwitch *synchroSwitch;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *synchroButton;

@end

@implementation SynchroCell

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (IBAction)doSync:(UIBarButtonItem*)sender {
	[self.delegate sync:sender];
}

- (IBAction)switchSynchro:(UISwitch *)sender {
	[self enableSync:sender.on];
	[self.delegate didEnableSync:sender.on];
}

- (void)enableSync:(BOOL)enable {
	self.synchroSwitch.on = enable;
	self.synchroButton.enabled = enable;
}

@end
