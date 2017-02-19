//
//  VideoController.h
//  WD Content
//
//  Created by Сергей Сейтов on 19.02.17.
//  Copyright © 2017 Sergey Seitov. All rights reserved.
//

#import <GLKit/GLKit.h>

@interface VideoController : GLKViewController

@property (retain, nonatomic) NSString* host;
@property (nonatomic) int port;
@property (retain, nonatomic) NSString* user;
@property (retain, nonatomic) NSString* password;
@property (retain, nonatomic) NSString* filePath;

@end
