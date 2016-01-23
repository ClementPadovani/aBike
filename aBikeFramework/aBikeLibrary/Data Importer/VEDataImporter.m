//
//  VEDataImporter.m
//  Velo'v
//
//  Created by Clément Padovani on 7/17/13.
//  Copyright (c) 2013 Clément Padovani. All rights reserved.
//

#import "VEDataImporter.h"

#import "VEConsul.h"

#import "CPCoreDataManager.h"

#import "UserSettings+Additions.h"

#import "NSString+ProcessedStationName.h"

#import "NSNumber+Extensions.h"

#import "VEConnectionManager.h"

//#define kJCDecauxAPIKey @"2d93849e709748d86c10c303ba94a773f14de3a2"
//#define kVEDataImporterStationListURL @"https://api.jcdecaux.com/vls/v1/stations?contract=%@&apiKey=%@"
//#define kVEDataImporterStationInformationURL @"https://api.jcdecaux.com/vls/v1/stations/%@?contract=%@&apiKey=%@"

static NSString * const kJCDecauxAPIKey = @"2d93849e709748d86c10c303ba94a773f14de3a2";

static NSString * const kVEDataImporterStationListURL = @"https://api.jcdecaux.com/vls/v1/stations?contract=%@&apiKey=%@";

static NSString * const kVEDataImporterStationInformationURL = @"https://api.jcdecaux.com/vls/v1/stations/%@?contract=%@&apiKey=%@";


/*
 
 station number = "number" // string
 
 contract identifier = "contract_name" // string
 
 station name = "name" // string
 
 station address = "address" // string
 
 station coords = "position" // dictionary
 
 station coords lat = "lat" // number
 
 station coords lon = "lng" // number
 
 station has banking = "banking" // bool
 
 station is bonus = "bonus" // bool
 
 station is open = "status" // string, "OPEN" or "CLOSED"
 
 total number of stands = "bike_stands" // number
 
 number of available stands = "available_bike_stands" // number
 
 number of available bikes = "available_bikes" // number
 
 last content update = "last_update" // number in ms (MILLISECONDS) since epoch
 
 note: updates are ~ every 10 mins
 
 
 */


NSString * const kStationNumber = @"number";

NSString * const kStationContractIdentifier = @"contract_name";

NSString * const kStationName = @"name";

NSString * const kStationAddress = @"address";

NSString * const kStationCoords = @"position";

NSString * const kStationCoordsLatitude = @"lat";

NSString * const kStationCoordsLongitude = @"lng";

NSString * const kStationBanking = @"banking";

NSString * const kStationBonus = @"bonus";

NSString * const kStationStatus = @"status";

NSString * const kStationStatusOpen = @"OPEN";

NSString * const kStationTotalStands = @"bike_stands";

NSString * const kStationAvailableStands = @"available_bike_stands";

NSString * const kStationAvailableBikes = @"available_bikes";

NSString * const kStationContentAge = @"last_update";

static NSString * const kVEDataImporterSessionConfigurationAcceptString = @"application/json";

static const NSUInteger kVEDataImporterBatchSaveSize = 125;

static NSURLSession *_sharedSession = nil;

static BOOL _isImportingData;

@interface VEDataImporter ()

+ (NSURLSessionConfiguration *) aBikeSessionConfiguration;

+ (NSString *) appVersion;

@end

@implementation VEDataImporter

+ (BOOL) isImportingData
{
	BOOL isImportingData;

	@synchronized(self)
	{
		isImportingData = _isImportingData;
	}

	return isImportingData;
}

+ (void) setImportingData: (BOOL) importingData
{
	@synchronized(self)
	{
		_isImportingData = importingData;
	}
}

+ (NSURLSession *) aBikeSession
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedSession = [NSURLSession sessionWithConfiguration: [self aBikeSessionConfiguration]];
	});
	
	return _sharedSession;
}

+ (void) tearDownSession
{
	_sharedSession = nil;
}

