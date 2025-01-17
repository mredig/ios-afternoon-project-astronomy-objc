//
//  REPRoverController.m
//  Astronomy Combo
//
//  Created by Michael Redig on 10/14/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

#import "REPRoverController.h"
#import "REPRoverControllerDelegate.h"
#import "REPRoverInfo.h"
#import "REPRoverPhotoReference.h"
#import "REPCache.h"

@interface REPRoverController()

@property (nonatomic) NSArray<NSURL *> *internalSolPhotos;
@property (nonatomic) NSUInteger internalSolIndex;
@property (nonatomic) REPRoverInfo *roverManifest;
@property (nonatomic) NSURLSessionDataTask *imageListTask;

@end

@implementation REPRoverController

static NSString const *baseURL = @"https://api.nasa.gov/mars-photos/api/v1/";
static NSString const *apiKey = @"qPsPa3fha2BfdNhwEPExvkMJXp0EgCCTCz82qd3z";

// MARK: - Properties
- (NSArray<NSURL *> *)currentSolPhotos {
	return _internalSolPhotos;
}

- (NSUInteger)currentSolIndex {
	return _internalSolIndex;
}

- (void)setCurrentRover:(NSString *)currentRover {
	_currentRover = currentRover;
	[self loadRoverManifest];
}

- (NSUInteger)currentSol {
	if (!self.roverManifest) {
		return 0;
	}
	REPRoverPhotoReference *reference = self.roverManifest.photosReferences[self.currentSolIndex];
	return reference.sol;
}

// MARK: - init
- (instancetype)initWithRoverNamed:(NSString *)name {
	if (self = [super init]){
		_currentRover = name;
		_internalSolPhotos = @[];
		_internalSolIndex = 0;
		_cache = [[REPCache alloc] init];
		_fetchQueue = [[NSOperationQueue alloc] init];
		[self loadRoverManifest];
	}
	return self;
}

// MARK: - Changing
- (void)nextSol {
	if (self.currentSolIndex + 1 < self.roverManifest.photosReferences.count) {
		self.internalSolIndex++;
	} else {
		self.internalSolIndex = 0;
	}
	[self loadSolImageList];
}

- (void)previousSol {
	if (self.currentSolIndex != 0) {
		self.internalSolIndex--;
	} else {
		self.internalSolIndex = self.roverManifest.photosReferences.count - 1;
	}
	[self loadSolImageList];
}

// MARK: - Network loading
- (void)loadRoverManifest {

	NSURL *url = [NSURL URLWithString:baseURL];
	url = [url URLByAppendingPathComponent:@"manifests"];
	url = [url URLByAppendingPathComponent:self.currentRover];

	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	components.queryItems = @[[NSURLQueryItem queryItemWithName:@"api_key" value:apiKey]];

	url = components.URL;

	NSData* cachedData = [self.cache itemForKey:url.absoluteString];
	if (cachedData) {
		[self decodeRoverManifestWithData:cachedData];
		return;
	}

	NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

		if (error) {
			NSLog(@"Error loading manifest: %@", error);
			return;
		}

		if (data) {
			[self.cache cacheItemWithKey:url.absoluteString item:data];
			[self decodeRoverManifestWithData:data];
			NSLog(@"loaded manifest");
		}
	}];
	[task resume];
}

- (void)decodeRoverManifestWithData:(NSData *)data {
	NSError *jsonError;
	NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
	if (jsonError) {
		NSLog(@"Error decoding manifest: %@", jsonError);
		return;
	}
	self.internalSolIndex = 0;
	self.roverManifest = [[REPRoverInfo alloc] initWithDictionary:jsonDict];
	if (self.delegate) {
		[self.delegate roverControllerLoadedData:self];
	}
	[self loadSolImageList];
}

- (void)loadSolImageList {
	if (self.imageListTask) {
		[self.imageListTask cancel];
	}
	NSURL *url = [NSURL URLWithString:baseURL];
	url = [url URLByAppendingPathComponent:@"rovers"];
	url = [url URLByAppendingPathComponent:self.currentRover];
	url = [url URLByAppendingPathComponent:@"photos"];


	REPRoverPhotoReference *reference = self.roverManifest.photosReferences[self.currentSolIndex];
	NSString *currentSol = [NSString stringWithFormat:@"%li", reference.sol];
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	components.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"api_key" value:apiKey],
		[NSURLQueryItem queryItemWithName:@"sol" value:currentSol]
	];

	url = components.URL;

	NSData* cachedData = [self.cache itemForKey:url.absoluteString];
	if (cachedData) {
		[self decodeImageListFromData:cachedData];
		return;
	}

	self.imageListTask = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

		if (error) {
			NSLog(@"Error loading photo list: %@", error);
			return;
		}

		if (data) {
			[self.cache cacheItemWithKey:url.absoluteString item:data];
			[self decodeImageListFromData:data];
			NSLog(@"loaded photo list");
		}
	}];
	[self.imageListTask resume];
}

- (void)decodeImageListFromData:(NSData *)data {
	NSError *jsonError;
	NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
	if (jsonError) {
		NSLog(@"Error decoding photo list: %@", jsonError);
		return;
	}

	NSArray *photosArray = jsonDict[@"photos"];
	NSMutableArray<NSURL *> *photoURLs = [NSMutableArray array];
	for (NSDictionary *photoDict in photosArray) {
		NSString *photoURLString = photoDict[@"img_src"];

		NSURLComponents *components = [NSURLComponents componentsWithString:photoURLString];
		[components setScheme:@"https"];
		NSURL *photoURL = components.URL;
		[photoURLs addObject:photoURL];
	}
	self.internalSolPhotos = [photoURLs copy];

	if (self.delegate) {
		[self.delegate roverControllerLoadedData:self];
	}
}

@end
