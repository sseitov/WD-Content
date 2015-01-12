//
//  SearchInfoTableViewController.m
//  WD Content
//
//  Created by Sergey Seitov on 20.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "SearchInfoTableViewController.h"
#import "TMDB.h"
#import "MBProgressHUD.h"
#import "InfoViewController.h"

@interface SearchInfoTableViewController () <UISearchBarDelegate>

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) NSMutableArray* searchResults;
@property (nonatomic, copy) NSString *imagesBaseUrlString;

@end

@implementation SearchInfoTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Search Info";
	self.clearsSelectionOnViewWillAppear = NO;
	
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
	self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
	_searchBar.text = _node.name;
	_searchResults = [[NSMutableArray alloc] init];
	
	__weak SearchInfoTableViewController *weakSelf = self;
	[[TMDB sharedInstance] GET:kMovieDBConfiguration parameters:nil block:^(id responseObject, NSError *error) {
		if (!error) {
			weakSelf.imagesBaseUrlString = [responseObject[@"images"][@"base_url"] stringByAppendingString:@"w185"];
			[weakSelf searchBarSearchButtonClicked:_searchBar];
		}
	}];


}

- (void)cancel
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (_searchResults.count > 0) {
		return _searchResults.count;
	} else {
		return 1;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
	}
	if (indexPath.row >= _searchResults.count) {
		cell.textLabel.text = @"No results";
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		NSDictionary* movie = [_searchResults objectAtIndex:indexPath.row];
		cell.textLabel.text = [movie objectForKey:@"title"];
		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.text = [movie objectForKey:@"release_date"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		if (movie[@"poster"] != [NSNull null]) {
			cell.imageView.contentMode = UIViewContentModeScaleToFill;
			cell.imageView.image = [UIImage imageWithData:movie[@"thumbnail"]];
		}
	}
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row < _searchResults.count) {
		NSDictionary* result = [_searchResults objectAtIndex:indexPath.row];
		[self performSegueWithIdentifier:@"Info" sender:result];
	}
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"Info"])
	{
		InfoViewController *vc = [segue destinationViewController];
		[vc setInfo:sender forNode:_node];
	}
}

#pragma mark - UISearchBar delegate

- (void)getInfoForMoview:(NSMutableDictionary*)mutableMovie
{
	NSNumber* moviewId = [mutableMovie objectForKey:@"id"];
	NSDictionary *params = @{@"id": [moviewId stringValue]};
	[[TMDB sharedInstance] GET:kMovieDBMovie parameters:params
						 block:^(id responseObject, NSError *error) {
							 if (error) {
								 NSLog(@"ERROR: %@", error);
							 } else {
								 id runtime = [responseObject objectForKey:@"runtime"];
								 if (runtime) {
									 [mutableMovie setObject:runtime forKey:@"runtime"];
								 }
								 id overview = [responseObject objectForKey:@"overview"];
								 if (overview) {
									 [mutableMovie setObject:overview forKey:@"overview"];
								 }
								 NSArray* genres = [[responseObject objectForKey:@"genres"] valueForKey:@"name"];
								 if (genres && genres.count > 0) {
									 [mutableMovie setObject:[genres componentsJoinedByString:@","] forKey:@"genre"];
								 }
							 }
							 [self getCreditsForMoview:mutableMovie];
						 }];
}

- (void)getCreditsForMoview:(NSMutableDictionary*)mutableMovie
{
	NSNumber* moviewId = [mutableMovie objectForKey:@"id"];
	NSDictionary *params = @{@"id": [moviewId stringValue]};
	[[TMDB sharedInstance] GET:kMovieDBMovieCredits parameters:params
						 block:^(id responseObject, NSError *error) {
							 if (error) {
								 NSLog(@"ERROR: %@", error);
							 } else {
								 NSArray* cast = [[responseObject objectForKey:@"cast"] valueForKey:@"name"];
								 if (cast && cast.count > 0) {
									 [mutableMovie setObject:[cast componentsJoinedByString:@","] forKey:@"cast"];
								 }
								 NSArray* crew = [responseObject objectForKey:@"crew"];
								 for (NSDictionary* job in crew) {
									 if ([[job valueForKey:@"job"] isEqual:@"Director"]) {
										 [mutableMovie setObject:[job valueForKey:@"name"] forKey:@"director"];
										 break;
									 }
								 }
							 }
							 [self getPosterForMovie:mutableMovie];
						 }];
}

- (void)getPosterForMovie:(NSMutableDictionary*)mutableMovie
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
		id path = mutableMovie[@"poster_path"];
		if ([path isKindOfClass:[NSString class]]) {
			NSString *posterUrlString = [_imagesBaseUrlString stringByAppendingString:path];
			NSData* imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:posterUrlString]];
			if (imageData) {
				[mutableMovie setObject:imageData forKey:@"thumbnail"];
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[_searchBar resignFirstResponder];
			[self.tableView reloadData];
		});
	});
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	NSDictionary* params = @{@"query": searchBar.text};
	[MBProgressHUD showHUDAddedTo:self.tableView animated:YES];
	[[TMDB sharedInstance] GET:kMovieDBSearchMovie parameters:params block:^(id responseObject, NSError *error) {
		[MBProgressHUD hideHUDForView:self.tableView animated:YES];
		if (error) {
			NSLog(@"ERROR: %@", error);
		} else {
			[_searchResults removeAllObjects];
			for (NSDictionary* movie in [responseObject objectForKey:@"results"]) {
				NSMutableDictionary *mutableMovie = [NSMutableDictionary dictionaryWithDictionary:movie];
				[_searchResults addObject:mutableMovie];
				[self getInfoForMoview:mutableMovie];
			}
			[self.tableView reloadData];
		}
	}];
}

@end