+ (NSURLSessionConfiguration *) aBikeSessionConfiguration
{
	NSString *userAgentString = [NSString stringWithFormat: @"aBike/%@", [self appVersion]];
	
	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	
	[configuration setAllowsCellularAccess: YES];
	
	[configuration setDiscretionary: NO];
	
	[configuration setHTTPAdditionalHeaders: @{@"User-Agent"	:	userAgentString,
									   @"Accept"		:	kVEDataImporterSessionConfigurationAcceptString}];
	
	return configuration;
}

+ (void) importStationListDataWithStationsData: (NSData *) stationsData
{
	if ([self isImportingData])
	{
		return;
	}

	[self setImportingData: YES];

	if (!stationsData)
	{
		//CPLog(@"have nil data... returning...");
		
		return;
	}
	
	//CPLog(@"starting import");
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		
		//CPLog(@"denying saves");
		
		[[VEConsul sharedConsul] setCanSave: NO];
		
		//CPLog(@"has denied saves");
		
	});
	
	NSError *serializationError = nil;
	
	NSArray *jsonSerializedData = [NSJSONSerialization JSONObjectWithData: stationsData options: 0 error: &serializationError];
	
	if (serializationError)
	{
		#if kEnableCrashlytics

		[[Crashlytics sharedInstance] recordError: serializationError];
		
		#endif
	}
	
	NSAssert(!serializationError, @"Serialization error: %@", serializationError);
	
	VEManagedObjectContext *userContext = [[CPCoreDataManager sharedCoreDataManager] userContext];
	
	VEManagedObjectContext *importContext = [[CPCoreDataManager sharedCoreDataManager] newImportManagedObjectContext];
	
	NSString *contractIdentifier = [jsonSerializedData firstObject][kStationContractIdentifier];
	
	#if !(enableNumberOfStations)
	
		CPLog(@"number of stations: %lu", [jsonSerializedData count]);
	
	#endif
	
	NSAssert(contractIdentifier, @"Nil contract identifier.");
	
	NSAssert(!([contractIdentifier length] == 0), @"");
	
	[userContext performBlock: ^{
		
		[[UserSettings sharedSettings] setContractIdentifier: contractIdentifier];
		
	}];
	
	[importContext performBlockAndWait: ^{
		
		VECityRect cityRect;
		
		CLLocationDegrees minLat, minLon, maxLat, maxLon;
		
		minLat = 90;
		
		minLon = 180;
		
		maxLat = -90;
		
		maxLon = -180;
		
		NSUInteger currentCount = 0;
		
		for (NSDictionary *aStationDictionary in jsonSerializedData)
		{
			currentCount++;
			
			if (currentCount % kVEDataImporterBatchSaveSize == 0)
			{
				
				NSError *saveError;
				
				if (![importContext attemptToSave: &saveError])
				{
					CPLog(@"save error: %@", saveError);
					
					[[Crashlytics sharedInstance] recordError: saveError];
				}
				else
				{
					//CPLog(@"has saved");
				}
			}
			
			BOOL hasLocation, hasDataAge;
			
			NSDictionary *stationCoords = aStationDictionary[kStationCoords];
			
			hasLocation = stationCoords != nil && stationCoords[kStationCoordsLatitude] != nil && stationCoords[kStationCoordsLongitude] != nil;
			
			hasDataAge = aStationDictionary[kStationContentAge] != nil;
			
			if (!hasLocation || !hasDataAge)
			{
				CPLog(@"no location and/or data age");
				
				continue;
			}
			
			CLLocationDegrees latitude, longitude;
			
			latitude = [stationCoords[kStationCoordsLatitude] ve_locationDegrees];
			
			longitude = [stationCoords[kStationCoordsLongitude] ve_locationDegrees];
			
//			if (latitude <= 0 || longitude <= 0)
//			{
//				CPLog(@"invalid coords");
//				
//				continue;
//			}
			
			[Station stationFromStationDictionary: aStationDictionary inContext: importContext];
			
			minLat = fmin(minLat, latitude);
			
			minLon = fmin(minLon, longitude);
			
			maxLat = fmax(maxLat, latitude);
			
			maxLon = fmax(maxLon, longitude);
		}
		
		cityRect.minLat = minLat;
		
		cityRect.minLon = minLon;
		
		cityRect.maxLat = maxLat;
		
		cityRect.maxLon = maxLon;
		
		VECityRect marginalizedCityRect = VECityRectMakeLarger(cityRect);
		
		
		
		NSError *finalSaveError;
		
		if (![importContext attemptToSave: &finalSaveError])
		{
			CPLog(@"final save error: %@", finalSaveError);
			
			[[Crashlytics sharedInstance] recordError: finalSaveError];
		}
		else
		{
			//CPLog(@"final save");
		}
		
		[userContext performBlockAndWait: ^{
			
			[[UserSettings sharedSettings] setCityRect: cityRect];
			
			[[UserSettings sharedSettings] setLargerCityRect: marginalizedCityRect];
			
		}];
		
	}];
	
	[userContext performBlockAndWait: ^{
		
		[[UserSettings sharedSettings] setLastDataImportDate: [NSDate date]];
		
	}];
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		
		[[VEConsul sharedConsul] setCanSave: YES];
		
		[[VEConsul sharedConsul] saveContext];
	});

	[self setImportingData: NO];
}

