//
//  ViewController.m
//  VideoCapture
//
//  Created by 刘春明 on 2018/7/31.
//  Copyright © 2018年 刘春明. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AssetsLibrary/AssetsLibrary.h>


#define kScreen_Height   ([UIScreen mainScreen].bounds.size.height)
#define kScreen_Width    ([UIScreen mainScreen].bounds.size.width)
#define GW(weakSelf)  __weak __typeof(&*self)weakSelf = self;

#define fileSaved  @"favde"
#define waterSaved  @"watesr"

typedef enum : NSUInteger {
    Type1X1 =0,
    Type4X3,
    TypeFullScreen,
} LMVideoViewType;

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate>

@property (nonatomic ,strong) AVCaptureSession *session;

@property (nonatomic ,strong) AVCaptureDeviceInput *videoInput;

@property (nonatomic ,strong) AVCaptureDeviceInput *audioInput;

@property (nonatomic ,strong) AVCaptureAudioDataOutput *audioOutput;

@property (nonatomic ,strong) AVCaptureMovieFileOutput *FileOutput;

@property (nonatomic) dispatch_queue_t videoQueue;

@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *previewlayer;

@property (nonatomic ,strong) NSURL *videoUrl;

@property (nonatomic ,strong) MPMoviePlayerController *mPMoviePlayerController;

@property (nonatomic) NSInteger nameCount;

@property (nonatomic ,strong) AVAssetExportSession *exportSession;

@property (nonatomic ,strong) NSMutableArray *combineArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.session = [[AVCaptureSession alloc] init];
    if ([_session canSetSessionPreset:AVCaptureSessionPreset640x480]) {//设置分辨率
        _session.sessionPreset=AVCaptureSessionPreset640x480;
    }
    
    self.videoQueue = dispatch_queue_create("com.SerialQueue",
                                            NULL);
    
    [self setUpVideoAVCaptureDevicePosition:AVCaptureDevicePositionBack];
    [self setUpAudio];
    [self setUpFileOut];
    [self setUpPreviewLayerWithType:Type1X1];
    
    self.nameCount = 10;
    
}
- (IBAction)tapClick:(id)sender {
    
    [(UIButton *)sender setSelected:![(UIButton *)sender isSelected]];
    UIButton *btn = (UIButton *)sender;
    if (btn.tag == 1) {
        if (!btn.isSelected) {
            // 取消视频拍摄
            [self.FileOutput stopRecording];
            
//            [self.session stopRunning];
            
            
        }else{
            self.nameCount +=1;
            NSString *videoPath = [self createVideoFilePath:[NSString stringWithFormat:@"%ld",self.nameCount]];
            self.videoUrl = [NSURL fileURLWithPath:videoPath];
            [self.FileOutput startRecordingToOutputFileURL:self.videoUrl recordingDelegate:self];
            
        }
        
    }else if (btn.tag == 2) {
//        CGFloat size = [self getfileSize:[self createVideoFilePath:@"combine"]];
//        NSLog(@"%f",size);
        [self combine];
    }else if (btn.tag == 3) {
        CGFloat size = [self getfileSize:[self getMergeVideoFilePath]];
        NSLog(@"%f",size);
//        NSLog(@"%@",[self createVideoFilePath]);
////        1.先自定义一个全局的MPMoviePlayerController 对象
        MPMoviePlayerController *mPMoviePlayerController;
//        2.视频的播放
        mPMoviePlayerController = [[MPMoviePlayerController alloc]initWithContentURL:[NSURL fileURLWithPath:[self getMergeVideoFilePath]]];
        mPMoviePlayerController.view.frame = CGRectMake(0, 100, 414, 300);
        mPMoviePlayerController.movieSourceType = MPMovieSourceTypeUnknown;//设置播放的视频为本地文件
        mPMoviePlayerController.initialPlaybackTime = -1.0f;
        [mPMoviePlayerController prepareToPlay];
        [mPMoviePlayerController setShouldAutoplay:YES];
        [self.view addSubview:mPMoviePlayerController.view];
        self.mPMoviePlayerController = mPMoviePlayerController;

    }else if(btn.tag == 4){
        
        self.session = nil;
        self.session = [[AVCaptureSession alloc] init];
        if ([_session canSetSessionPreset:AVCaptureSessionPreset640x480]) {//设置分辨率
            _session.sessionPreset=AVCaptureSessionPreset640x480;
        }
        self.audioInput = nil;
        self.videoInput = nil;
        self.FileOutput = nil;
        
        [self setUpVideoAVCaptureDevicePosition:AVCaptureDevicePositionFront];
        [self setUpAudio];
        [self setUpFileOut];
        [self setUpPreviewLayerWithType:Type1X1];
    }else if(btn.tag == 5){
        [self addWaterImg];
        
    }else if(btn.tag == 6){
        [self saveCombineVideoToAlbum];
    }else if(btn.tag == 7){
        //裁剪视频
        
    }else if(btn.tag == 8){
        
    }
}


