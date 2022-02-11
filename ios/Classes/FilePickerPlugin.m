#import "FilePickerPlugin.h"
#import "FileUtils.h"

@interface FilePickerPlugin()
@property (nonatomic) FlutterResult result;
@property (nonatomic) FlutterEventSink eventSink;
@property (nonatomic) UIDocumentPickerViewController *documentPickerController;
@property (nonatomic) NSArray<NSString *> * allowedExtensions;
@property (nonatomic) BOOL loadDataToMemory;
@end

@implementation FilePickerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {

    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"miguelruivo.flutter.plugins.filepicker"
                                     binaryMessenger:[registrar messenger]];

    FlutterEventChannel* eventChannel = [FlutterEventChannel
                                         eventChannelWithName:@"miguelruivo.flutter.plugins.filepickerevent"
                                         binaryMessenger:[registrar messenger]];

    FilePickerPlugin* instance = [[FilePickerPlugin alloc] init];

    [registrar addMethodCallDelegate:instance channel:channel];
    [eventChannel setStreamHandler:instance];
}

- (instancetype)init {
    self = [super init];

    return self;
}

- (UIViewController *)viewControllerWithWindow:(UIWindow *)window {
    UIWindow *windowToUse = window;
    if (windowToUse == nil) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                windowToUse = window;
                break;
            }
        }
    }

    UIViewController *topController = windowToUse.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    _eventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    _eventSink = nil;
    return nil;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if (_result) {
        result([FlutterError errorWithCode:@"multiple_request"
                                   message:@"Cancelled by a second request"
                                   details:nil]);
        _result = nil;
        return;
    }

    _result = result;

    if([call.method isEqualToString:@"dir"]) {
        if (@available(iOS 13, *)) {
            [self resolvePickDocumentWithMultiPick:NO pickDirectory:YES];
        } else {
            _result([self getDocumentDirectory]);
            _result = nil;
        }
        return;
    } else {
        result(FlutterMethodNotImplemented);
        _result = nil;
    }
}

- (NSString*)getDocumentDirectory {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return paths.firstObject;
}

#pragma mark - Resolvers
- (void)resolvePickDocumentWithMultiPick:(BOOL)allowsMultipleSelection pickDirectory:(BOOL)isDirectory {

    @try{
        self.documentPickerController = [[UIDocumentPickerViewController alloc]
                                         initWithDocumentTypes: isDirectory ? @[@"public.folder"] : self.allowedExtensions
                                         inMode: isDirectory ? UIDocumentPickerModeOpen : UIDocumentPickerModeImport];
    } @catch (NSException * e) {
        Log(@"Couldn't launch documents file picker. Probably due to iOS version being below 11.0 and not having the iCloud entitlement. If so, just make sure to enable it for your app in Xcode. Exception was: %@", e);
        _result = nil;
        return;
    }

    if (@available(iOS 11.0, *)) {
        self.documentPickerController.allowsMultipleSelection = allowsMultipleSelection;
    } else if(allowsMultipleSelection) {
        Log(@"Multiple file selection is only supported on iOS 11 and above. Single selection will be used.");
    }

    self.documentPickerController.delegate = self;
    self.documentPickerController.presentationController.delegate = self;

    [[self viewControllerWithWindow:nil] presentViewController:self.documentPickerController animated:YES completion:nil];
}

- (void) handleResult:(id) files {
    _result([FileUtils resolveFileInfo: [files isKindOfClass: [NSArray class]] ? files : @[files] withData:self.loadDataToMemory]);
    _result = nil;
}

#pragma mark - Delegates

// DocumentPicker delegate - iOS 10 only
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url{
    [self.documentPickerController dismissViewControllerAnimated:YES completion:nil];
    [self handleResult:url];
}

// DocumentPicker delegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{

    if(_result == nil) {
        return;
    }

    [self.documentPickerController dismissViewControllerAnimated:YES completion:nil];

    if(controller.documentPickerMode == UIDocumentPickerModeOpen) {
        _result([urls objectAtIndex:0].path);
        _result = nil;
        return;
    }

    [self handleResult: urls];
}

#pragma mark - Actions canceled

- (void)presentationControllerDidDismiss:(UIPresentationController *)controller {
    Log(@"FilePicker canceled");
    if (self.result != nil) {
        self.result(nil);
        self.result = nil;
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    Log(@"FilePicker canceled");
    _result(nil);
    _result = nil;
    [controller dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Alert dialog


@end
