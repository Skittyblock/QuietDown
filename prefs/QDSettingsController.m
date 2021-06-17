// QDSettingsController.m

#import "QDSettingsController.h"

@implementation QDSettingsController

- (void)clearMutes {
	[@{@"entries":@[]} writeToFile:@"/var/mobile/Library/QuietDown/config.plist" atomically:YES];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("xyz.skitty.quietdown.prefschanged"), nil, nil, true);

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Muted Apps Cleared" message:@"All previously muted apps have been unmuted." preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
	[alert addAction:okButton];
	[self presentViewController:alert animated:YES completion:nil];
}

@end