- (void)saveCombineVideoToAlbum{
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    [library writeVideoAtPathToSavedPhotosAlbum:[NSURL fileURLWithPath:[self getMergeVideoFilePath]]
     
                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                    
                                    if (error) {
                                        
                                        NSLog(@"Save video fail:%@",error);
                                        NSString *path = [self getMergeVideoFilePath];
                                        NSFileManager *mana = [NSFileManager defaultManager];
                                        if ([mana fileExistsAtPath:path isDirectory:NO]) {
                                            [mana removeItemAtPath:path error:nil];
                                        }
                                    } else {
                                        
                                        NSLog(@"Save video succeed.");
                                        NSString *path = [self getMergeVideoFilePath];
                                        NSFileManager *mana = [NSFileManager defaultManager];
                                        if ([mana fileExistsAtPath:path isDirectory:NO]) {
                                            [mana removeItemAtPath:path error:nil];
                                        }
                                    }
                                    
                                }];
    
    
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog(@"---- 开始录制 ----");
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"---- 录制结束 ----");
}


- (CGFloat)getfileSize:(NSString *)path
{
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSLog (@"file size: %f", (unsigned long long)[outputFileAttributes fileSize]/1024.00 /1024.00);
    return (CGFloat)[outputFileAttributes fileSize]/1024.00 /1024.00;
}

- (void)setUpVideoAVCaptureDevicePosition:(AVCaptureDevicePosition)position
{
    // 1.1 获取视频输入设备(摄像头)
    AVCaptureDevice *videoCaptureDevice=[self getCameraDeviceWithPosition:position];//取得后置摄像头
    
    // 视频 HDR (高动态范围图像)
    // videoCaptureDevice.videoHDREnabled = YES;
    // 设置最大，最小帧速率
    //videoCaptureDevice.activeVideoMinFrameDuration = CMTimeMake(1, 60);
    // 1.2 创建视频输入源
    NSError *error=nil;
    self.videoInput= [[AVCaptureDeviceInput alloc] initWithDevice:videoCaptureDevice error:&error];
    // 1.3 将视频输入源添加到会话
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
        
    }
}

-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

