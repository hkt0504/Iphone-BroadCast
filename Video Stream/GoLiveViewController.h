//
//  GoLiveViewController.h
//  Video Stream
//
//  Created by Rus Flaviu on 12/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BroadcastHighlightView.h"

@interface GoLiveViewController : UIViewController {
    
    
}

@property (retain, nonatomic) IBOutlet UIButton *buttonForSettings;
@property (retain, nonatomic) IBOutlet UIButton *buttonForSound;
@property (retain, nonatomic) IBOutlet UIButton *buttonForTorch;
@property (retain, nonatomic) IBOutlet UIButton *buttonForFlipCamera;
@property (retain, nonatomic) IBOutlet UIButton *buttonForToggleStream;
@property (retain, nonatomic) IBOutlet UILabel *labelForTime;

@property (retain, nonatomic) IBOutlet BroadcastHighlightView *highlightView;

- (IBAction)pushSettings:(id)sender;
- (IBAction)pushTorch:(id)sender;
- (IBAction)pushFlipCamera:(id)sender;
- (IBAction)toggleStream:(id)sender;
- (IBAction)toggleSound:(id)sender;


- (BOOL) connectedToNetwork;

@end
