
//
//  ViewController.m
//  MQTTChat
//
//  Created by Christoph Krey on 12.07.15.
//  Copyright (c) 2015-2016 Owntracks. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "ViewController.h"
#import "ChatCell.h"
#import "CoffeePalAppDelegate.h"
#import "GLView.h"
#import "ConstantsAndMacros.h"
#import "GLViewController.h"
#import "ViewController.h"
// calculate the size of 'output' buffer required for a 'input' buffer of length x during Base64 decoding operation
#define B64DECODE_OUT_SAFESIZE(x) (((x)*3)/4)

@interface ViewController ()
/*
 * MQTTClient: keep a strong reference to your MQTTSessionManager here
 */
@property (strong, nonatomic) MQTTSessionManager *manager;


@property (strong, nonatomic) NSDictionary *mqttSettings;
@property (strong, nonatomic) NSMutableArray *chat;
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UITextField *message;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSString *base;
@property (weak, nonatomic) IBOutlet UIButton *connect;
@property (weak, nonatomic) IBOutlet UIButton *disconnect;


@property (retain, nonatomic) IBOutlet UIButton *play;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSURL *mqttPlistUrl = [bundleURL URLByAppendingPathComponent:@"mqtt.plist"];
    self.mqttSettings = [NSDictionary dictionaryWithContentsOfURL:mqttPlistUrl];
    self.base = self.mqttSettings[@"base"];
    
    self.chat = [[NSMutableArray alloc] init];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.estimatedRowHeight = 150;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.message.delegate = self;
   
    /*
     * MQTTClient: create an instance of MQTTSessionManager once and connect
     * will is set to let the broker indicate to other subscribers if the connection is lost
     */
    if (!self.manager) {
        self.manager = [[MQTTSessionManager alloc] init];
        self.manager.delegate = self;
        self.manager.subscriptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:MQTTQosLevelExactlyOnce]
                                                                 forKey:[NSString stringWithFormat:@"%@/#", self.base]];
        [self.manager connectTo:self.mqttSettings[@"host"]
                           port:[self.mqttSettings[@"port"] intValue]
                            tls:[self.mqttSettings[@"tls"] boolValue]
                      keepalive:60
                          clean:true
                           auth:false
                           user:nil
                           pass:nil
                      willTopic:[NSString stringWithFormat:@"%@/%@-%@",
                                 self.base,
                                 [UIDevice currentDevice].name,
                                 self.tabBarItem.title]
                           will:[@"offline" dataUsingEncoding:NSUTF8StringEncoding]
                        willQos:MQTTQosLevelExactlyOnce
                 willRetainFlag:FALSE
                   withClientId:nil];
    } else {
        [self.manager connectToLast];
    }
    
    /*
     * MQTTCLient: observe the MQTTSessionManager's state to display the connection status
     */
    
    [self.manager addObserver:self
                   forKeyPath:@"state"
                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                      context:nil];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    switch (self.manager.state) {
        case MQTTSessionManagerStateClosed:
            self.status.text = @"closed";
            self.disconnect.enabled = false;
            self.connect.enabled = false;
            break;
        case MQTTSessionManagerStateClosing:
            self.status.text = @"closing";
            self.disconnect.enabled = false;
            self.connect.enabled = false;
            break;
        case MQTTSessionManagerStateConnected:
            self.status.text = [NSString stringWithFormat:@"connected as %@-%@",
                                [UIDevice currentDevice].name,
                                self.tabBarItem.title];
            self.disconnect.enabled = true;
            self.connect.enabled = false;
            [self.manager sendData:[@"joins chat" dataUsingEncoding:NSUTF8StringEncoding]
                             topic:[NSString stringWithFormat:@"%@/%@-%@",
                                    self.base,
                                    [UIDevice currentDevice].name,
                                    self.tabBarItem.title]
                               qos:MQTTQosLevelExactlyOnce
                            retain:FALSE];

            break;
        case MQTTSessionManagerStateConnecting:
            self.status.text = @"connecting";
            self.disconnect.enabled = false;
            self.connect.enabled = false;
            break;
        case MQTTSessionManagerStateError:
            self.status.text = @"error";
            self.disconnect.enabled = false;
            self.connect.enabled = false;
            break;
        case MQTTSessionManagerStateStarting:
        default:
            self.status.text = @"not connected";
            self.disconnect.enabled = false;
            self.connect.enabled = true;
            break;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (IBAction)clear:(id)sender {
    [self.chat removeAllObjects];
    [self.tableView reloadData];
}
- (IBAction)connect:(id)sender {
    /*
     * MQTTClient: connect to same broker again
     */
    
    [self.manager connectToLast];
}

- (IBAction)disconnect:(id)sender {
    /*
     * MQTTClient: send goodby message and gracefully disconnect
     */
    [self.manager sendData:[@"leaves chat" dataUsingEncoding:NSUTF8StringEncoding]
                     topic:[NSString stringWithFormat:@"%@/%@-%@",
                            self.base,
                            [UIDevice currentDevice].name,
                            self.tabBarItem.title]
                       qos:MQTTQosLevelExactlyOnce
                    retain:FALSE];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [self.manager disconnect];
}

- (IBAction)send:(id)sender {
    /*
     * MQTTClient: send data to broker
     */
    UIImage  *em = [UIImage imageNamed:@"EasternMed"];
    NSData *imageData = UIImagePNGRepresentation(em);
    NSString * base64String = [imageData base64EncodedStringWithOptions:0];
   // [self.manager sendData:[self.message.text dataUsingEncoding:NSUTF8StringEncoding]
   // if (B64DECODE_OUT_SAFESIZE(base64String.length) < 1444) {
    if (self.message.text.length < 30) {
        [self.manager sendData:[@"arab" dataUsingEncoding:NSUTF8StringEncoding]

                            topic:[NSString stringWithFormat:@"%@/%@-%@",
                                   self.base,
                                   [UIDevice currentDevice].name,
                                   self.tabBarItem.title]
                              qos:MQTTQosLevelExactlyOnce
                           retain:FALSE];
    }
    else {
     [self.manager sendData:[base64String dataUsingEncoding:NSUTF8StringEncoding]

                     topic:[NSString stringWithFormat:@"%@/%@-%@",
                            self.base,
                            [UIDevice currentDevice].name,
                            self.tabBarItem.title]
                       qos:MQTTQosLevelExactlyOnce
                    retain:FALSE];
    }
}



- (UIImage *)decodeBase64ToImage:(NSString *)strEncodeData {
  NSData *data = [[NSData alloc]initWithBase64EncodedString:strEncodeData options:NSDataBase64DecodingIgnoreUnknownCharacters];
  return [UIImage imageWithData:data];
}

/*
 * MQTTSessionManagerDelegate
 */
- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    /*
     * MQTTClient: process received message
     */
      
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (dataString.length > 10){
        _imageReceived = [[UIImage alloc]init];
        NSString *prependFormatString =  @"data:image/png;base64,";
        NSString *finalString = [prependFormatString stringByAppendingString:dataString];
        NSURL *url = [NSURL URLWithString:finalString];
        NSData *imageData = [NSData dataWithContentsOfURL:url];
        _imageReceived = [UIImage imageWithData:imageData];
        dataString = nil;

    }
    NSString *senderString = [topic substringFromIndex:self.base.length + 1];
    
    [self.chat insertObject:[NSString stringWithFormat:@"%@:\n%@", senderString, dataString] atIndex:0];
    [self.tableView reloadData];
}