- (void)setUpAudio
{
    // 2.2 获取音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    NSError *error=nil;
    // 2.4 创建音频输入源
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioCaptureDevice error:&error];
    // 2.6 将音频输入源添加到会话
    if ([self.session canAddInput:self.audioInput]) {
        [self.session addInput:self.audioInput];
    }
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self queue:self.videoQueue];
    if([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    
}

- (void)setUpFileOut
{
    // 3.1初始化设备输出对象，用于获得输出数据
    self.FileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    // 3.2设置输出对象的一些属性
    AVCaptureConnection *captureConnection=[self.FileOutput connectionWithMediaType:AVMediaTypeVideo];
    //设置防抖
    //视频防抖 是在 iOS 6 和 iPhone 4S 发布时引入的功能。到了 iPhone 6，增加了更强劲和流畅的防抖模式，被称为影院级的视频防抖动。相关的 API 也有所改动 (目前为止并没有在文档中反映出来，不过可以查看头文件）。防抖并不是在捕获设备上配置的，而是在 AVCaptureConnection 上设置。由于不是所有的设备格式都支持全部的防抖模式，所以在实际应用中应事先确认具体的防抖模式是否支持：
    if ([captureConnection isVideoStabilizationSupported ]) {
        captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
    }
    //预览图层和视频方向保持一致
    captureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
//    [self.previewlayer connection].videoOrientation;
    
    
    // 3.3将设备输出添加到会话中
    if ([_session canAddOutput:_FileOutput]) {
        [_session addOutput:_FileOutput];
    }
}

- (void)setUpPreviewLayerWithType:(LMVideoViewType )type
{
    CGRect rect = CGRectZero;
    switch (type) {
        case Type1X1:
            rect = CGRectMake(0, 0, kScreen_Width, kScreen_Width);
            break;
        case Type4X3:
            rect = CGRectMake(0, 0, kScreen_Width, kScreen_Width*4/3);
            break;
        case TypeFullScreen:
            rect = [UIScreen mainScreen].bounds;
            break;
        default:
            rect = [UIScreen mainScreen].bounds;
            break;
    }
    self.previewlayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewlayer.frame = rect;
//    self.previewlayer.backgroundColor = [UIColor blueColor].CGColor;
    [self.view.layer addSublayer:self.previewlayer];
    [self.session startRunning];
}

-(NSString *)getWaterVideoFilePath{
    return [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/%@.mp4",waterSaved]];
    //    return  [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

-(NSString *)getMergeVideoFilePath{
    return [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/%@.mp4",fileSaved]];
}

-(NSString *)createVideoFilePath:(NSString *)name{
    return [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/%@.mp4",name]];
}

#pragma mark -合并视频

-(void)combine{
    self.combineArray = [[NSMutableArray alloc] initWithCapacity:0];
    for (int i =11; i<=self.nameCount; i++) {
        NSString *url = [self createVideoFilePath:[NSString stringWithFormat:@"%d",i]];
        if(url.length >0){
            [self.combineArray addObject:url];
        }
    }
    if (self.combineArray.count <= 0) {
        return;
    }
    
    [self mergeAndExportVideos:self.combineArray withOutPath:[self getMergeVideoFilePath]];
//    [self mergeVideoToOneVideo:self.combineArray toStorePath:[self getMergeVideoFilePath] WithStoreName:@"did" andIf3D:NO success:^{
//        NSLog(@"success merge.");
//    } failure:^{
//        NSLog(@"failure merge.");
//    }];
}

- (void)mergeAndExportVideos:(NSArray*)videosPathArray withOutPath:(NSString*)outpath{
    if (videosPathArray.count == 0) {
        return;
    }
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    
    
    CMTime totalDuration = kCMTimeZero;
    for (int i = 0; i < videosPathArray.count; i++) {
        CGFloat size = [self getfileSize:videosPathArray[i]];
        NSLog(@"%f",size);
        
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:videosPathArray[i]]];
        NSError *erroraudio = nil;
        　　　　　//获取AVAsset中的音频 或者视频
        AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        　　　　　//向通道内加入音频或者视频
        BOOL ba = [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                      ofTrack:assetAudioTrack
                                       atTime:totalDuration
                                        error:&erroraudio];
        
        NSLog(@"erroraudio:%@%d",erroraudio,ba);
        NSError *errorVideo = nil;
        AVAssetTrack *assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo]firstObject];
        
        BOOL bl = [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                      ofTrack:assetVideoTrack
                                       atTime:totalDuration
                                        error:&errorVideo];
         [videoTrack setPreferredTransform:assetVideoTrack.preferredTransform];

        NSLog(@"errorVideo:%@%d",errorVideo,bl);
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        
    }
    
    
    
    
    
    NSURL *mergeFileURL = [NSURL fileURLWithPath:outpath];
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        NSLog(@"exporter%@",exporter.error);
        
        switch ([exporter status]) {
                
            case AVAssetExportSessionStatusUnknown: {
                
                break;
            }
            case AVAssetExportSessionStatusWaiting: {
                
                break;
            }
            case AVAssetExportSessionStatusExporting: {
                
                break;
            }
            case AVAssetExportSessionStatusCompleted: {
                CGFloat size = [self getfileSize:[self getMergeVideoFilePath]];
                NSLog(@"%f",size);
                break;
            }
            case AVAssetExportSessionStatusFailed: {
                
                NSLog(@"failed, error:%@.", exporter.error);
                NSString *path = [self getMergeVideoFilePath];
                NSFileManager *mana = [NSFileManager defaultManager];
                if ([mana fileExistsAtPath:path isDirectory:NO]) {
                    [mana removeItemAtPath:path error:nil];
                }
            }
                
            case AVAssetExportSessionStatusCancelled: {
                
                break;
            }
            default:
                break;
        }
    }];
}


