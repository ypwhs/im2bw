//
//  ViewController.h
//  im2bw
//
//  Created by 杨培文 on 16/8/19.
//  Copyright © 2016年 杨培文. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgproc/imgproc.hpp>
#import "keras_model.h"

@interface ViewController : UIViewController <CvVideoCameraDelegate>

@end

