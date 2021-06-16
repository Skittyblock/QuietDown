// QuietDown Preferences

#include "QDRootListController.h"

#define kTintColor [UIColor colorWithRed:0.56 green:0.28 blue:0.96 alpha:1.0]

// Weird hack
@implementation PSTableCell (QuietDown)
- (void)layoutSubviews {
	[super layoutSubviews];
	if (self.type == 13 && [[self _viewControllerForAncestor] isKindOfClass:NSClassFromString(@"QDRootListController")]) {
		self.textLabel.textColor = kTintColor;
	}
}
@end

@implementation QDHeader
- (id)initWithSpecifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];

	if (self) {
		UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 30, self.frame.size.width, 60)];
		title.numberOfLines = 1;
		title.font = [UIFont systemFontOfSize:50];
		title.text = @"QuietDown";
		title.textColor = kTintColor;
		title.textAlignment = NSTextAlignmentCenter;
		[self addSubview:title];

		UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 85, self.frame.size.width, 30)];
		subtitle.numberOfLines = 1;
		subtitle.font = [UIFont systemFontOfSize:20];
		subtitle.text = @"Mute Notifications Better";
		subtitle.textColor = [UIColor grayColor];
		subtitle.textAlignment = NSTextAlignmentCenter;
		[self addSubview:subtitle];
	}

	return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
	return 150.0;
}
@end

@implementation QDRootListController
- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
	self.view.tintColor = kTintColor;
	keyWindow.tintColor = kTintColor;
	[UISwitch appearanceWhenContainedInInstancesOfClasses:@[self.class]].onTintColor = kTintColor;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
	keyWindow.tintColor = nil;
}

- (void)clearMutes {
	[@{@"entries":@[]} writeToFile:@"/var/mobile/Library/QuietDown/config.plist" atomically:YES];
}
@end
