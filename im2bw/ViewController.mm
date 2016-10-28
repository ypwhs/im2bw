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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while(true) [self process];
    });
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
    img.copyTo(outimg(cv::Rect(x, y, w, h)));
    return outimg;
}

//#define conv
#ifdef conv
int predict(cv::Mat img){   //预测数字 conv
    cv::bitwise_not(img, img);
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
//    predictions[10] = 0;

    auto max = max_element(predictions.begin(), predictions.end());
    int index = (int)distance(predictions.begin(), max);
    return index;
}

#else
int predict(cv::Mat img){   //预测数字 mlp
    cv::bitwise_not(img, img);
    vector<float> data;
    for (int i = 0; i < img.rows; i++) {
        for (int j = 0; j < img.cols; j++) {
            data.push_back(img.at<uchar>(i, j)/255.0);
        }
    }

    DataChunk * dc = new DataChunkFlat();
    dc->set_data(data); //Mat 转 DataChunk
    
    vector<float> predictions = model->compute_output(dc);
//    predictions[10] = 0;
    
    auto max = max_element(predictions.begin(), predictions.end());
    int index = (int)distance(predictions.begin(), max);
    return index;
}
#endif

cv::Mat img;
cv::Mat gray, bw;
cv::Mat mask(640, 480, CV_8UC3, cv::Scalar(0,0,0));
cv::Mat mask_out(640, 480, CV_8UC3, cv::Scalar(0,0,0));

bool newimage = false;
NSLock * newimagelock = [[NSLock alloc] init];
NSLock * masklock = [[NSLock alloc] init];

- (void) process {
    usleep(1000);
    if(!newimage) return;
    [newimagelock lock];
    cv::cvtColor(img, gray, CV_BGR2GRAY);
    [newimagelock unlock];
    
    adaptiveThreshold(gray, bw, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 25, 25);
    
    vector<vector<cv::Point>> rects;
    findContours(bw.clone(), rects, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    cv::bitwise_not(bw, bw);
    
    mask = cv::Scalar(0,0,0);
    for( int i = 0; i< rects.size(); i++ ){
        cv::Rect rect = boundingRect(rects[i]);
        int x = rect.x, y = rect.y;
        int w = rect.width, h = rect.height;
        float hw = float(h) / w;
        if( w < 200 && h < 200 && h > 10 && 1.1 < hw &&  hw < 5) {
            cv::Mat res = [self resize:bw(rect)];
            cv::rectangle(mask, rect, cv::Scalar(0, 255, 0), 0.5);
            int index = predict(res);
            if(index != 10){
                char tmp[10];
                sprintf(tmp, "%d", index);
                cv::putText(mask, tmp, cv::Point(x, y), cv::FONT_HERSHEY_DUPLEX, 0.5, cv::Scalar(0, 0, 255));
            }
        }
    }
    newimage = false;
    
    [masklock lock];
    mask_out = mask.clone();
    [masklock unlock];
}

cv::Mat mask_not;
- (void)processImage:(cv::Mat &)image {
    cv::cvtColor(image, image, CV_RGBA2BGR);
    [newimagelock lock];
    img = image.clone();
    [newimagelock unlock];
    newimage = true;
    
    [masklock lock];
    cv::cvtColor(mask_out, mask_not, cv::COLOR_BGR2GRAY);
    cv::threshold(mask_not, mask_not, 10, 255, cv::THRESH_BINARY);
    mask_out.copyTo(image, mask_not);
    [masklock unlock];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage * outimage = MatToUIImage(image);
        _imageView.image = outimage;
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
