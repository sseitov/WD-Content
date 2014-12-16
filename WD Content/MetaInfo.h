//
//  MetaInfo.h
//  WD Content
//
//  Created by Сергей Сейтов on 23.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Node;

@interface MetaInfo : NSManagedObject

@property (nonatomic, retain) NSString * cast;
@property (nonatomic, retain) NSString * director;
@property (nonatomic, retain) NSString * genre;
@property (nonatomic, retain) NSString * original_title;
@property (nonatomic, retain) NSString * overview;
@property (nonatomic, retain) NSString * release_date;
@property (nonatomic, retain) NSString * runtime;
@property (nonatomic, retain) NSData * thumbnail;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) Node *node;

@end
