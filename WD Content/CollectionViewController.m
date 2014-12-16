//
//  ViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 29.11.13.
//  Copyright (c) 2013 Sergey Seitov. All rights reserved.
//

#import "CollectionViewController.h"
#import "Cell.h"
#import "InfoViewController.h"
#import "DataModel.h"
#import "MBProgressHUD.h"
#import "SharesTableViewController.h"
#import "SearchInfoTableViewController.h"

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface CollectionViewController ()<SharesTableViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSArray* nodes;
@property (nonatomic) int errorCount;

@end

@implementation CollectionViewController

- (void)awakeFromNib
{
	BOOL isTable = [[NSUserDefaults standardUserDefaults] boolForKey:@"TableMode"];
	if (isTable) {
		_viewMode = Table;
	} else {
		_viewMode = Collection;
	}
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateInfoNotification:)
												 name:UpdateInfoNotification
											   object:nil];
	
	_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
	
	UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
	[btn setImage:[UIImage imageNamed:@"refresh.png"] forState:UIControlStateNormal];
	[btn addTarget:self action:@selector(updateData) forControlEvents:UIControlEventTouchDown];
	UIBarButtonItem* refresh = [[UIBarButtonItem alloc] initWithCustomView:btn];
	
	btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
	if (_viewMode == Collection) {
		[btn setImage:[UIImage imageNamed:@"list.png"] forState:UIControlStateNormal];
		_tableView.alpha = 0;
	} else {
		[btn setImage:[UIImage imageNamed:@"collection.png"] forState:UIControlStateNormal];
		_collectionView.alpha = 0;
	}
	[btn addTarget:self action:@selector(switchMode:) forControlEvents:UIControlEventTouchDown];
	UIBarButtonItem* compose = [[UIBarButtonItem alloc] initWithCustomView:btn];
	
	NSArray* items = @[compose, refresh];
	
	[self.navigationItem setRightBarButtonItems:items];
	if (_rootNode == nil) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(selectShares)];
	}
	if (!_rootNode) {
		self.title = @"WD Content";
	} else {
		self.title = _rootNode.name;
	}
}

- (void)switchMode:(UIButton*)sender
{
	[UIView animateWithDuration:.3f animations:^{
		if (_viewMode == Collection) {
			_viewMode = Table;
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TableMode"];
			[sender setImage:[UIImage imageNamed:@"collection.png"] forState:UIControlStateNormal];
			_collectionView.alpha = 0;
			_tableView.alpha = 1;
		} else {
			_viewMode = Collection;
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"TableMode"];
			[sender setImage:[UIImage imageNamed:@"list.png"] forState:UIControlStateNormal];
			_collectionView.alpha = 1;
			_tableView.alpha = 0;
		}
		[[NSUserDefaults standardUserDefaults] synchronize];
	}];
}

-(void)didUpdateInfoNotification:(NSNotification*)notification
{
	Node* target = (Node*)notification.object;
	for (Node* node in _nodes) {
		if ([node.path isEqual:target.path]) {
			_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
			[_collectionView reloadData];
			[_tableView reloadData];
			break;
		}
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (_nodes.count == 0) {
		[self updateData];
	}
}

NSString* hostFromPath(NSString *path)
{
	NSRange startRange = [path rangeOfString:@"smb://"];
	NSRange finishRange = {startRange.length, path.length-startRange.length};
	finishRange = [path rangeOfString:@"/" options:NSCaseInsensitiveSearch range:finishRange];
	if (finishRange.location != NSNotFound) {
		NSRange resultRange = {startRange.length, finishRange.location-startRange.length};
		return [path substringWithRange:resultRange];
	} else {
		NSRange resultRange = {startRange.length, path.length-startRange.length};
		return [path substringWithRange:resultRange];
	}
}

- (void)selectShares
{
	SharesTableViewController* shares = [[SharesTableViewController alloc] initWithDelegate:self];
	UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:shares];
	nav.navigationBar.barStyle = UIBarStyleBlack;
	nav.modalPresentationStyle = UIModalPresentationFormSheet;
	[self presentViewController:nav animated:YES completion:^(){}];
}

