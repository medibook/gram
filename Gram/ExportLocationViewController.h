//
//  ExportLocationViewController.h
//  Gram
//
//  Created by Yoshimura Kenya on 2012/08/31.
//  Copyright (c) 2012年 Yoshimura Kenya. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "UITabBarWithAdDelegate.h"

@interface ExportLocationViewController : UIViewController <CLLocationManagerDelegate, MKMapViewDelegate, UITabBarWithAdDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end
