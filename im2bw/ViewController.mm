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

const int width = 32;
-(cv::Mat)resize:(cv::Mat)img { //将图片转换为正方形
    cv::Mat outimg(width, width, CV_8U, 255);
    float fc = (float)width / img.cols;
    float fr = (float)width / img.rows;
    fc = min(fc, fr);
    fr = fc;
    cv::Size size;
    size.width = img.cols * fc;
    size.height = img.rows * fr;
    if(size.width == 0 || size.height == 0)return outimg;
    cv::resize(img, img, size);
    int w = img.cols, h = img.rows;
    int x = (width - w)/2, y = (width - h)/2;
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
//        float hw = float(h) / w;
        if( w < 100 && h < 100 && h > 10) {
            cv::Mat res = [self resize:bw(rect).clone()];
            cv::rectangle(image, rect, cv::Scalar(0, 255, 0, 255), 0.5);
            int index = predict(res);
//            if(index != 10){
            
            char tmp[10];
//            sprintf(tmp, "%d", index);
            if(index < 10) sprintf(tmp, "%d", index);
            else if(index < 24)sprintf(tmp, "%c", index-10+'a');
            else sprintf(tmp, "%c", index-9+'a');

            cv::putText(image, tmp, cv::Point(x, y-5), cv::FONT_HERSHEY_DUPLEX, 0.5, cv::Scalar(255, 0, 0));
//            }
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
