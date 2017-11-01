//
//  ViewController.m
//  UploadLogs
//
//  Created by zhouluyao on 10/31/17.
//  Copyright © 2017 zhouluyao. All rights reserved.
//

#import "ViewController.h"
#include "CLogx.hpp"

@interface ViewController ()
{
    CLogx m_clogx;
}
@property (weak, nonatomic) IBOutlet UILabel *displayUploadProcess;
@property (weak, nonatomic) IBOutlet UITextView* logTextView;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

}
- (IBAction)writeLogs:(id)sender
{
    int len = (int)_logTextView.text.length;
    char *szLog = new char[len];
    strcpy(szLog,(char *)[_logTextView.text UTF8String]);
    m_clogx.WriteFile(szLog,len, 0);
}
- (IBAction)uploadLogs:(id)sender
{
    m_clogx.UploadLogs();
}

@end