- (void)didSelectShares:(NSArray*)nodes
{
	for (NSDictionary* node in nodes) {
		KxSMBItem* item = [node objectForKey:@"item"];
		if ([[node objectForKey:@"checked"] boolValue]) {
			NSLog(@"%@ checked", item.path);
			if (![[self hasNodeWithPath:item.path] boolValue]) {
				[[DataModel sharedInstance] newNodeForItem:item withParent:nil];
			}
		} else {
			Node* node = [self nodeWithPath:item.path];
			if (node) {
				[[DataModel sharedInstance] deleteNode:node];
			}
		}
	}
	_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
	[_collectionView reloadData];
	[_tableView reloadData];
}

- (Node*)nodeWithPath:(NSString*)path
{
	for (Node* node in _nodes) {
		if ([node.path isEqual:path]) {
			return node;
		}
	}
	return nil;
}

- (NSNumber*)hasNodeWithPath:(NSString*)path
{
	if ([self nodeWithPath:path]) {
		return [NSNumber numberWithBool:YES];
	} else {
		return [NSNumber numberWithBool:NO];
	}
}

- (void)updateData
{
	if (!_rootNode) {
		NSMutableSet* authHosts = [NSMutableSet setWithArray:[DataModel auth].allKeys];
		for (int i=0; i<_nodes.count; i++) {
			Node* node = [_nodes objectAtIndex:i];
			NSString* host = hostFromPath(node.path);
			if (![authHosts containsObject:host]) {
				[[DataModel sharedInstance] deleteNode:node];
			}
		}
		_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
		[_collectionView reloadData];
		[_tableView reloadData];
		
		NSMutableSet* nodesHosts = [NSMutableSet new];
		for (Node* node in _nodes) {
			NSString* path = hostFromPath(node.path);
			if (path) {
				[nodesHosts addObject:path];
			}
		}
		[authHosts minusSet:nodesHosts];
		if (authHosts.count > 0) {
			[self addHosts:authHosts.allObjects];
		} else {
			[_collectionView reloadData];
			[_tableView reloadData];
		}
	} else {
		_errorCount = 0;
		[self addNodesForRoot];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex) {
		switch (alertView.tag) {
			case 1:
				[self updateData];
				break;
			case 2:
				_errorCount = 0;
				[self addNodesForRoot];
				break;
			default:
				break;
		}
	}
}

- (void)addHosts:(NSArray*)hosts
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
		for (NSString* host in hosts) {
			id result = [[DataModel sharedInstance].provider fetchAtPath:[NSString stringWithFormat:@"smb://%@", host]];
			if ([result isKindOfClass:[NSError class]]) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[MBProgressHUD hideHUDForView:self.view animated:YES];
					UIAlertView* alert = [[UIAlertView alloc] initWithTitle:_rootNode.path
																	message:@"Error connect. Retry?"
																   delegate:self
														  cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
					alert.tag = 1;
					[alert show];
				});
				return;
			} else {
				if ([result isKindOfClass:[NSArray class]]) {
					for (KxSMBItem* item in result) {
						[[DataModel sharedInstance] newNodeForItem:item withParent:nil];
					}
				} else if ([result isKindOfClass:[KxSMBItem class]]) {
					KxSMBItem* item = (KxSMBItem*)result;
					[[DataModel sharedInstance] newNodeForItem:item withParent:nil];
				}
			}
		}
		_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			[self.collectionView reloadData];
		});
	});
}

- (void)addNodesForRoot
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
		NSMutableArray* newItems = [NSMutableArray new];
		id result = [[DataModel sharedInstance].provider fetchAtPath:_rootNode.path];
		if ([result isKindOfClass:[NSError class]]) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[MBProgressHUD hideHUDForView:self.view animated:YES];
				if (_errorCount < 3) {
					_errorCount++;
					[self addNodesForRoot];
				} else {
					UIAlertView* alert = [[UIAlertView alloc] initWithTitle:_rootNode.path
																	message:@"Error connect. Retry?"
																   delegate:self
														  cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
					alert.tag = 2;
					[alert show];
				}
			});
			return;
		} else {
			if ([result isKindOfClass:[NSArray class]]) {
				for (KxSMBItem* item in result) {
					[self addItem:item toList:newItems];
				}
			} else if ([result isKindOfClass:[KxSMBItem class]]) {
				[self addItem:result toList:newItems];
			}
		}
		// add new nodes
		for (KxSMBItem* item in newItems) {
			if (![self nodeWithPath:item.path]) {
				[[DataModel sharedInstance] newNodeForItem:item withParent:_rootNode];
			}
		}
		// remove deleted
		NSArray* paths = [newItems valueForKeyPath:@"path"];
		for (Node* node in _nodes) {
			if (![paths containsObject:node.path]) {
				[[DataModel sharedInstance] deleteNode:node];
			}
		}
		_nodes = [[DataModel sharedInstance] nodesByRoot:_rootNode];
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			[_collectionView reloadData];
			[_tableView reloadData];
		});
	});
}

