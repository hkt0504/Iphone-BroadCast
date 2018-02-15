//
//  AppDelegate.m
//  Video Stream
//
//  Created by Rus Flaviu on 12/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "GoLiveViewController.h"

@implementation AppDelegate



- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    
    [application setStatusBarHidden: YES];
    
#if TARGET_IPHONE_SIMULATOR
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"iOS-RTSP"
                                                    message: @"This app uses a video camera. Please run it on a device."
                                                   delegate: nil
                                          cancelButtonTitle: @"Ok"
                                          otherButtonTitles: nil];
    [alert show];
    [alert release];
#else
    
    NSString *nibName;
    
    nibName = @"GoLiveViewController_iPhone";
    
    GoLiveViewController *goLiveViewController = [[GoLiveViewController alloc] initWithNibName: nibName bundle: [NSBundle mainBundle]];
    [self.window setRootViewController: goLiveViewController];
    [goLiveViewController release];
#endif
    
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    //NSLog(@"applicationWillResignActive");
    [[NSNotificationCenter defaultCenter] postNotificationName: @"WillEnterBackground" object: nil];
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    //NSLog(@"applicationWillEnterForeground");
    [[NSNotificationCenter defaultCenter] postNotificationName: @"WillEnterForeground" object: nil];
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[UIApplication sharedApplication] setIdleTimerDisabled: NO];
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
