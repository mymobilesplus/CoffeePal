#import "CoffeePalAppDelegate.h"
#import "GLView.h"
#import "ConstantsAndMacros.h"
#import "GLViewController.h"
#import "ViewController.h"
@implementation CoffeePalAppDelegate

@synthesize window;
@synthesize glView;

- (void)applicationDidFinishLaunching:(UIApplication *)application {
 
//	glView.animationInterval = 1.0 / kRenderingFrequency;
//	[glView startAnimation];
//    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
   // self.window.backgroundColor = [UIColor clearColor];
   
    //GLViewController *rootCtr = [[GLViewController alloc] init];
    ViewController *rootCtr = [[ViewController alloc] init];
   // UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootCtr];
   // [rootCtr.view addSubview:glView];
    
    UIStoryboard *storyBoard;

    storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController *initViewController = [storyBoard instantiateInitialViewController];
    [self.window setRootViewController:initViewController];
    //[rootCtr.view addSubView:]
   // [self.window setRootViewController:nav];
    // window.rootViewController = rootCtr;
    
    
    
    // [self.window addSubview:menu];
   // [self.window makeKeyAndVisible];
//    NSArray *windows = [[UIApplication sharedApplication] windows];
//    for(UIWindow *window in windows) {
//        if(window.rootViewController == nil){
//            UIViewController* vc = [[UIViewController alloc]initWithNibName:nil bundle:nil];
//            window.rootViewController = vc;
//        }
//    }
}


- (void)applicationWillResignActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / kInactiveRenderingFrequency;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / 60.0;
}


- (void)dealloc {
	[window release];
	[glView release];
	[super dealloc];
}

@end
