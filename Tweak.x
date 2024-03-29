// QuietDown, by Skitty
// Mute notifications per app for periods of time

#import <rootless.h>
#import "Tweak.h"

#define BUNDLE_ID @"xyz.skitty.quietdown"

static NSDictionary *settings;
static bool enabled;
static bool forceTouch;
static bool swipeUp;
static bool banners;
static bool coverSheet;

static NSString *configPath = ROOT_PATH_NS(@"/var/mobile/Library/QuietDown/config.plist");
static NSMutableDictionary *config;

// Preference Updates
static void refreshPrefs() {
	CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keyList) {
		settings = (NSMutableDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, (CFStringRef)BUNDLE_ID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
		CFRelease(keyList);
	} else {
		settings = nil;
	}
	if (!settings) {
		settings = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:ROOT_PATH_NS(@"/var/mobile/Library/Preferences/%@.plist"), BUNDLE_ID]];
	}
	config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];

	enabled = [([settings objectForKey:@"enabled"] ?: @(YES)) boolValue];
	forceTouch = [([settings objectForKey:@"forceTouch"] ?: @(YES)) boolValue];
	swipeUp = [([settings objectForKey:@"swipeUp"] ?: @(NO)) boolValue];
	int type = [([settings objectForKey:@"type"] ?: 0) floatValue];
	if (type == 0) {
		banners = YES;
		coverSheet = NO;
	} else if (type == 1) {
		banners = NO;
		coverSheet = YES;
	} else {
		banners = YES;
		coverSheet = YES;
	}
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	refreshPrefs();
}

// Return config dictionary with added (or removed) entry
static void processEntry(NSString *bundleID, double interval) {
	if (!config) config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
	if (!config[@"entries"]) config[@"entries"] = @[];
	NSMutableArray *entries = [config[@"entries"] mutableCopy];
	bool add = YES;
	for (int i = 0; i < entries.count; i++) {
		if ([entries[i][@"id"] isEqual:bundleID]) {
			NSMutableDictionary *entry = [entries[i] mutableCopy];
			if (interval < 0) {
				entry[@"timeStamp"] = @(-1);
			} else if (interval == 0) {
				[entries removeObjectAtIndex:i];
				break;
			} else {
				entry[@"timeStamp"] = @([[NSDate date] timeIntervalSince1970] + interval);
			}
			add = NO;
			[entries replaceObjectAtIndex:i withObject:entry];
			break;
		}
	}
	if (add) {
		NSDictionary *info;
		if (interval < 0) {
			info = @{@"id": bundleID, @"timeStamp":  @(-1)};
		} else if (interval != 0) {
			info = @{@"id": bundleID, @"timeStamp": @([[NSDate date] timeIntervalSince1970] + interval)};
		}
		if (info) {
			[entries addObject:info];
		}
	}
	[config setValue:entries forKey:@"entries"];
	[config writeToFile:configPath atomically:YES];
}

// Stop notification requests
static bool shouldStopRequest(NCNotificationRequest *request) {
	bool stop = NO;
	NSMutableArray *removeObjects = [[NSMutableArray alloc] init];
	for (NSDictionary *entry in (NSArray *)config[@"entries"]) {
		int interval = [[NSDate date] timeIntervalSince1970];
		int timeStamp = [entry[@"timeStamp"] intValue];
		if ([request.sectionIdentifier isEqualToString:entry[@"id"]] && (interval < timeStamp || timeStamp == -1)) {
			stop = YES;
		} else if (interval > timeStamp && timeStamp != -1) {
			[removeObjects addObject:entry];
		}
	}
	if (removeObjects) {
		[config[@"entries"] removeObjectsInArray:removeObjects];
		[config writeToFile:configPath atomically:YES];
	}
	return stop;
}

