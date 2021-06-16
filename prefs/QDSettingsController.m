// QDSettingsController.m

#import "QDSettingsController.h"

@implementation QDSettingsController

- (void)clearMutes {
	[@{@"entries":@[]} writeToFile:@"/var/mobile/Library/QuietDown/config.plist" atomically:YES];
}

@end
