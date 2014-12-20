//
//  DataModel.h
//  WD Content
//
//  Created by Sergey Seitov on 09.01.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "KxSMBProvider.h"
#import "MetaInfo.h"
#import "Node.h"

extern NSString * const DataModelDidChangeNotification;

@class Node;

@interface DataModel : NSObject {
}

@property (nonatomic, readonly, retain) NSManagedObjectModel *objectModel;
@property (nonatomic, readonly, retain) NSManagedObjectContext *mainObjectContext;
@property (nonatomic, readonly, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong, nonatomic) KxSMBProvider* provider;

+ (DataModel*)sharedInstance;

- (BOOL)save;
- (NSManagedObjectContext*)managedObjectContext;

- (NSString*)sharedDocumentsPath;
- (BOOL)updateDBFile:(NSData*)data;
- (NSDate*)lastModified;

- (Node*)nodeByPath:(NSString*)path;
- (NSArray*)nodesByRoot:(Node*)root;

- (Node*)newNodeForItem:(KxSMBItem*)item withParent:(Node*)parent;
- (void)deleteNode:(Node*)node;
- (void)addInfo:(NSDictionary*)info forNode:(Node*)node;
- (void)clearInfoForNode:(Node*)node;

- (KxSMBProvider*)provider;

+ (NSArray*)auth;
+ (void)setAuth:(NSArray*)authArray;
+ (void)removeHost:(NSDictionary*)host;
+ (void)setHost:(NSMutableDictionary*)host;

+ (NSIndexPath*)lastIndex;
+ (void)setLastIndex:(NSIndexPath*)index;

@end
