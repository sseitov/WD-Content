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
#import "MetaInfo.h"
#import "Node.h"

#ifndef TV
	#import "KxSMBProvider.h"
#endif

extern NSString * const DataModelDidChangeNotification;

@class Node;

@interface DataModel : NSObject {
}

@property (nonatomic, readonly, retain) NSManagedObjectModel *objectModel;
@property (nonatomic, readonly, retain) NSManagedObjectContext *mainObjectContext;
@property (nonatomic, readonly, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;

#ifndef TV
@property (strong, nonatomic) KxSMBProvider* provider;
#endif

+ (DataModel*)sharedInstance;

- (BOOL)save;
- (void)updateDB;

- (NSManagedObjectContext*)managedObjectContext;

- (Node*)nodeByPath:(NSString*)path;
- (NSArray*)nodesByRoot:(Node*)root;

#ifndef TV
- (Node*)newNodeForItem:(KxSMBItem*)item withParent:(Node*)parent;
#endif
- (void)deleteNode:(Node*)node;
- (void)addInfo:(NSDictionary*)info forNode:(Node*)node;
- (void)clearInfoForNode:(Node*)node;

+ (NSDate*)lastModified;
+ (void)setLastModified:(NSDate*)date;
+ (NSDate*)lastAuthModified;
+ (void)setLastAuthModified:(NSDate*)date;

+ (void)convertAuth;

+ (NSArray*)auth;
+ (void)setAuth:(NSArray*)authArray;
+ (void)removeHost:(NSDictionary*)host;
+ (void)setHost:(NSMutableDictionary*)host;
+ (NSDictionary*)authForHost:(NSString*)server;

+ (NSIndexPath*)lastIndex;
+ (void)setLastIndex:(NSIndexPath*)index;

+ (NSString*)authPath;
+ (NSString*)contentPath;

@end
