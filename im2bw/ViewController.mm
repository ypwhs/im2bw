//
//  ViewController.m
//  im2bw
//
//  Created by 杨培文 on 16/8/19.
//  Copyright © 2016年 杨培文. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIButton *button;

@end

@implementation ViewController

using namespace std;
using namespace keras;

CvVideoCamera * camera;
KerasModel * model;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    camera = [[CvVideoCamera alloc] initWithParentView: _imageView];
    camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    camera.defaultFPS = 30;
    camera.grayscaleMode = NO;
    camera.delegate = self;
    
    NSString* file_path = [[NSBundle mainBundle] pathForResource:@"model" ofType:@"txt"];
    model = new KerasModel([file_path UTF8String]);
}

- (void)viewDidAppear:(BOOL)animated {
    [camera start];
}

bool state = true;
- (IBAction)click:(UIButton *)sender {
    if(state){
        [sender setTitle:@"继续" forState: UIControlStateNormal];
        [camera stop];
    }else{
        [sender setTitle:@"暂停" forState: UIControlStateNormal];
        [camera start];
    }
    state = !state;
}

-(cv::Mat)resize:(cv::Mat)img { //将图片转换为28*28
    cv::Mat outimg(28, 28, CV_8U, 255);
    float fc = 28.0 / img.cols;
    float fr = 28.0 / img.rows;
    fc = min(fc, fr);
    fr = fc;
    cv::Size size;
    size.width = img.cols * fc;
    size.height = img.rows * fr;
    if(size.width == 0 || size.height == 0)return outimg;
    cv::resize(img, img, size);
    int w = img.cols, h = img.rows;
    int x = (28 - w)/2, y = (28 - h)/2;
    img.copyTo( outimg(cv::Rect(x, y, w, h)) );
    
//    UIImage * outimage = MatToUIImage(outimg);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        _imageView2.image = outimage;
//    });
    
    return outimg;
}

int predict(cv::Mat img){   //预测数字
    vector<vector<vector<float>>> data;
    vector<vector<float>> d;
    for (int i = 0; i < img.rows; i++) {
        vector<float> r;
        for (int j = 0; j < img.cols; j++) {
            r.push_back(img.at<uchar>(i, j)/255.0);
        }
        d.push_back(r);
    }
    data.push_back(d);
    
    DataChunk * dc = new DataChunk2D();
    dc->set_data(data); //Mat 转 DataChunk
    
    vector<float> predictions = model->compute_output(dc);
    predictions[10] = 0;
    
    auto max = max_element(predictions.begin(), predictions.end());
    int index = (int)distance(predictions.begin(), max);
    return index;
}

- (void)processImage:(cv::Mat &)image {
    cv::Mat gray, bw;
    cvtColor(image, gray, CV_BGR2GRAY);
    adaptiveThreshold(gray, bw, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 25, 25);
    
    vector<vector<cv::Point>> rects;
    findContours(bw.clone(), rects, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    cv::bitwise_not(bw, bw);
    
    for( int i = 0; i< rects.size(); i++ ){
        cv::Rect rect = boundingRect(rects[i]);
        
        int x = rect.x, y = rect.y;
        int w = rect.width, h = rect.height;
        if( w < 100 && h < 100 && h > 10 ) {
            cv::Mat res = [self resize:bw(rect).clone()];
            
            int index = predict(res);
            if(index != 10){
                char tmp[2];
                sprintf(tmp, "%d", index);
                cv::rectangle(image, rect, cv::Scalar(0, 255, 0, 255), 0.5);
                cv::putText(image, tmp, cv::Point(x, y), cv::FONT_HERSHEY_DUPLEX, 0.5, cv::Scalar(255, 0, 0));
            }
        }
    }
    
    cvtColor(image, image, CV_BGR2RGB);
    
    UIImage * outimage = MatToUIImage(image);
    dispatch_async(dispatch_get_main_queue(), ^{
        _imageView.image = outimage;
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
