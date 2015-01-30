//
//  DataModel.m
//  WD Content
//
//  Created by Sergey Seitov on 09.01.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "DataModel.h"
#import "Node.h"
#include <mutex>

NSString* const DataModelDidChangeNotification = @"DataModelDidChangeNotification";

@interface DataModel () <KxSMBProviderDelegate> {
	
	std::mutex _mutex;
}

@end

@implementation DataModel

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize mainObjectContext = _mainObjectContext;
@synthesize objectModel = _objectModel;

NSString * const kDataManagerModelName = @"ContentModel";
NSString * const kDataManagerSQLiteName = @"ContentModel.sqlite";
NSString * const kDataManagerAuthName = @"Auth.plist";

+ (DataModel*)sharedInstance
{
	static dispatch_once_t pred;
	static DataModel *sharedInstance = nil;
	
	dispatch_once(&pred, ^{ sharedInstance = [[self alloc] init]; });
	return sharedInstance;
}

- (id)init
{
	self = [super init];
	if (self) {
		_provider = [KxSMBProvider sharedSmbProvider];
		_provider.delegate = self;
	}
	return self;
}

- (void)dealloc
{
	[self save];
}

- (NSManagedObjectModel*)objectModel
{
	if (_objectModel)
		return _objectModel;
	
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *modelPath = [bundle pathForResource:kDataManagerModelName ofType:@"momd"];
	_objectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:modelPath]];
	
	return _objectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
	if (_persistentStoreCoordinator)
		return _persistentStoreCoordinator;
	
	// Get the paths to the SQLite file
	NSString *storePath = [[DataModel sharedDocumentsPath] stringByAppendingPathComponent:kDataManagerSQLiteName];
	NSURL *storeURL = [NSURL fileURLWithPath:storePath];
	
	// Define the Core Data version migration options
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 @{@"journal_mode":@"DELETE"}, NSSQLitePragmasOption,
//							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
//							 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
							 nil];
	
	// Attempt to load the persistent store
	NSError *error = nil;
	_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.objectModel];
	if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
												   configuration:nil
															 URL:storeURL
														 options:options
														   error:&error]) {
		NSLog(@"Remove previouse store");
		[[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
		if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
													   configuration:nil
																 URL:storeURL
															 options:options
															   error:&error]) {
			NSLog(@"Fatal error while creating persistent store: %@", error);
			abort();
		}
	}
	
	return _persistentStoreCoordinator;
}

- (NSManagedObjectContext*)mainObjectContext
{
	if (_mainObjectContext)
		return _mainObjectContext;
	
	// Create the main context only on the main thread
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(mainObjectContext)
							   withObject:nil
							waitUntilDone:YES];
		return _mainObjectContext;
	}
	
	_mainObjectContext = [[NSManagedObjectContext alloc] init];
	[_mainObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
	
	return _mainObjectContext;
}

- (BOOL)save
{
	std::unique_lock<std::mutex> lock(_mutex);
	
	if (![self.mainObjectContext hasChanges]) {
		NSLog(@"data not changed");
		return YES;
	}
	
	NSError *error = nil;
	if (![self.mainObjectContext save:&error]) {
		NSLog(@"Error while saving: %@\n%@", [error localizedDescription], [error userInfo]);
		return NO;
	} else {
		[_mainObjectContext processPendingChanges];
		[DataModel setLastModified:[NSDate date]];
		return YES;
	}
}

- (void)updateDB
{
	_mainObjectContext = nil;
	_persistentStoreCoordinator = nil;
	[self mainObjectContext];
}

- (NSManagedObjectContext*)managedObjectContext
{
	NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] init];
	[ctx setPersistentStoreCoordinator:self.persistentStoreCoordinator];
	
	return ctx;
}

#pragma mark - fetch methods

- (id)fetchObjectFromEntity:(NSString *)entity withPredicate:(NSPredicate *)predicate
{
	if (!_mainObjectContext) {
		_mainObjectContext = [self managedObjectContext];
	}
    
	//Set up to get the object you want to fetch
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:[NSEntityDescription entityForName:entity inManagedObjectContext:_mainObjectContext]];
	[request setPredicate:predicate];
	
	NSError *error = nil;
	id object = [[_mainObjectContext executeFetchRequest:request error:&error] lastObject];
	if (error) {
		NSLog(@"ERROR (fetchObjectFromEntity): %@", error);
		return nil;
	} else {
		return object;
	}
}