static NSString *timeStringFromInterval(NSTimeInterval seconds) {
	NSString *s = @"s";
	if (seconds == 0) return @"";
	if (floorf(seconds) == 1) s = @"";
	if (seconds < 60) return [NSString stringWithFormat:@"%.ld second%@", (long)seconds, s];

	long minutes = seconds / 60;
	seconds -= minutes * 60;
	if (minutes < 60)  return [NSString stringWithFormat:@"%ld:%02ld", minutes, (long)seconds];   

	long hours = minutes / 60;
	minutes -= hours * 60;
	return [NSString stringWithFormat:@"%ld:%02ld:%02ld", hours, minutes, (long)seconds];   
}

%group Tweak
// Add menu observer
%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
	%orig;
	config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showMuteMenu:) name:[NSString stringWithFormat:@"%@.menu", BUNDLE_ID] object:nil];
}

%new
- (void)showMuteMenu:(NSNotification *)notification {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mute notifications" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	NSString *bundleID = notification.userInfo[@"id"];

	[alert addAction:[UIAlertAction actionWithTitle:@"For 15 Minutes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		processEntry(bundleID, 900);
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"For 1 Hour" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		processEntry(bundleID, 3600);
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"For 8 Hours" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		processEntry(bundleID, 28800);
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"For 1 Day" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		processEntry(bundleID, 86400);
	}]];

	bool muted = NO;
	NSTimeInterval mutedFor = 0;
	for (NSDictionary *entry in (NSArray *)config[@"entries"]) {
		if ([entry[@"id"] isEqualToString:bundleID]) {
			if ([[NSDate date] timeIntervalSince1970] < [entry[@"timeStamp"] intValue]) {
				muted = YES;
				mutedFor = [entry[@"timeStamp"] intValue] - [[NSDate date] timeIntervalSince1970];
			} else if ([entry[@"timeStamp"] intValue] == -1) {
				muted = YES;
			}
		}
	}
	if (muted) {
		[alert addAction:[UIAlertAction actionWithTitle:@"Unmute" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			processEntry(bundleID, 0);
		}]];
		if (mutedFor > 0) {
			// NSDictionary *map = timeMapFromInterval(mutedFor);
			NSString *timeLeftString = timeStringFromInterval(mutedFor);
			alert.message = [NSString stringWithFormat:@"Currently muted for %@", timeLeftString];
		} else {
			alert.message = @"Currently muted indefinitely";
		}
	} else {
		[alert addAction:[UIAlertAction actionWithTitle:@"Forever" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			processEntry(bundleID, -1);
		}]];
	}

	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

%end

// Force touch menu shortcut (iOS 11-12)
%hook SBUIAppIconForceTouchControllerDataProvider

- (NSArray *)applicationShortcutItems {
	NSArray *orig = %orig;

	if (enabled && forceTouch) {
		SBSApplicationShortcutItem *muteOptionsShortcut = [[%c(SBSApplicationShortcutItem) alloc] init];

		muteOptionsShortcut.localizedTitle = @"Mute Options";
		muteOptionsShortcut.bundleIdentifierToLaunch = [self applicationBundleIdentifier];
		muteOptionsShortcut.type = [NSString stringWithFormat:@"%@.shortcut", BUNDLE_ID];

		return [orig arrayByAddingObject:muteOptionsShortcut];
	}

	return %orig;
}

%end

