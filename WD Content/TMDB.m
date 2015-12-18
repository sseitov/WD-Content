//
//  TMDB.m
//  WD Content
//
//  Created by Сергей Сейтов on 17.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "TMDB.h"
#import <AFNetworking/AFSecurityPolicy.h>

#pragma mark - API URLs

NSString * const kMovieDBBaseURL = @"http://api.themoviedb.org/3/";
NSString * const kMovieDBBaseURLSSL = @"https://api.themoviedb.org/3/";

#pragma mark - Configuration

NSString * const kMovieDBConfiguration = @"configuration";

#pragma mark - Movies

NSString * const kMovieDBMovie = @"movie/:id";
NSString * const kMovieDBMovieAlternativeTitles = @"movie/:id/alternative_titles";
NSString * const kMovieDBMovieCredits = @"movie/:id/credits";
NSString * const kMovieDBMovieImages = @"movie/:id/images";
NSString * const kMovieDBMovieKeywords = @"movie/:id/keywords";
NSString * const kMovieDBMovieReleases = @"movie/:id/releases";
NSString * const kMovieDBMovieTrailers = @"movie/:id/trailers";
NSString * const kMovieDBMovieTranslations = @"movie/:id/translations";
NSString * const kMovieDBMovieSimilarMovies = @"movie/:id/similar_movies";
NSString * const kMovieDBMovieReviews = @"movie/:id/reviews";
NSString * const kMovieDBMovieLists = @"movie/:id/lists";
NSString * const kMovieDBMovieChanges = @"movie/:id/changes";

NSString * const kMovieDBMovieLatest = @"movie/latest";
NSString * const kMovieDBMovieUpcoming = @"movie/upcoming";
NSString * const kMovieDBMovieTheatres = @"movie/now_playing";
NSString * const kMovieDBMoviePopular = @"movie/popular";
NSString * const kMovieDBMovieTopRated = @"movie/top_rated";

#pragma mark - Genres

NSString * const kMovieDBGenreList = @"genre/list";
NSString * const kMovieDBGenreMovies = @"genre/:id/movies";

#pragma mark - Collections

NSString * const kMovieDBCollection = @"collection/:id";
NSString * const kMovieDBCollectionImages = @"collection/:id/images";

#pragma mark - Search

NSString * const kMovieDBSearchMovie = @"search/movie";
NSString * const kMovieDBSearchPerson = @"search/person";
NSString * const kMovieDBSearchCollection = @"search/collection";
NSString * const kMovieDBSearchList = @"search/list";
NSString * const kMovieDBSearchCompany = @"search/company";
NSString * const kMovieDBSearchKeyword = @"search/keyword";

#pragma mark - People

NSString * const kMovieDBPeople = @"person/:id";
NSString * const kMovieDBPeopleMovieCredits = @"person/:id/movie_credits";
NSString * const kMovieDBPeopleImages = @"person/:id/images";
NSString * const kMovieDBPeopleChanges = @"person/:id/changes";
NSString * const kMovieDBPeoplePopular = @"person/popular";
NSString * const kMovieDBPeopleLatest = @"person/latest";

#pragma mark - Lists

NSString * const kMovieDBList = @"list/:id";
NSString * const kMovieDBListItemStatus = @"list/:id/item_status";

#pragma mark - Companies

NSString * const kMovieDBCompany = @"company/:id";
NSString * const kMovieDBCompanyMovies = @"company/:id/movies";

#pragma mark - Keywords

NSString * const kMovieDBKeyword = @"keyword/:id";
NSString * const kMovieDBKeywordMovies = @"keyword/:id/movies";

#pragma mark - Discover

NSString * const kMovieDBDiscover = @"discover/movie";

#pragma mark - Reviews

NSString * const kMovieDBReview = @"review/:id";

#pragma mark - Changes

NSString * const kMovieDBChangesMovie = @"movie/changes";
NSString * const kMovieDBChangesPerson = @"person/changes";

#pragma mark - Jobs

NSString * const kMovieDBJobList = @"job/list";

#pragma TMDB implementation

@implementation TMDB

+ (TMDB*)sharedInstance
{
	static dispatch_once_t pred;
	static TMDB *sharedInstance = nil;
	
	dispatch_once(&pred, ^{
		sharedInstance = [[self alloc] initWithBaseURL:[NSURL URLWithString:kMovieDBBaseURLSSL]];
		AFSecurityPolicy* policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
		policy.allowInvalidCertificates = YES;
		policy.validatesDomainName = NO;
		sharedInstance.securityPolicy = policy;
		sharedInstance.requestSerializer = [AFJSONRequestSerializer new];
	});
	return sharedInstance;
}

- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters block:(TMDBResponseBlock)block
{
    NSParameterAssert(self.apiKey);
    NSParameterAssert(block);
	
	NSMutableDictionary *params = parameters ? [parameters mutableCopy] : [NSMutableDictionary new];
	params[@"api_key"] = self.apiKey;
	params[@"language"] = [[NSLocale autoupdatingCurrentLocale] objectForKey: NSLocaleLanguageCode];

	if ([path rangeOfString:@":id"].location != NSNotFound) {
		NSParameterAssert(parameters[@"id"]);
		path = [path stringByReplacingOccurrencesOfString:@":id" withString:parameters[@"id"]];
	}

	[self GET:path parameters:params progress:nil success:^(NSURLSessionTask *task, id responseObject) {
		block(responseObject, nil);
	} failure:^(NSURLSessionTask *operation, NSError *error) {
		block(nil, error);
	}];
}

@end