- (id)fetchObjectsFromEntity:(NSString *)entity withPredicate:(NSPredicate *)predicate withSortDescriptors:(NSArray *)sortDescriptors
{
	if (!_mainObjectContext) {
		_mainObjectContext = [self managedObjectContext];
	}
    
	//Set up to get the object you want to fetch
	NSFetchRequest * request = [[NSFetchRequest alloc] init];
	[request setEntity:[NSEntityDescription entityForName:entity inManagedObjectContext:_mainObjectContext]];
	[request setPredicate:predicate];
	[request setSortDescriptors:sortDescriptors];
    
    
	NSError *error = nil;
	id objects = [_mainObjectContext executeFetchRequest:request error:&error];
	if (error) {
		NSLog(@"ERROR (fetchObjectsFromEntity): %@", error);
		return nil;
	} else {
		return objects;
	}
}

- (Node*)nodeByPath:(NSString*)path
{
	return [self fetchObjectFromEntity:@"Node" withPredicate:[NSPredicate predicateWithFormat:@"path == %@", path]];
}

- (NSArray*)nodesByRoot:(Node*)root
{
	return [self fetchObjectsFromEntity:@"Node"
						  withPredicate:[NSPredicate predicateWithFormat:@"parent = %@", root]
					withSortDescriptors:[NSArray arrayWithObjects:
										 [NSSortDescriptor sortDescriptorWithKey:@"isFile" ascending:YES],
										 [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES],
										 nil] ];
}

#pragma mark - update methods

- (Node*)newNodeForItem:(KxSMBItem*)item withParent:(Node*)parent
{
	Node *node = [self nodeByPath:item.path];
	if (!node) {
		node = (Node*)[NSEntityDescription insertNewObjectForEntityForName: @"Node" inManagedObjectContext: _mainObjectContext];
	}
	
	node.path = item.path;
	node.parent = parent;
	if (parent) {
		[parent addChildsObject:node];
	}
	node.isFile = [NSNumber numberWithBool:[item isKindOfClass:[KxSMBItemFile class]]];
	node.name = [[item.path lastPathComponent] stringByDeletingPathExtension];
	node.info = nil;
	if ([node.isFile boolValue]) {
		node.size = [NSNumber numberWithLongLong:item.stat.size];
		node.image = UIImagePNGRepresentation([UIImage imageNamed:@"FileIcon"]);
	} else {
		node.size = 0;
		node.image = UIImagePNGRepresentation([UIImage imageNamed:@"FolderIcon"]);
	}
	
	//Save result in database
	if (![self save]) {
		NSLog(@"ERROR (newNode)");
	} else {
		[_mainObjectContext refreshObject:node mergeChanges:YES];
	}
 	return node;
}

- (void)deleteNode:(Node*)node
{
	if (node.info) {
		[_mainObjectContext deleteObject:node.info];
	}
	[_mainObjectContext deleteObject:node];
	
	// Save result in the database
	if (![self save]) {
		NSLog(@"ERROR (deleteNode)");
	}
}

- (void)addInfo:(NSDictionary*)info forNode:(Node*)node
{
	node.info = (MetaInfo*)[NSEntityDescription insertNewObjectForEntityForName: @"MetaInfo" inManagedObjectContext: _mainObjectContext];
	node.info.cast = [info objectForKey:@"cast"];
	node.info.director = [info objectForKey:@"director"];
	node.info.genre = [info objectForKey:@"genre"];
	node.info.overview = [info objectForKey:@"overview"];
	node.info.runtime = [info objectForKey:@"runtime"];
	node.info.thumbnail = [info objectForKey:@"thumbnail"];
	node.info.title = [info objectForKey:@"title"];
	node.info.original_title = [info objectForKey:@"original_title"];
	node.info.release_date = [info objectForKey:@"release_date"];
	
	//Save result in database
	if (![self save]) {
		NSLog(@"ERROR (addInfo)");
	} else {
		[_mainObjectContext refreshObject:node mergeChanges:YES];
	}
}

- (void)clearInfoForNode:(Node*)node
{
	if (node.info) {
		[_mainObjectContext deleteObject:node.info];
	}
	node.info = nil;
	
	//Save result in database
	if (![self save]) {
		NSLog(@"ERROR (clearInfoForNode)");
	} else {
		[_mainObjectContext refreshObject:node mergeChanges:YES];
	}
}

#pragma mark - user settings storage

+ (NSString*)sharedDocumentsPath
{
	static NSString *SharedDocumentsPath = nil;
	if (SharedDocumentsPath)
		return SharedDocumentsPath;
	
	// Compose a path to the <Library>/Database directory
	NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	SharedDocumentsPath = [libraryPath stringByAppendingPathComponent:@"ContentModel"];
	
	// Ensure the database directory exists
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDirectory;
	if (![manager fileExistsAtPath:SharedDocumentsPath isDirectory:&isDirectory] || !isDirectory) {
		NSError *error = nil;
		NSDictionary *attr = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
														 forKey:NSFileProtectionKey];
		[manager createDirectoryAtPath:SharedDocumentsPath
		   withIntermediateDirectories:YES
							attributes:attr
								 error:&error];
		if (error)
			NSLog(@"Error creating directory path: %@", [error localizedDescription]);
	}
	
	return SharedDocumentsPath;
}

