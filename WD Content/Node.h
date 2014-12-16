//
//  Node.h
//  WD Content
//
//  Created by Сергей Сейтов on 17.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MetaInfo, Node;

@interface Node : NSManagedObject

@property (nonatomic, retain) NSData * image;
@property (nonatomic, retain) NSNumber * isFile;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * path;
@property (nonatomic, retain) NSNumber * size;
@property (nonatomic, retain) NSSet *childs;
@property (nonatomic, retain) Node *parent;
@property (nonatomic, retain) MetaInfo *info;
@end

@interface Node (CoreDataGeneratedAccessors)

- (void)addChildsObject:(Node *)value;
- (void)removeChildsObject:(Node *)value;
- (void)addChilds:(NSSet *)values;
- (void)removeChilds:(NSSet *)values;

@end