%hook SBUIAppIconForceTouchController
- (void)appIconForceTouchShortcutViewController:(id)arg1 activateApplicationShortcutItem:(SBSApplicationShortcutItem *)item {
	if ([[item type] isEqualToString:[NSString stringWithFormat:@"%@.shortcut", BUNDLE_ID]]) {
		NSDictionary *info = @{@"id": item.bundleIdentifierToLaunch};
		[[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@.menu", BUNDLE_ID] object:nil userInfo:info];
	} else {
		%orig;
	}
}
%end

%hook SBIconView
%property (nonatomic, retain) UISwipeGestureRecognizer *swipeGesture;

// Force touch menu shortcut (iOS 13+)
- (NSArray *)applicationShortcutItems {
	NSArray *orig = %orig;

	if (enabled && forceTouch) {
		SBSApplicationShortcutItem *muteOptionsShortcut = [[%c(SBSApplicationShortcutItem) alloc] init];

		muteOptionsShortcut.localizedTitle = @"Mute Options";
		muteOptionsShortcut.type = [NSString stringWithFormat:@"%@.shortcut", BUNDLE_ID];

		return [orig arrayByAddingObject:muteOptionsShortcut];
	}

	return %orig;
}

+ (void)activateShortcut:(SBSApplicationShortcutItem *)item withBundleIdentifier:(NSString*)bundleID forIconView:(id)iconView {
	if ([[item type] isEqualToString:[NSString stringWithFormat:@"%@.shortcut", BUNDLE_ID]]) {
		NSDictionary *info = @{@"id": bundleID};
		[[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@.menu", BUNDLE_ID] object:nil userInfo:info];
	} else {
		%orig;
	}
}

// Add swipe up gesture
- (void)setLocation:(long long)arg1 {
	%orig;
	if (!self.swipeGesture) {
		self.swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedUp:)];
		self.swipeGesture.direction = UISwipeGestureRecognizerDirectionUp;
		[self addGestureRecognizer:self.swipeGesture];
	}
}

%new
- (void)swipedUp:(UISwipeGestureRecognizer *)recognizer {
	NSString *bundleID = [self.icon applicationBundleID];
	if (bundleID && swipeUp) {
		NSDictionary *info = @{@"id": bundleID};
		[[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@.menu", BUNDLE_ID] object:nil userInfo:info];
	}
}

%end

// Mute Lock Screen notifications
%hook SBDashBoardNotificationDispatcher
// iOS 11-12
- (void)postNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
	if (coverSheet && shouldStopRequest(request)) return;
	%orig;
}

%end

%hook CSNotificationDispatcher
// iOS 13+
- (void)postNotificationRequest:(NCNotificationRequest *)request {
	if (coverSheet && shouldStopRequest(request)) return;
	%orig;
}

%end

%hook SBNCScreenController

- (void)turnOnScreenForNotificationRequest:(NCNotificationRequest *)request {
	if (coverSheet && shouldStopRequest(request)) return;
	%orig;
}

%end

%hook SBNCSoundController
// iOS 11-12
- (void)playSoundForNotificationRequest:(NCNotificationRequest *)request {
	if (coverSheet && shouldStopRequest(request) && [self _isDeviceUILocked]) return;
	%orig;
}
// iOS 13+
- (void)playSoundForNotificationRequest:(NCNotificationRequest *)request presentingDestination:(id)destination {
	if (coverSheet && shouldStopRequest(request) && [self _isDeviceUILocked]) return;
	%orig;
}

%end

// Mute banner notifications
%hook SBNotificationBannerDestination
// iOS 11-12
- (void)_postNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification modal:(bool)modal sourceAction:(id)sourceAction completion:(id)completion {
	if (banners && shouldStopRequest(request)) return;
	%orig;
}
// iOS 13+
- (void)_postNotificationRequest:(NCNotificationRequest *)request modal:(BOOL)modal completion:(id)completion {
	if (banners && shouldStopRequest(request)) return;
	%orig;
}

%end
%end

%ctor {
	refreshPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, (CFStringRef)[NSString stringWithFormat:@"%@.prefschanged", BUNDLE_ID], NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:[NSNumber numberWithInt:501] forKey:NSFileOwnerAccountID];
	[attributes setObject:[NSNumber numberWithInt:501] forKey:NSFileGroupOwnerAccountID];

	NSFileManager *manager = [NSFileManager defaultManager];

	if (![manager fileExistsAtPath:configPath]) {
		if(![manager fileExistsAtPath:configPath.stringByDeletingLastPathComponent isDirectory:nil]) {
			[manager createDirectoryAtPath:configPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:attributes error:NULL];
		}
		[manager createFileAtPath:configPath contents:nil attributes:attributes];
		[@{@"entries":@[]} writeToFile:configPath atomically:YES];
	}

	if (enabled) {
		%init(Tweak);
	}
}
