//
//  VEMapContainerView.m
//  Velo'v
//
//  Created by Clément Padovani on 11/3/13.
//  Copyright (c) 2013 Clément Padovani. All rights reserved.
//

#import "VEMapContainerView.h"

#import "VEMapViewController.h"

#import "VEMapViewBlurImageView.h"

#import "VEConsul.h"

#import "UIDevice+Additions.h"

#import "CPCoreDataManager.h"

@interface VEMapContainerView ()

@property (weak, nonatomic, readwrite) VEMapViewBlurImageView *blurImageView;

@property (weak, nonatomic, readwrite) MKMapView *mapView;

- (void) setupConstraints;

@end

@implementation VEMapContainerView

- (instancetype) initWithMapViewDelegate: (id <MKMapViewDelegate>) mapViewDelegate
{
	self = [super init];
	
	if (self)
	{
		MKMapView *mapView = [[MKMapView alloc] init];
		
		[mapView setDelegate: mapViewDelegate];
		
		[mapView setShowsUserLocation: YES];
		
		[mapView setUserTrackingMode: MKUserTrackingModeNone];
		
		[mapView setTranslatesAutoresizingMaskIntoConstraints: NO];
				
		VEMapViewBlurImageView *blurImageView = [[VEMapViewBlurImageView alloc] init];
		
		if ([UIDevice ve_isAniPad])
			[blurImageView setAlpha: 0];
		
		[self addSubview: mapView];
		
		[self addSubview: blurImageView];
		
		_mapView = mapView;
		
		_blurImageView = blurImageView;
		
		[self setTranslatesAutoresizingMaskIntoConstraints: NO];
		
		[self setupConstraints];
	}
	
	return self;
}

- (void) setupConstraints
{
	NSDictionary *viewsDictionary = @{@"_mapView" : [self mapView],
							    @"_blurImageView" : [self blurImageView]};
	
	
	NSDictionary *metricsDictionary = nil;
	
	NSArray *horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[_mapView]|"
															   options: 0
															   metrics: metricsDictionary
																views: viewsDictionary];
	
	[self addConstraints: horizontalConstraints];
	
	NSArray *verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[_mapView]|"
															 options: 0
															 metrics: metricsDictionary
															   views: viewsDictionary];
	
	[self addConstraints: verticalConstraints];
	
	NSArray *blurViewHorizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[_blurImageView]|"
																	 options: 0
																	 metrics: metricsDictionary
																	   views: viewsDictionary];
	
	[self addConstraints: blurViewHorizontalConstraints];
	
	NSArray *blurViewVerticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[_blurImageView]"
																    options: 0
																    metrics: metricsDictionary
																	 views: viewsDictionary];

		
	[self addConstraints: blurViewVerticalConstraints];
}

@end