+ (void) attemptToDownloadStationListForIdentifier: (NSString *) identifier withCompletionHandler: (void (^)(NSError *stationError, NSData *stationData)) completionHandler
{
	NSError *internalError = nil;
	
	if (![[VEConnectionManager sharedConnectionManger] isReachable])
	{
		CPLog(@"NOT REACHABLE");
		
		NSString *serviceName = [[VEConsul sharedConsul] cityServiceName];
		
		NSString *descriptionString = [NSString stringWithFormat: CPLocalizedString(@"Cannot connect to %@.", @"nointernet_error_desc_key"), serviceName];
		
		NSDictionary *userInfo = @{NSLocalizedDescriptionKey : descriptionString,
							  NSLocalizedFailureReasonErrorKey : CPLocalizedString(@"Please check your internet connection.", @"nointernet_error_failure_reason_key")};
		
		internalError = [NSError errorWithDomain: NSURLErrorDomain code: NSURLErrorNotConnectedToInternet userInfo: userInfo];
		
		
		completionHandler(internalError, nil);
		
		return;
	}
	
	__block BOOL canLoadData;
	
	VEManagedObjectContext *userContext = [[CPCoreDataManager sharedCoreDataManager] userContext];
	
	[userContext performBlockAndWait: ^{
		
		canLoadData = [[UserSettings sharedSettings] canLoadData];
		
	}];
	
	if (!canLoadData)
	{
		completionHandler(nil, nil);
		
		return;
	}
	
	//CPLog(@"will download");
	
	NSURL *downloadURL = [VEDataImporter dataURLForIdentifier: identifier];
	
	NSURLSession *downloadSession = [self aBikeSession];
	
	NSURLSessionDataTask *downloadTask = [downloadSession dataTaskWithURL: downloadURL
											  completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
												  
												  completionHandler(error, data);
												  
											  }];
	
	[downloadTask resume];
	
	//[downloadSession finishTasksAndInvalidate];
}

+ (NSURL *) dataURLForIdentifier: (NSString *) identifier
{
	return [NSURL URLWithString: [NSString stringWithFormat: kVEDataImporterStationListURL, identifier, kJCDecauxAPIKey]];
}

+ (NSURL *) stationDataURLForStation: (Station *) aStation
{
	NSURL *dataURL;

	//dataURL = [NSURL URLWithString: [NSString stringWithFormat: kVEDataImporterStationInformationURL, [[aStation number] stringValue]]];
	
	dataURL = [NSURL URLWithString: [NSString stringWithFormat: kVEDataImporterStationInformationURL, [[aStation number] stringValue], [aStation contractIdentifier], kJCDecauxAPIKey]];
	
	return dataURL;
}

+ (NSString *) appVersion
{
	return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
}

@end