#pragma mark -添加水印
-(void)addWaterImg{
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    
    
    CMTime totalDuration = kCMTimeZero;
    
    NSDictionary*optional =@{@"AVURLAssetPreferPreciseDurationAndTimingKey":@(YES)};
    AVURLAsset*asset = [[AVURLAsset alloc]initWithURL:[NSURL fileURLWithPath:[self getMergeVideoFilePath]] options:optional];
    
//    AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[self getMergeVideoFilePath]]];
    NSError *erroraudio = nil;
    　　　　　//获取AVAsset中的音频 或者视频
    AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
   
    NSError *errorVideo = nil;
    AVAssetTrack *assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo]firstObject];
    
    BOOL bl = [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                  ofTrack:assetVideoTrack
                                   atTime:totalDuration
                                    error:&errorVideo];
    [videoTrack setPreferredTransform:assetVideoTrack.preferredTransform];
    
    //3.1 AVMutableVideoCompositionInstruction 视频轨道中的一个视频，可以缩放、旋转等
    AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration);
    
    // 3.2 AVMutableVideoCompositionLayerInstruction 一个视频轨道，包含了这个轨道上的所有视频素材
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    //        AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    //    UIImageOrientation videoAssetOrientation_  = UIImageOrientationUp;
    BOOL isVideoAssetPortrait_  = NO;
    CGAffineTransform videoTransform = assetVideoTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        //        videoAssetOrientation_ = UIImageOrientationRight;
        isVideoAssetPortrait_ = YES;
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        //        videoAssetOrientation_ =  UIImageOrientationLeft;
        isVideoAssetPortrait_ = YES;
    }
    //    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
    //        videoAssetOrientation_ =  UIImageOrientationUp;
    //    }
    //    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
    //        videoAssetOrientation_ = UIImageOrientationDown;
    //    }
    [videolayerInstruction setTransform:assetVideoTrack.preferredTransform atTime:kCMTimeZero];
    [videolayerInstruction setOpacity:1.0 atTime:kCMTimeZero];
    // 3.3 - Add instructions
    mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction,nil];
    //AVMutableVideoComposition：管理所有视频轨道，可以决定最终视频的尺寸，裁剪需要在这里进行
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    
    CGSize naturalSize;
    if(isVideoAssetPortrait_){
        naturalSize = CGSizeMake(assetVideoTrack.naturalSize.height, assetVideoTrack.naturalSize.width);
    } else {
        naturalSize = assetVideoTrack.naturalSize;
    }
    
    float renderWidth, renderHeight;
    renderWidth = naturalSize.width;
    renderHeight = naturalSize.height;
    if (renderWidth == 0) {
        renderWidth = 100;
    }
    if (renderHeight == 0) {
        renderHeight = 100;
    }
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.renderSize = CGSizeMake(renderWidth, renderHeight);
    mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
    mainCompositionInst.frameDuration = CMTimeMake(1, 25);
    [self applyVideoEffectsToComposition:mainCompositionInst WithWaterImg:[UIImage imageNamed:@"water.png"] WithCoverImage:[UIImage imageNamed:@"cover.png"] WithQustion:@"ques" size:CGSizeMake(500, 500)];
    
    NSURL* videoUrl = [NSURL fileURLWithPath:[self getWaterVideoFilePath]];
    
   CADisplayLink *  dlink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgress)];
    [dlink setFrameInterval:15];
    [dlink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [dlink setPaused:NO];
    // 5 - 视频文件输出
    
    AVAssetExportSession* exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=videoUrl;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    exporter.videoComposition = mainCompositionInst;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        NSLog(@"exporter%@",exporter.error);
        
        switch ([exporter status]) {
                
            case AVAssetExportSessionStatusUnknown: {
                
                break;
            }
            case AVAssetExportSessionStatusWaiting: {
                
                break;
            }
            case AVAssetExportSessionStatusExporting: {
                
                break;
            }
            case AVAssetExportSessionStatusCompleted: {
                CGFloat size = [self getfileSize:[self getWaterVideoFilePath]];
                NSLog(@"%f",size);
                //        NSLog(@"%@",[self createVideoFilePath]);
                ////        1.先自定义一个全局的MPMoviePlayerController 对象
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.mPMoviePlayerController = nil;
                    MPMoviePlayerController *mPMoviePlayerController;
                    //        2.视频的播放
                    mPMoviePlayerController = [[MPMoviePlayerController alloc]initWithContentURL:[NSURL fileURLWithPath:[self getWaterVideoFilePath]]];
                    mPMoviePlayerController.view.frame = CGRectMake(0, 100, 414, 300);
                    mPMoviePlayerController.movieSourceType = MPMovieSourceTypeUnknown;//设置播放的视频为本地文件
                    mPMoviePlayerController.initialPlaybackTime = -1.0f;
                    [mPMoviePlayerController prepareToPlay];
                    [mPMoviePlayerController setShouldAutoplay:YES];
                    [self.view addSubview:mPMoviePlayerController.view];
                    self.mPMoviePlayerController = mPMoviePlayerController;
                });
                
                break;
            }
            case AVAssetExportSessionStatusFailed: {
                
                NSLog(@"failed, error:%@.", exporter.error);
                NSString *path = [self getWaterVideoFilePath];
                NSFileManager *mana = [NSFileManager defaultManager];
                if ([mana fileExistsAtPath:path isDirectory:NO]) {
                    [mana removeItemAtPath:path error:nil];
                }
            }
                
            case AVAssetExportSessionStatusCancelled: {
                
                break;
            }
            default:
                break;
        }
    }];
    
}

