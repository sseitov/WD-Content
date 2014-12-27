//
//  Cell.h
//  WD Content
//
//  Created by Sergey Seitov on 29.11.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DataModel.h"

@interface Cell : UICollectionViewCell

@property (strong, nonatomic) IBOutlet UILabel *title;
@property (strong, nonatomic) IBOutlet UIImageView *image;

- (void)setInfo:(Node*)node;

@end