-(void)addItem:(KxSMBItem*)item toList:(NSMutableArray*)list
{
	if ([item isKindOfClass:[KxSMBItemFile class]]) {
		NSArray* movieExtensions = @[@"mkv", @"avi", @"iso", @"ts", @"mov", @"m4v", @"mpg", @"mpeg", @"wmv", @"mp4"];
		if ([movieExtensions containsObject:item.path.pathExtension]) {
			[list addObject:item];
		}
	} else {
		[list addObject:item];
	}
}

#pragma mark - Collection View Data Sources

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return _nodes.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    Cell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"my_cell" forIndexPath:indexPath];
	Node *node = [_nodes objectAtIndex:indexPath.row];
	if (node.info && node.info.thumbnail) {
		cell.image.image = [UIImage imageWithData:node.info.thumbnail];
	} else {
		cell.image.image = [UIImage imageWithData:node.image];
	}
	cell.title.text = node.name;
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	Node* node = [_nodes objectAtIndex:indexPath.row];
	[self selectNode:node];
}

- (void)selectNode:(Node*)node
{
	if ([node.isFile boolValue] == NO) {
		UIStoryboard* storyboard = IS_PAD ? [UIStoryboard storyboardWithName:@"Main_iPad" bundle:nil] : [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
		CollectionViewController *next = [storyboard instantiateViewControllerWithIdentifier:@"CollectionViewController"];
		next.rootNode = node;
		next.viewMode = _viewMode;
		[self.navigationController pushViewController:next animated:YES];
	}
	else {
		if (node.info) {
			InfoViewController *next = [[InfoViewController alloc] initWithMetaInfo:node.info forNode:node];
			UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:next];
			nav.navigationBar.barStyle = UIBarStyleBlack;
			nav.modalPresentationStyle = UIModalPresentationFormSheet;
			nav.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
			[self presentViewController:nav animated:YES completion:^(){}];
		} else {
			UIStoryboard* storyboard = IS_PAD ? [UIStoryboard storyboardWithName:@"Main_iPad" bundle:nil] : [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
			SearchInfoTableViewController *search = [storyboard instantiateViewControllerWithIdentifier:@"SearchInfoController"];
			search.node = node;
			UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:search];
			nav.navigationBar.barStyle = UIBarStyleBlack;
			nav.modalPresentationStyle = UIModalPresentationFormSheet;
			nav.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
			[self presentViewController:nav animated:YES completion:^(){}];
		}
	}
}

#pragma mark - UITableView delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return _nodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
	Node *node = [_nodes objectAtIndex:indexPath.row];
	cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
	if (node.info && node.info.thumbnail) {
		cell.imageView.image = [UIImage imageWithData:node.info.thumbnail];
	} else {
		cell.imageView.image = [UIImage imageWithData:node.image];
	}
	cell.backgroundColor = [UIColor blackColor];
	cell.contentView.backgroundColor = [UIColor blackColor];
	cell.textLabel.textColor = [UIColor whiteColor];
	cell.detailTextLabel.textColor = [UIColor whiteColor];
	cell.textLabel.numberOfLines = 0;
	cell.textLabel.text = node.name;
	if ([node.isFile boolValue] == NO) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:17];
	} else {
		cell.accessoryType = UITableViewCellAccessoryDetailButton;
		cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:14];
		if (node.info) {
			cell.detailTextLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
			cell.detailTextLabel.text = node.info.release_date;
		}
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Node* node = [_nodes objectAtIndex:indexPath.row];
	[self selectNode:node];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	Node* node = [_nodes objectAtIndex:indexPath.row];
	[self selectNode:node];
}

@end
