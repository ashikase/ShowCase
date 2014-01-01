/**
 * Name: ShowCase
 * Type: iOS SpringBoard extension (MobileSubstrate-based)
 * Desc: Make keyboard show current case.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 *
 * Last-modified: 2014-01-01 21:52:26
 */


#include <objc/runtime.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_5_0
#define kCFCoreFoundationVersionNumber_iOS_5_0 675.00
#endif

// Class declarations
// NOTE: These are not 100% accurate; protocol information has been stripped,
//       and super classes may change between firmware versions.
@interface CPBitmapStore : NSObject
- (void)purge;
@end

@interface UIKeyboardImpl : UIView
+ (id)activeInstance;
@end

@interface UIKeyboardLayout : UIView @end
@interface UIKeyboardLayoutStar : UIKeyboardLayout
@property(copy, nonatomic) NSString *keyplaneName;
@property(assign, nonatomic) BOOL shift;
@end

@interface UIKBKeyplaneView : UIView @end
@interface UIKBShape : NSObject @end
@interface UIKBKey : UIKBShape
@property(copy, nonatomic) NSString *name;
@end

// 4.2.1+
@interface UIKeyboardCache : NSObject
+ (id)sharedInstance;
@end

// 5.0+
@interface UIKBTree : NSObject
@property(copy, nonatomic) NSString *name;
@end

//==============================================================================

// DESC: Use separate cache keys for "small" and "capital" keyplanes.
// NOTE: By default, iOS uses the same key ("small-letters") for both cases.

static BOOL shouldFixCase$ = NO;

%hook UIKBTree %group GFirmware_GTE_50

- (id)shiftAlternateKeyplaneName
{
    // NOTE: While we could simply hook just this method and always convert
    // "small" to "capital", doing so results in the keyboard always showing
    // capital letters.
    // TODO: Determine why the above issue occurs.
    id result = %orig();
    return (shouldFixCase$ && [result isEqualToString:@"small-letters"]) ? @"capital-letters" : result;
}

%end %end

%hook UIKeyboardLayoutStar %group GFirmware_GTE_50

- (id)cachedKeyplaneNameForKeyplane:(id)keyplane
{
    shouldFixCase$ = YES;
    id result = %orig();
    shouldFixCase$ = NO;
    return result;
}

%end %end

%hook UIKBKeyplaneView %group GFirmware_LT_50

- (id)cacheKey
{
    id result = %orig();

    // Get reference to layout in order to determine shift state
    UIKeyboardLayoutStar *layout = nil;
    UIKeyboardImpl *impl = [objc_getClass("UIKeyboardImpl") activeInstance];
    if (impl != nil) {
        layout = MSHookIvar<UIKeyboardLayoutStar *>(impl, "m_layout");
    }

    // If shift is currently enabled, return identifier for uppercase instead of lower.
    return layout.shift ? [result stringByReplacingOccurrencesOfString:@"small" withString:@"capital"] : result;
}

%end %end

//==============================================================================

// DESC: If key represents a lowercase letter, then actually return a lowercase
//       letter.

%hook KBKeyTree %group GHonorCase

- (NSString *)displayString
{
    NSString *result = %orig();
    return [[self name] rangeOfString:@"-Small-"].location != NSNotFound ? [result lowercaseString] : result;
}

%end %end

//==============================================================================

// DESC: Force redraw of keyboard when keyplane name changes (e.g., from "small"
//       to "capital").
// NOTE: This does not appear to be necessary in iOS version 5.0 ~ 6.1.x.
// TODO: Determine why this is once again necessary in 7.0.

static inline void updateKeyplaneView(id object)
{
    UIKBKeyplaneView *_keyplaneView = NULL;
    if (object_getInstanceVariable(object, "_keyplaneView", (void **)&_keyplaneView) == NULL) {
        object_getInstanceVariable(object, "m_keyplaneView", (void **)&_keyplaneView);
    }
    [_keyplaneView setNeedsDisplay];
}

%hook UIKeyboardLayoutStar

- (void)setKeyplaneName:(id)name
{
    NSString *oldName = self.keyplaneName;

    %orig();

    // If keyplane name changed, force a redraw
    if (name != nil && ![name isEqualToString:oldName]) {
        updateKeyplaneView(self);
    }
}

%end

//==============================================================================

// DESC: Clear the keyboard cache to remove any old images that display all
//       capital letters for lowercase (i.e., images that either existed before
//       installation of this extension or were generated while in Safe Mode).
// NOTE: Cache path for keyboard images is:
//       /var/mobile/Library/Caches/com.apple.keyboard/images

%hook SpringBoard %group GSpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig();

    Class $UIKeyboardCache = objc_getClass("UIKeyboardCache");
    if ($UIKeyboardCache != nil) {
        UIKeyboardCache *cache = [$UIKeyboardCache sharedInstance];
        CPBitmapStore *_store = MSHookIvar<id>(cache, "_store");
        [_store purge];
    }
}

%end %end

//==============================================================================

%ctor
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Setup hooks
    %init;

    // Setup firmware-dependent hooks
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_5_0) {
        %init(GFirmware_GTE_50);
    } else {
        %init(GFirmware_LT_50);
    }
    Class $KBKeyTree = (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_5_0) ?
        %c(UIKBTree) : %c(UIKBKey);
    %init(GHonorCase, KBKeyTree = $KBKeyTree);

    // Setup app-dependent hooks
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        %init(GSpringBoard);
    }

    [pool release];
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */