//
//  VEStationsView.m
//  aBikeLibrary
//
//  Created by Clément Padovani on 5/28/14.
//  Copyright (c) 2014 Clément Padovani. All rights reserved.
//

@import QuartzCore;

#import <tgmath.h>

#import "VEStationsView.h"

#import "VEMapViewController.h"

#import "UIColor+MainColor.h"

#import "VEStationsScrollView.h"

#import "VETimeFormatter.h"

@interface VEStationsView () <UIScrollViewDelegate>

@property (nonatomic, weak) UIVisualEffectView *blurEffectView;

@property (nonatomic, weak) UIView *shadowView;

@property (nonatomic, weak) UIPageControl *pager;

@property (nonatomic, weak) VEStationsScrollView *stationsScrollView;

@property (nonatomic, assign) NSUInteger currentPage;

@property (nonatomic, assign) BOOL hasSetupConstraints;

@property (nonatomic, copy) NSArray *currentConstraints;

- (void) setCurrentStationIndex: (NSUInteger) currentStationIndex withNotification: (BOOL) notifies;

- (void) pageControlDidChangeValue;

- (void) numberOfBikeStationsHasChangedNotification: (NSNotification *) notification;

@end

@implementation VEStationsView

- (instancetype) initWithStationDelegate: (id <VEStationViewDelegate>) stationViewDelegate
{
	self = [super init];
	
	if (self)
	{
		UIView *shadowView = [[UIView alloc] init];
		
		[shadowView setBackgroundColor: [UIColor ve_shadowColor]];
		
		[shadowView setOpaque: NO];
		
		[shadowView setTranslatesAutoresizingMaskIntoConstraints: NO];
		
		UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect: [UIBlurEffect effectWithStyle: UIBlurEffectStyleExtraLight]];

			[blurEffectView setTranslatesAutoresizingMaskIntoConstraints: NO];

		VEStationsScrollView *stationsScrollView = [[VEStationsScrollView alloc] initWithStationDelegate: stationViewDelegate];
		
		[stationsScrollView setDelegate: self];
		
		UIPageControl *pager = [[UIPageControl alloc] init];
		
		//[pager setBackgroundColor: [UIColor purpleColor]];
		
		[pager setCurrentPageIndicatorTintColor: [UIColor ve_mainColor]];
		
		[pager setPageIndicatorTintColor: [UIColor ve_pagerInactiveColor]];
		
		[pager setCurrentPage: 0];
		
		NSInteger numberOfPages = (NSInteger) [VETimeFormatter numberOfBikeStations];
		
		[pager setNumberOfPages: numberOfPages];
		
		[pager addTarget: self action: @selector(pageControlDidChangeValue) forControlEvents: UIControlEventValueChanged];
		
		[pager setTranslatesAutoresizingMaskIntoConstraints: NO];
		
		[self addSubview: blurEffectView];

		[self addSubview: stationsScrollView];
		
		[self addSubview: shadowView];
		
		[self addSubview: pager];
		
		[self setBlurEffectView: blurEffectView];

		[self setStationsScrollView: stationsScrollView];
		
		[self setShadowView: shadowView];
		
		[self setPager: pager];

		[self setBackgroundColor: [UIColor clearColor]];
		
		[self setOpaque: NO];
		
		
		[self setTranslatesAutoresizingMaskIntoConstraints: NO];
		
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(numberOfBikeStationsHasChangedNotification:) name: kVETimeFormatterNumberOfBikeStationsHasChangedNotification object: nil];
	}
	
	return self;
}

//- (UIView *) preferredFocusedView
//{
//	return [self stationsScrollView];
//}

- (BOOL)canBecomeFocused
{
	return YES;
}

- (void) tintColorDidChange
{
	//CPLog(@"pager tint did change");
	
	[[self pager] setCurrentPageIndicatorTintColor: [self tintColor]];
	
	[super tintColorDidChange];
}

- (void) numberOfBikeStationsHasChangedNotification: (NSNotification *) notification
{
	NSInteger numberOfPages = (NSInteger) [VETimeFormatter numberOfBikeStations];
	
	[[self pager] setNumberOfPages: numberOfPages];
}

- (void) pageControlDidChangeValue
{	
	NSUInteger newPage = (NSUInteger) [[self pager] currentPage];
	
	CGRect newRect = [[self stationsScrollView] bounds];
	
	newRect.origin.x = CGRectGetWidth(newRect) * newPage;
	
	[[self delegate] userDidScrollToNewStationForIndex: newPage];
	
	[self setCurrentStationIndex: newPage withNotification: NO];
	
	[[self stationsScrollView] scrollRectToVisible: newRect animated: YES];
}

- (void) scrollViewDidScroll: (UIScrollView *) scrollView
{
	if (![scrollView isDragging])
		return;
	
	CGFloat pageWidth = CGRectGetWidth([[self stationsScrollView] bounds]);
	
	CGFloat horizontalOffset = [scrollView contentOffset].x;
	
	NSUInteger page = (NSUInteger) (round(horizontalOffset / pageWidth));
	
	NSUInteger currentPage = (NSUInteger) [[self pager] currentPage];
	
	if (page == currentPage)
		return;
	
	[[self pager] setCurrentPage: (NSInteger) page];
	
	[self setCurrentStationIndex: page withNotification: NO];
	
	[[self delegate] userDidScrollToNewStationForIndex: page];
}

- (void) layoutSubviews
{
	[super layoutSubviews];
}

- (void) traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
	[super traitCollectionDidChange: previousTraitCollection];

	[self removeConstraints: [self currentConstraints]];

	[self setupConstraintsForTraitCollection: [self traitCollection]];
}

- (void) setupConstraintsForTraitCollection: (UITraitCollection * __nonnull) traitCollection
{
	NSDictionary *viewsDictionary = NSDictionaryOfVariableBindings(self,
													   _shadowView,
													   _pager,
													   _stationsScrollView,
													   _blurEffectView);
	
	NSDictionary *metricsDictionary = @{@"selfWidth" : @(320),
								 @"selfHeight" : @(152.5),
								 @"shadowViewHeight" : @(.5)};

		NSMutableArray *newConstraints = [@[] mutableCopy];
	
		NSArray *blurEffectViewHorizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[_blurEffectView]|"
																			  options: 0
																			  metrics: metricsDictionary
																			    views: viewsDictionary];
		
		[newConstraints addObjectsFromArray: blurEffectViewHorizontalConstraints];
		
		NSArray *blurEffectViewVerticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[_blurEffectView]|"
																			options: 0
																			metrics: metricsDictionary
																			  views: viewsDictionary];
		
		[newConstraints addObjectsFromArray: blurEffectViewVerticalConstraints];

	NSArray *shadowViewHorizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[_shadowView]|"
																	   options: 0
																	   metrics: metricsDictionary
																		views: viewsDictionary];
	
	[newConstraints addObjectsFromArray: shadowViewHorizontalConstraints];
	
	NSArray *pagerHorizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[_pager]|"
																   options: 0
																   metrics: metricsDictionary
																	views: viewsDictionary];
	
	[newConstraints addObjectsFromArray: pagerHorizontalConstraints];
	
	NSArray *pagerVerticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:[_pager]|"
																 options: 0
																 metrics: metricsDictionary
																   views: viewsDictionary];
	
	[newConstraints addObjectsFromArray: pagerVerticalConstraints];
	
	NSArray *stationViewHorizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[_stationsScrollView]|"
																	    options: 0
																	    metrics: metricsDictionary
																		 views: viewsDictionary];
	
	[newConstraints addObjectsFromArray: stationViewHorizontalConstraints];
	
	NSArray *verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[_shadowView(==shadowViewHeight)][_stationsScrollView]|"
															 options: 0
															 metrics: metricsDictionary
															   views: viewsDictionary];
	
	[newConstraints addObjectsFromArray: verticalConstraints];

		[self setCurrentConstraints: newConstraints];

		[self addConstraints: newConstraints];
}

- (void) updateConstraints
{
	if (![self hasSetupConstraints])
	{
		[self setupConstraintsForTraitCollection: [self traitCollection]];

		[self setHasSetupConstraints: YES];
	}

	[super updateConstraints];
}

- (void) setStations: (NSArray *) stations
{
	[[self stationsScrollView] setStations: stations];
	
	[self setCurrentStationIndex: 0];
}

- (void) setCurrentStationIndex: (NSUInteger) currentStationIndex withNotification: (BOOL) notifies
{
	//CPLog(@"index: %ld", currentStationIndex);
	
	if (notifies)
		[self setCurrentStationIndex: currentStationIndex];
	else
	{
		_currentStationIndex = currentStationIndex;
		
		[[self stationsScrollView] setCurrentStationIndex: currentStationIndex];
	}
}

- (void) setCurrentStationIndex: (NSUInteger) currentStationIndex
{
	//CPLog(@"index: %ld", currentStationIndex);
	
	_currentStationIndex = currentStationIndex;
	
	[[self pager] setCurrentPage: (NSInteger) currentStationIndex];
	
	[self pageControlDidChangeValue];
	
	[[self stationsScrollView] setCurrentStationIndex: currentStationIndex];
}

- (VEStationView *) stationViewForStation: (Station *) aStation
{
	return [[self stationsScrollView] stationViewForStation: aStation];
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

+ (BOOL) requiresConstraintBasedLayout
{
	return YES;
}

@end