-(void)updateProgress{
    
}

- (void)applyVideoEffectsToComposition:(AVMutableVideoComposition *)composition WithWaterImg:(UIImage*)img WithCoverImage:(UIImage*)coverImg WithQustion:(NSString*)question  size:(CGSize)size {
    
    UIFont *font = [UIFont systemFontOfSize:30.0];
    CATextLayer *subtitle1Text = [[CATextLayer alloc] init];
    [subtitle1Text setFontSize:30];
    [subtitle1Text setString:question];
    [subtitle1Text setAlignmentMode:kCAAlignmentCenter];
    [subtitle1Text setForegroundColor:[[UIColor whiteColor] CGColor]];
    subtitle1Text.masksToBounds = YES;
    subtitle1Text.cornerRadius = 23.0f;
    [subtitle1Text setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.5].CGColor];
    CGSize textSize = [question sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:font,NSFontAttributeName, nil]];
    [subtitle1Text setFrame:CGRectMake(50, 100, textSize.width+20, textSize.height+10)];
    
    //水印
    CALayer *imgLayer = [CALayer layer];
    imgLayer.contents = (id)img.CGImage;
    //    imgLayer.bounds = CGRectMake(0, 0, size.width, size.height);
    imgLayer.bounds = CGRectMake(0, 0, 50, 50);
    imgLayer.position = CGPointMake(50, size.height -50);
    
    //第二个水印
    CALayer *coverImgLayer = [CALayer layer];
    coverImgLayer.contents = (id)coverImg.CGImage;
    //    [coverImgLayer setContentsGravity:@"resizeAspect"];
    coverImgLayer.bounds =  CGRectMake(50, 200,50, 50);
    coverImgLayer.position = CGPointMake(50, 50);
    
    // 2 - The usual overlay
    CALayer *overlayLayer = [CALayer layer];
    [overlayLayer addSublayer:subtitle1Text];
    [overlayLayer addSublayer:imgLayer];
    overlayLayer.frame = CGRectMake(0, 0, size.width, size.height);
    [overlayLayer setMasksToBounds:YES];
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:overlayLayer];
    [parentLayer addSublayer:coverImgLayer];
    
    //设置封面
    CABasicAnimation *anima = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anima.fromValue = [NSNumber numberWithFloat:1.0f];
    anima.toValue = [NSNumber numberWithFloat:0.0f];
    anima.repeatCount = 0;
    anima.duration = 5.0f;  //5s之后消失
    [anima setRemovedOnCompletion:NO];
    [anima setFillMode:kCAFillModeForwards];
    anima.beginTime = AVCoreAnimationBeginTimeAtZero;
    [coverImgLayer addAnimation:anima forKey:@"opacityAniamtion"];
    
    composition.animationTool = [AVVideoCompositionCoreAnimationTool
                                 videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
}

