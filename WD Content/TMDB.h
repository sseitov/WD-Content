//
//  TMDB.h
//  WD Content
//
//  Created by Сергей Сейтов on 17.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFHTTPSessionManager.h>

#pragma mark - API URLs

extern NSString * const kMovieDBBaseURL;
extern NSString * const kMovieDBBaseURLSSL;

#pragma mark - Configuration

extern NSString * const kMovieDBConfiguration;

#pragma mark - Movies

extern NSString * const kMovieDBMovie;
extern NSString * const kMovieDBMovieAlternativeTitles;
extern NSString * const kMovieDBMovieCredits;
extern NSString * const kMovieDBMovieImages;
extern NSString * const kMovieDBMovieKeywords;
extern NSString * const kMovieDBMovieReleases;
extern NSString * const kMovieDBMovieTrailers;
extern NSString * const kMovieDBMovieTranslations;
extern NSString * const kMovieDBMovieSimilarMovies;
extern NSString * const kMovieDBMovieReviews;
extern NSString * const kMovieDBMovieLists;
extern NSString * const kMovieDBMovieChanges;

extern NSString * const kMovieDBMovieLatest;
extern NSString * const kMovieDBMovieUpcoming;
extern NSString * const kMovieDBMovieTheatres;
extern NSString * const kMovieDBMoviePopular;
extern NSString * const kMovieDBMovieTopRated;

#pragma mark - Genres

extern NSString * const kMovieDBGenreList;
extern NSString * const kMovieDBGenreMovies;

#pragma mark - Collections

extern NSString * const kMovieDBCollection;
extern NSString * const kMovieDBCollectionImages;

#pragma mark - Search

extern NSString * const kMovieDBSearchMovie;
extern NSString * const kMovieDBSearchPerson;
extern NSString * const kMovieDBSearchCollection;
extern NSString * const kMovieDBSearchList;
extern NSString * const kMovieDBSearchCompany;
extern NSString * const kMovieDBSearchKeyword;

#pragma mark - People

extern NSString * const kMovieDBPeople;
extern NSString * const kMovieDBPeopleMovieCredits;
extern NSString * const kMovieDBPeopleImages;
extern NSString * const kMovieDBPeopleChanges;
extern NSString * const kMovieDBPeoplePopular;
extern NSString * const kMovieDBPeopleLatest;

#pragma mark - Lists

extern NSString * const kMovieDBList;
extern NSString * const kMovieDBListItemStatus;

#pragma mark - Companies

extern NSString * const kMovieDBCompany;
extern NSString * const kMovieDBCompanyMovies;

#pragma mark - Keywords

extern NSString * const kMovieDBKeyword;
extern NSString * const kMovieDBKeywordMovies;

#pragma mark - Discover

extern NSString * const kMovieDBDiscover;

#pragma mark - Reviews

extern NSString * const kMovieDBReview;

#pragma mark - Changes

extern NSString * const kMovieDBChangesMovie;
extern NSString * const kMovieDBChangesPerson;

#pragma mark - Jobs

extern NSString * const kMovieDBJobList;

#pragma mark - TMDB Manager

typedef void (^TMDBResponseBlock)(id responseObject, NSError *error);

@interface TMDB : AFHTTPSessionManager

@property (nonatomic, copy) NSString *apiKey;

+ (TMDB*)sharedInstance;
- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters block:(TMDBResponseBlock)block;

@end
