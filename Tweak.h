// QuietDown Headers

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SBIcon : NSObject
- (BOOL)isApplicationIcon;
- (NSString *)applicationBundleID;
- (NSString *)leafIdentifier;
@end

@interface SBIconView : UIView
@property (nonatomic,retain) SBIcon *icon;
@property (nonatomic, retain) UISwipeGestureRecognizer *swipeGesture;
@end

@interface NCNotificationContent : NSObject
@property (nonatomic, retain) NSString *header;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subtitle;
@property (nonatomic, retain) NSString *message;
@property (nonatomic, retain) UIImage *icon;
@property (nonatomic, retain) NSDate *date;
@end

@interface NCNotificationActionRunner <NSObject>
-(void)executeAction:(id)arg1 fromOrigin:(id)arg2 withParameters:(id)arg3 completion:(/*^block*/id)arg4;
@end

@interface NCNotificationAction : NSObject
@property (nonatomic,readonly) NCNotificationActionRunner *actionRunner;
@property (nonatomic, copy, readonly) NSURL *launchURL;
@property (nonatomic, copy, readonly) NSString *launchBundleID;
@end

@interface NCNotificationOptions : NSObject
@property (nonatomic, assign) NSUInteger messageNumberOfLines;
@end

@interface NCNotificationRequest : NSObject
@property (nonatomic, copy, readonly) NSString *sectionIdentifier;
@property (nonatomic, retain) NCNotificationContent *content;
@property (nonatomic, retain) NCNotificationOptions *options;
@property (nonatomic,readonly) NCNotificationAction *defaultAction;
@end

@interface SBUIIconForceTouchIconViewWrapperView : UIView
@property (nonatomic, retain) SBIconView *iconView;
@end

@interface SBUIIconForceTouchViewController : UIViewController
- (void)dismissAnimated:(bool)arg1 withCompletionHandler:(id)arg2;
@end