/*
 * UITableViewDelegate
 */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 150;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"line"];
    
   
    //cell.imageHolder.frame = CGRectMake(50.0f, 50.0f, 200.0f, 50.0f);
    cell.textView.text = @"nuk e di"; //self.chat[indexPath.row];//
    UIImageView *iv = [UIImageView new];
    iv.frame = CGRectMake(50.0f, 50.0f, 200.0f, 50.0f);
    iv.backgroundColor = UIColor.clearColor;
    
    iv.image = [self blurredImageWithImage : _imageReceived];
    //cell.imageHolder.image =  [UIImage imageNamed:@"EasternMed"]; //_imageReceived;
   // cell.imageHolder.frame = CGRectMake(cell.frame.origin.x, cell.frame.origin.y, cell.frame.size.width, 100);
    [cell.contentView addSubview: iv];
    return cell;
}

/*
 * UITableViewDataSource
 */

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chat.count;
}


//marin added blurredimage
- (UIImage *)blurredImageWithImage:(UIImage *)sourceImage{
    
    //  Create our blurred image
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:sourceImage.CGImage];
    
    //  Setting up Gaussian Blur
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:15.0f] forKey:@"inputRadius"];
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    
    /*  CIGaussianBlur has a tendency to shrink the image a little, this ensures it matches
     *  up exactly to the bounds of our original image */
    CGImageRef cgImage = [context createCGImage:result fromRect:[inputImage extent]];
   
    UIImage *retVal = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return retVal;
}

