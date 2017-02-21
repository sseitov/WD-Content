//
//  MovieController.h
//  WD Content
//
//  Created by Сергей Сейтов on 21.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

@interface MovieController : UIViewController <GLKViewControllerDelegate>

@property (retain, nonatomic)	NSString*	host;
@property (nonatomic)			int			port;
@property (retain, nonatomic)	NSString*	user;
@property (retain, nonatomic)	NSString*	password;
@property (retain, nonatomic)	NSString*	filePath;

@end