#pragma mark -裁剪视频


//-(void)mergeVideoToOneVideo:(NSArray *)tArray toStorePath:(NSString *)storePath WithStoreName:(NSString *)storeName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok
//
//{
//
//    GW(weakSelf)
//
//    AVMutableComposition *mixComposition = [self mergeVideostoOnevideo:tArray success:^(AVMutableComposition* composition){
//
//
//        NSURL *outputFileUrl = [weakSelf joinStorePaht:storePath togetherStoreName:storeName];
//
//        [weakSelf storeAVMutableComposition:composition withStoreUrl:outputFileUrl andVideoUrl:[tArray objectAtIndex:0] WihtName:storeName andIf3D:tbool success:successBlock failure:failureBlcok];
//
//
//
//    } failure:^{
//
//
//
//    }];
//
//
//
//}
//
//
//-(AVMutableComposition *)mergeVideostoOnevideo:(NSArray*)array success:(void (^)(AVMutableComposition* composition))successBlock failure:(void (^)(void))failureBlcok
//
//{
//
//    AVMutableComposition* mixComposition = [AVMutableComposition composition];
//
//    //合成视频轨道
//
//    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//
//    Float64 tmpDuration =0.0f;
//
//
//
//    NSError *error;
//
//
//
//    for (NSInteger i=0; i<array.count; i++)
//
//    {
//
//
//
//        AVURLAsset *videoAsset = [[AVURLAsset alloc]initWithURL:array[i] options:nil];
//
//
//
//        CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,videoAsset.duration);
//
//
//
//        /**
//
//         *  依次加入每个asset
//
//         *
//
//         *  @param TimeRange 加入的asset持续时间
//
//         *  @param Track     加入的asset类型,这里都是video
//
//         *  @param Time      从哪个时间点加入asset,这里用了CMTime下面的CMTimeMakeWithSeconds(tmpDuration, 0),timesacle为0
//
//         *
//
//         */
//
////        BOOL tbool = [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:CMTimeMakeWithSeconds(tmpDuration, 0) error:&error];
//
//        tmpDuration += CMTimeGetSeconds(videoAsset.duration);
//
//
//
//    }
//
//
//
//    if (error == nil) {
//
//        if (successBlock) {
//
//            successBlock(mixComposition);
//
//        }
//
//    }
//
//    else {
//
//        if (failureBlcok) {
//
//            failureBlcok();
//
//        }
//
//    }
//
//
//
//    return mixComposition;
//
//}
//
//-(NSURL *)joinStorePaht:(NSString *)sPath togetherStoreName:(NSString *)sName
//
//{
//
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//
//    NSString *documentPath = [paths objectAtIndex:0];
//
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//
//
//
//    NSString *storePath = [documentPath stringByAppendingPathComponent:sPath];
//
//    BOOL isExist = [fileManager fileExistsAtPath:storePath];
//
//    if(!isExist){
//
//        [fileManager createDirectoryAtPath:storePath withIntermediateDirectories:YES attributes:nil error:nil];
//
//    }
//
//    NSString *realName = [NSString stringWithFormat:@"%@.mp4", sName];
//
//    storePath = [storePath stringByAppendingPathComponent:realName];
//
//    NSURL *outputFileUrl = [NSURL fileURLWithPath:storePath];
//
//    return outputFileUrl;
//
//}
//
//
///**
//
// *  存储合成的视频，以及转mp4格式带压缩
//
// *
//
// *  @param mixComposition mixComposition参数 （ 当其是AVURLAsset类时——仅转码压缩，，AVMutableComposition类时——合并视频,进行的转码压缩同时导出操作 ）
//
// *  @param storeUrl       存储的路径 (完整的url路径)
//
// *  @param successBlock   successBlock
//
// *  @param failureBlcok   failureBlcok
//
// */
//
//-(void)storeAVMutableComposition:(id)mixComposition withStoreUrl:(NSURL *)storeUrl andVideoUrl:(NSURL *)videoUrl WihtName:(NSString *)aName andIf3D:(BOOL)tbool success:(void (^)(void))successBlock failure:(void (^)(void))failureBlcok
//
//{
//
//
//
//    __weak typeof(self) welf = self;
//
//    NSLog(@"操作类型%@", [mixComposition class]);
//
//
//    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]
//
//                                           initWithAsset:mixComposition
//
//                                           presetName:AVAssetExportPresetMediumQuality];
//
//    self.exportSession = exportSession;
//
//
//
//    exportSession.outputURL = storeUrl;
//
//    exportSession.shouldOptimizeForNetworkUse = YES;
//
//    exportSession.outputFileType = AVFileTypeMPEG4;
//
////    dispatch_semaphore_t wait = dispatch_semaphore_create(0l);
//
//    //        [self showHudInView:self.view hint:@"正在压缩"];
//
//    //        __weak typeof(self) weakSelf = self;
//
//
//    [exportSession exportAsynchronouslyWithCompletionHandler:^{
//
//        //            [weakSelf hideHud];
//        dispatch_async(dispatch_get_main_queue(), ^{
//
//            switch ([exportSession status]) {
//
//                case AVAssetExportSessionStatusFailed: {
//
//                    NSLog(@"failed, error:%@.", exportSession.error);
//
//                    if (failureBlcok) {
//
//                        failureBlcok();
//
//                    }
//
//                } break;
//
//                case AVAssetExportSessionStatusCancelled: {
//
//                    NSLog(@"cancelled.");
//
//                } break;
//
//                case AVAssetExportSessionStatusCompleted: {
//
//                    NSLog(@"completed.");
//
//
//                    if (successBlock) {
//
//                        successBlock();
//
//                    }
//
//
//
//                } break;
//
//                case AVAssetExportSessionStatusExporting: {
//
//                    NSLog(@"Exporting");
//
//                }
//
//                    break;
//
//                default: {
//
//                    NSLog(@"others.");
//
//                } break;
//
//            }
////            dispatch_semaphore_signal(wait);
//        });
//
//
//    }];
//
////    long timeout = dispatch_semaphore_wait(wait, DISPATCH_TIME_FOREVER);
////
////    if (timeout) {
////
////        NSLog(@"timeout.");
////
////    }
////
////    if (wait) {
////
////        //dispatch_release(wait);
////
////        wait = nil;
////
////    }
//
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