- (IBAction)play:(id)sender {
    
    GLViewController *rootCtr = [[GLViewController alloc] init];
    GLView *glView = (GLView*)rootCtr.view;
    glView.backgroundColor = UIColor.greenColor;
    [self.navigationController pushViewController:rootCtr animated:YES];
   
//    [self.navigationController popViewControllerAnimated:YES];
////   GLViewController *rootCtr = [[GLViewController alloc] init];
////                 GLView *glView = [[GLView alloc] init];
////                 glView.animationInterval = 1.0 / kRenderingFrequency;
////
//
//
////             [glView startAnimation];
//////             [rootCtr.view addSubview:glView];
//        //    UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
////          //  UIWindow* window = [[UIApplication sharedApplication] keyWindow];
////
////      // [self.view addSubview:glView];
////           //self.dealloc;
////      [window.rootViewController.view addSubview: glView];
//
//   /* ***/
//    CoffeePalAppDelegate *appDelegate=(CoffeePalAppDelegate *)[[UIApplication sharedApplication]delegate];
//
//    appDelegate.glView.animationInterval = 1.0 / kRenderingFrequency;
//    [appDelegate.glView startAnimation];
//     //GLViewController *glViewController = [[GLViewController alloc] init];
//    GLViewController *rootCtr = [[GLViewController alloc] init];
//    GLView *glView = [[[NSBundle mainBundle] loadNibNamed:@"GLView" owner:self options:nil] objectAtIndex:0];
//
//    rootCtr.view.backgroundColor = UIColor.greenColor;
//    glView.backgroundColor = UIColor.greenColor;
//    glView.layer.zPosition = FLT_MAX;
//    [self presentViewController:rootCtr animated:NO completion:nil];
    
//    [rootCtr.view addSubview:glView];
//    [rootCtr.view addSubview:glView];
//    window.rootViewController = rootCtr;
   // AddTaskViewController *add = [[AddTaskViewController alloc] initWithNibName:@"AddTaskView" bundle:nil];
//   dispatch_async(dispatch_get_main_queue(), ^{
//      [self dismissViewControllerAnimated:YES completion:^{
//       [self presentViewController:rootCtr animated:YES completion:nil];
//
//          appDelegate.window.rootViewController = rootCtr;
//          }];
//   });
    
      
        // [appDelegate.window addSubview:menu];
      
//        NSArray *windows = [[UIApplication sharedApplication] windows];
//        for(UIWindow *window in windows) {
//            [[UIApplication sharedApplication].windows enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UIWindow *window, NSUInteger idx, BOOL *stop) {
//                   if([window isKindOfClass:[UIWindow class]] && window.windowLevel == UIWindowLevelNormal) {
//                       [window makeKeyWindow];
//                       *stop = YES;
//                       NSString *viewControllerName = NSStringFromClass([self class]);
//                      NSLog(viewControllerName);
//                      //[self removeFromSuperview];
//                      if(window.rootViewController == nil   ){
//                           window.hidden = true;
//                          UIViewController* vc = rootCtr;
//                          appDelegate.window.rootViewController = vc;
//                            [appDelegate.window makeKeyAndVisible];
//                      }
//                      else if ( [viewControllerName isEqualToString:@"ViewController"]  ){
//                          //NSLog(windows.count);
//                          dispatch_async(dispatch_get_main_queue(), ^{
//                             // window.hidden = true;
////                                                         UIViewController* vc = rootCtr;
////                                                                        appDelegate.window.rootViewController = vc;
////                                                                          [appDelegate.window makeKeyAndVisible];
////                              GLViewController *vc = [[GLViewController alloc] init];
//                              GLViewController *vc = [[GLViewController alloc] initWithNibName:@"MainWindow" bundle:nil];
//
//                              glView.backgroundColor = UIColor.greenColor;
//                              glView.layer.zPosition = FLT_MAX;
////                            appDelegate.window.rootViewController = vc;
//                           [appDelegate.window makeKeyAndVisible];
//                          });
//
//                      }
//                   }
//               }];
//           // NSString *CurrentSelectedCViewController = NSStringFromClass([[((UINavigationController *)viewController1) visibleViewController] class]);
//
//        }
    
  
}


- (void)dealloc {
    [_play release];
    [super dealloc];
}
@end
