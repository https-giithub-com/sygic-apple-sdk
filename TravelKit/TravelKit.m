//
//  TravelKit.m
//  TravelKit
//
//  Created by Michal Zelinka on 10/02/17.
//  Copyright © 2017 Tripomatic. All rights reserved.
//

#import "TravelKit.h"
#import "TKAPI+Private.h"


@interface TravelKit ()
{
	NSString *_Nullable _language;
}
@end


@implementation TravelKit

+ (TravelKit *)sharedKit
{
	static TravelKit *shared = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [self new];
	});

	return shared;
}

+ (NSArray<NSString *> *)supportedLanguages
{
	static NSArray *langs = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		langs = @[ @"en", @"fr", @"de", @"es", @"nl",
				   @"pt", @"it", @"ru", @"cs", @"sk",
				   @"pl", @"tr", @"zh", @"ko", @"en-GB",
		];
	});

	return langs;
}

- (void)setAPIKey:(NSString *)APIKey
{
	_APIKey = [APIKey copy];

	[TKAPI sharedAPI].APIKey = _APIKey;
}

- (NSString *)language
{
	return _language ?: @"en";
}

- (void)setLanguage:(NSString *)language
{
	NSArray *supported = [[self class] supportedLanguages];
	NSString *newLanguage = (language &&
	  [supported containsObject:language]) ?
		language : nil;

	_language = [newLanguage copy];

	[TKAPI sharedAPI].language = language;
}

- (void)placesForQuery:(TKPlacesQuery *)query completion:(void (^)(NSArray<TKPlace *> *, NSError *))completion
{
	static NSCache<NSNumber *, NSArray<TKPlace *> *> *placesCache = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		placesCache = [NSCache new];
		placesCache.countLimit = 100;
	});

	if (query.quadKeys.count <= 1)
	{
		NSArray *cached = [placesCache objectForKey:@(query.hash)];
		if (cached) {
			if (completion)
				completion(cached, nil);
			return;
		}
	}

	NSMutableArray<NSString *> *neededQuadKeys =
		[NSMutableArray arrayWithCapacity:query.quadKeys.count];
	NSMutableArray<TKPlace *> *cachedPlaces =
		[NSMutableArray arrayWithCapacity:200];

	TKPlacesQuery *workingQuery = [query copy];

	for (NSString *quad in query.quadKeys) {

		workingQuery.quadKeys = @[ quad ];
		NSUInteger queryHash = workingQuery.hash;

		NSArray<TKPlace *> *cached = [placesCache objectForKey:@(queryHash)];

		if (cached)
			[cachedPlaces addObjectsFromArray:cached];
		else
			[neededQuadKeys addObject:quad];
	}

	if (query.quadKeys.count && !neededQuadKeys.count) {
		if (completion)
		{
			[cachedPlaces sortUsingComparator:^NSComparisonResult(TKPlace *lhs, TKPlace *rhs) {
				return [rhs.rating ?: @0 compare:lhs.rating ?: @0];
			}];
			completion(cachedPlaces, nil);
		}
		return;
	}

	workingQuery.quadKeys = neededQuadKeys;

	[[[TKAPIRequest alloc] initAsPlacesRequestForQuery:workingQuery success:^(NSArray<TKPlace *> *places) {

		if (neededQuadKeys.count)
		{
			[cachedPlaces addObjectsFromArray:places];

			NSMutableDictionary<NSString *, NSMutableArray<TKPlace *> *>
				*sorted = [NSMutableDictionary dictionaryWithCapacity:neededQuadKeys.count];

			for (NSString *quad in neededQuadKeys)
				sorted[quad] = [NSMutableArray arrayWithCapacity:64];

			for (TKPlace *p in places)
				for (NSString *quad in neededQuadKeys)
					if ([p.quadKey hasPrefix:quad])
					{
						[sorted[quad] addObject:p];
						break;
					}

			for (NSString *quad in sorted.allKeys)
			{
				workingQuery.quadKeys = @[ quad ];
				NSUInteger hash = workingQuery.hash;
				[placesCache setObject:sorted[quad] forKey:@(hash)];
			}

			places = [cachedPlaces sortedArrayUsingComparator:^NSComparisonResult(TKPlace *lhs, TKPlace *rhs) {
				return [rhs.rating ?: @0 compare:lhs.rating ?: @0];
			}];
		}
		else {
			NSUInteger queryHash = workingQuery.hash;
			[placesCache setObject:places forKey:@(queryHash)];

		}

		if (completion)
			completion(places, nil);

	} failure:^(TKAPIError *error) {

		if (completion)
			completion(nil, error);

	}] start];
}

- (void)detailedPlaceWithID:(NSString *)placeID completion:(void (^)(TKPlace *, NSError *))completion
{
	static NSCache<NSString *, TKPlace *> *placeCache = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		placeCache = [NSCache new];
		placeCache.countLimit = 200;
	});

	TKPlace *cached = [placeCache objectForKey:placeID];

	if (cached) {
		if (completion)
			completion(cached, nil);
		return;
	}

	[[[TKAPIRequest alloc] initAsPlaceRequestForItemWithID:placeID success:^(TKPlace *place) {

		[placeCache setObject:place forKey:placeID];

		if (completion)
			completion(place, nil);

	} failure:^(TKAPIError *error) {

		if (completion)
			completion(nil, error);

	}] start];
}

- (void)mediaForPlaceWithID:(NSString *)placeID completion:(void (^)(NSArray<TKMedium *> *, NSError *))completion
{
	static NSCache<NSString *, NSArray<TKMedium *> *> *mediaCache = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		mediaCache = [NSCache new];
		mediaCache.countLimit = 50;
	});

	NSArray *cached = [mediaCache objectForKey:placeID];

	if (cached) {
		if (completion)
			completion(cached, nil);
		return;
	}

	[[[TKAPIRequest alloc] initAsMediaRequestForPlaceWithID:placeID success:^(NSArray<TKMedium *> *media) {

		[mediaCache setObject:media forKey:placeID];

		if (completion)
			completion(media, nil);

	} failure:^(TKAPIError *error){

		if (completion)
			completion(nil, error);

	}] start];
}

@end
