// QuietDown, by Skitty
// Mute notifications per app for periods of time

#import "Tweak.h"

static NSDictionary *settings;
static bool enabled;
static bool forceTouch;
static bool swipeUp;
static bool banners;
static bool coverSheet;

static NSString *configPath = @"/var/mobile/Library/QuietDown/config.plist";
static NSMutableDictionary *config;

// Preference Updates
static void refreshPrefs() {
  CFArrayRef keyList = CFPreferencesCopyKeyList(CFSTR("xyz.skitty.quietdown"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  if(keyList) {
    settings = (NSMutableDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, CFSTR("xyz.skitty.quietdown"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
    CFRelease(keyList);
  } else {
    settings = nil;
  }
  if (!settings) {
    settings = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/xyz.skitty.quietdown.plist"];
  }
  if (!config) {
    config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
  }

  enabled = [([settings objectForKey:@"enabled"] ?: @(YES)) boolValue];
  int mode = [([settings objectForKey:@"mode"] ?: 0) floatValue];
  if (mode == 0) {
    forceTouch = NO;
    swipeUp = YES;
  } else {
    forceTouch = YES;
    swipeUp = NO;
  }
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
  NSMutableArray *entries = [config[@"entries"] mutableCopy];
  bool add = YES;
  NSDictionary *remove = nil;
  for (NSMutableDictionary *entry in entries) {
    if ([entry[@"id"] isEqual:bundleID]) {
      if (interval < 0) {
        entry[@"timeStamp"] = @(-1);
      } else if (interval == 0) {
        remove = entry;
      } else {
        entry[@"timeStamp"] = @([[NSDate date] timeIntervalSince1970] + interval);
      }
      add = NO;
    }
  }
  if (remove) {
    [entries removeObject:remove];
  }
  if (add) {
    NSDictionary *info;
    if (interval < 0) {
      info = @{@"id": bundleID, @"timeStamp":  @(-1)};
    } else if (interval != 0) {
      info = @{@"id": bundleID, @"timeStamp": @([[NSDate date] timeIntervalSince1970] + interval)}; // 1 minute test
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
    if ([request.sectionIdentifier isEqualToString:entry[@"id"]] && (interval < [entry[@"timeStamp"] intValue] || [entry[@"timeStamp"] intValue] == -1)) {
      stop = YES;
    } else if (interval > [entry[@"timeStamp"] intValue] && [entry[@"timeStamp"] intValue] != -1) {
      [removeObjects addObject:entry];
    }
  }
  if (removeObjects) {
    [config[@"entries"] removeObjectsInArray:removeObjects];
    [config writeToFile:configPath atomically:YES];
  }
  return stop;
}

%group Tweak
// Add menu observer
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
  %orig;
  config = [NSMutableDictionary dictionaryWithContentsOfFile:configPath];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showMuteMenu:) name:@"xyz.skitty.quietdown.menu" object:nil];
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
  for (NSDictionary *entry in (NSArray *)config[@"entries"]) {
    if ([entry[@"id"] isEqualToString:bundleID]) {
      if ([[NSDate date] timeIntervalSince1970] < [entry[@"timeStamp"] intValue] || [entry[@"timeStamp"] intValue] == -1) {
        muted = YES;
      }
    }
  }
  if (muted) {
    [alert addAction:[UIAlertAction actionWithTitle:@"Unmute" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      processEntry(bundleID, 0);
    }]];
  } else {
    [alert addAction:[UIAlertAction actionWithTitle:@"Forever" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      processEntry(bundleID, -1);
    }]];
  }

  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}
%end

// Replace force touch
%hook SBUIIconForceTouchViewController
- (void)_presentAnimated:(BOOL)arg1 withCompletionHandler:(void (^)())arg2 {
  SBUIIconForceTouchIconViewWrapperView *wrapperView = MSHookIvar<SBUIIconForceTouchIconViewWrapperView *>(self, "_iconViewWrapperViewAbove");
  NSString *bundleID = [wrapperView.iconView.icon applicationBundleID];
  if (enabled && forceTouch && bundleID && [wrapperView respondsToSelector:@selector(iconView)]) {
    arg2();
    [self dismissAnimated:YES withCompletionHandler:nil];
    NSDictionary *info = @{@"id": bundleID};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"xyz.skitty.quietdown.menu" object:nil userInfo:info];
  } else {
    %orig;
  }
}
%end

// Add swipe up gesture
%hook SBIconView
%property (nonatomic, retain) UISwipeGestureRecognizer *swipeGesture;
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"xyz.skitty.quietdown.menu" object:nil userInfo:info];
  }
}
%end

// Mute Lock Screen notifications
// Could also use NCNotificationCombinedListViewController, SBDashBoardCombinedListViewController, or SBDashBoardMainPageContentViewController. They all do the same thing.
%hook SBDashBoardNotificationDispatcher
- (void)postNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)arg2 {
  if (coverSheet && shouldStopRequest(request)) {
    return;
  }
  %orig;
}
%end

%hook SBNCScreenController
- (void)turnOnScreenForNotificationRequest:(NCNotificationRequest *)request {
  if (coverSheet && shouldStopRequest(request)) {
    return;
  }
  %orig;
}
%end

%hook SBNCSoundController
- (void)playSoundForNotificationRequest:(NCNotificationRequest *)request {
  if (coverSheet && shouldStopRequest(request)) {
    return;
  }
  %orig;
}
%end

// Mute banner notifications
%hook SBNotificationBannerDestination
- (void)_postNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)arg2 modal:(bool)arg3 sourceAction:(id)arg4 completion:(id)arg5 {
  if (banners && shouldStopRequest(request)) {
    return;
  }
  %orig;
}
%end
%end

%ctor {
  refreshPrefs();
  CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, CFSTR("xyz.skitty.quietdown.prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

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
