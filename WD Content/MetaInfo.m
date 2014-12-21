//
//  MetaInfo.m
//  WD Content
//
//  Created by Сергей Сейтов on 23.09.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "MetaInfo.h"
#import "Node.h"


@implementation MetaInfo

@dynamic cast;
@dynamic director;
@dynamic genre;
@dynamic original_title;
@dynamic overview;
@dynamic release_date;
@dynamic runtime;
@dynamic thumbnail;
@dynamic title;
@dynamic node;

- (NSDictionary*)dictionary
{
	NSMutableDictionary* dict = [NSMutableDictionary new];
	if ([self.cast isKindOfClass:[NSString class]]) {
		[dict setObject:self.cast forKey:@"cast"];
	}
	if ([self.director isKindOfClass:[NSString class]]) {
		[dict setObject:self.director forKey:@"director"];
	}
	if ([self.genre isKindOfClass:[NSString class]]) {
		[dict setObject:self.genre forKey:@"genre"];
	}
	if ([self.original_title isKindOfClass:[NSString class]]) {
		[dict setObject:self.original_title forKey:@"original_title"];
	}
	if ([self.overview isKindOfClass:[NSString class]]) {
		[dict setObject:self.overview forKey:@"overview"];
	}
	if ([self.release_date isKindOfClass:[NSString class]]) {
		[dict setObject:self.release_date forKey:@"release_date"];
	}
	if ([self.runtime isKindOfClass:[NSString class]]) {
		[dict setObject:self.runtime forKey:@"runtime"];
	}
	if ([self.thumbnail isKindOfClass:[NSData class]]) {
		[dict setObject:self.thumbnail forKey:@"thumbnail"];
	}
	if ([self.title isKindOfClass:[NSString class]]) {
		[dict setObject:self.title forKey:@"title"];
	}
	return dict;
}

@end
