# im2bw

OpenCV iOS playground

OpenCV iOS 试验场

## 数字检测

虽然是数字检测，也会把字母检测到，如果中文字符是一个连通域，也会检测到，比如"当"。

```c++
- (void)processImage:(Mat &)image {
    Mat gray, bw;
    cvtColor(image, gray, CV_RGB2GRAY);
    adaptiveThreshold(gray, bw, 255, ADAPTIVE_THRESH_GAUSSIAN_C, THRESH_BINARY_INV, 25, 25);
    
    vector<vector<cv::Point>> rects;
    findContours(bw, rects, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);
    
    for( int i = 0; i< rects.size(); i++ ){
        cv::Rect rect = boundingRect(rects[i]);
//        int x = rect.x, y = rect.y;
        int w = rect.width, h = rect.height;
        if( w < 100 && h < 100 && h > 8 ) {
            rectangle(image, rect, Scalar(0, 255, 0, 255), 0.5);
        }
    }
    
    cvtColor(image, image, CV_BGR2RGB);
    UIImage * outimage = MatToUIImage(image);
    dispatch_async(dispatch_get_main_queue(), ^{
        _imageView.image = outimage;
    });
}
```

![](https://raw.githubusercontent.com/ypwhs/resources/master/IMG_0456.PNG)