+ (NSString*)authPath
{
	return [[DataModel sharedDocumentsPath] stringByAppendingPathComponent:kDataManagerAuthName];
}

+ (NSString*)contentPath
{
	return [[DataModel sharedDocumentsPath] stringByAppendingPathComponent:kDataManagerSQLiteName];
}

+ (NSDate*)lastModified
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"lastModified"];
}

+ (void)setLastModified:(NSDate*)date
{
	[[NSUserDefaults standardUserDefaults] setObject:date forKey:@"lastModified"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSDate*)lastAuthModified
{
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[DataModel authPath] error:nil];
	return [attributes fileModificationDate];
}

+ (void)setLastAuthModified:(NSDate*)date
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDictionary *creationDateAttr = [NSDictionary dictionaryWithObjectsAndKeys: date, NSFileCreationDate, nil];
	NSDictionary *modificationDateAttr = [NSDictionary dictionaryWithObjectsAndKeys: date, NSFileModificationDate, nil];
	NSError* err = nil;
	[fileManager setAttributes:modificationDateAttr ofItemAtPath:[DataModel authPath] error:&err];
	[fileManager setAttributes:creationDateAttr ofItemAtPath:[DataModel authPath] error:&err];
}

+ (void)convertAuth
{
	NSMutableArray* newAuth = [NSMutableArray new];
	NSDictionary *oldAuth = [[NSUserDefaults standardUserDefaults] objectForKey:@"auth"];
	for (NSString *h in oldAuth.allKeys) {
		NSMutableDictionary *host = [NSMutableDictionary dictionaryWithDictionary:[oldAuth objectForKey:h]];
		[host setObject:h forKey:@"host"];
		[host setObject:[NSNumber numberWithBool:YES] forKey:@"validated"];
		[newAuth addObject:host];
	}
	[DataModel setAuth:newAuth];
}

+ (NSArray*)auth
{
	return [NSArray arrayWithContentsOfFile:[DataModel authPath]];
}

+ (void)setAuth:(NSArray*)authArray
{
	[authArray writeToFile:[DataModel authPath] atomically:YES];
}

+ (void)removeHost:(NSDictionary*)host
{
	NSMutableArray* allHosts = [NSMutableArray arrayWithArray:[DataModel auth]];
	for (NSDictionary* h in allHosts) {
		if ([[h objectForKey:@"host"] isEqual:[host objectForKey:@"host"]]) {
			for (NSString* folder in [host objectForKey:@"folders"]) {
				Node* node = [[DataModel sharedInstance] nodeByPath:folder];
				if (node) {
					[[DataModel sharedInstance] deleteNode:node];
				}
			}
			[allHosts removeObject:h];
			break;
		}
	}
	[DataModel setAuth:allHosts];
}

+ (void)setHost:(NSMutableDictionary*)host
{
	NSMutableArray* allHosts = [NSMutableArray arrayWithArray:[DataModel auth]];
	for (NSInteger index=0; index<allHosts.count; index++) {
		NSDictionary* h = [allHosts objectAtIndex:index];
		if ([[h objectForKey:@"host"] isEqual:[host objectForKey:@"host"]]) {
			[host setObject:[NSNumber numberWithBool:YES] forKey:@"validated"];
			[allHosts replaceObjectAtIndex:index withObject:host];
			break;
		}
	}
	[DataModel setAuth:allHosts];
}

+ (NSIndexPath*)lastIndex
{
	NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"initialIndex"];
	if (index > 0) {
		return [NSIndexPath indexPathForRow:(index-1) inSection:1];
	} else {
		return [NSIndexPath indexPathForRow:0 inSection:0];
	}
}

+ (void)setLastIndex:(NSIndexPath*)index
{
	if (index) {
		if (index.section) {
			[[NSUserDefaults standardUserDefaults] setInteger:(index.row + 1) forKey:@"initialIndex"];
		} else {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"initialIndex"];
		}
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

+ (NSDictionary*)authForHost:(NSString*)server
{
	NSArray *auth = [DataModel auth];
	for (NSDictionary *host in auth) {
		if ([[host objectForKey:@"host"] isEqual:server]) {
			return host;
		}
	}
	return nil;
}

#pragma mark - KxSmbProvider delegate

- (KxSMBAuth *)smbAuthForServer:(NSString*)server withShare:(NSString*)share
{
	NSArray *auth = [DataModel auth];
	for (NSDictionary *host in auth) {
		if ([[host objectForKey:@"host"] isEqual:server]) {
			return [KxSMBAuth smbAuthWorkgroup:[host valueForKey:@"workgroup"]
									  username:[host valueForKey:@"user"]
									  password:[host valueForKey:@"password"]];
		}
	}
	return nil;
}

@end
