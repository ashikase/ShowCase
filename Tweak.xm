/**
 * Name: ShowCase
 * Type: iOS SpringBoard extension (MobileSubstrate-based)
 * Desc: Make keyboard show current case.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 *
 * Last-modified: 2014-01-01 22:53:17
 */


#include <objc/runtime.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_5_0
#define kCFCoreFoundationVersionNumber_iOS_5_0 675.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_6_0
#define kCFCoreFoundationVersionNumber_iOS_6_0 793.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#endif

// Class declarations
// NOTE: These are not 100% accurate; protocol information has been stripped,
//       and super classes may change between firmware versions.
@interface CPBitmapStore : NSObject
- (void)purge;
@end

@interface UIKBShape : NSObject @end
@interface UIKBKey : UIKBShape
@property(copy, nonatomic) NSString *name;
@end

@interface UIKBKeyplane : NSObject
- (BOOL)isShiftKeyplane;
@end

@interface UIKBKeyplaneView : UIView
@property(retain, nonatomic) UIKBKeyplane *keyplane;
@end

@interface UIKeyboardLayout : UIView @end
@interface UIKeyboardLayoutStar : UIKeyboardLayout
@property(copy, nonatomic) NSString *keyplaneName;
@end

// 4.2.1+
@interface UIKeyboardCache : NSObject
+ (id)sharedInstance;
@end

// 5.0+
@interface UIKBTree : NSObject
@property(copy, nonatomic) NSString *name;
- (BOOL)isShiftKeyplane;
@end

//==============================================================================

// DESC: On iOS 6.x, a bug existed with ShowCase which caused the Notes app to
//       crash in certain cases, resulting in an all-black keyboard afterwards.
// NOTE: With this code in place, overriding cacheKey and setKeyplaneName: is
//       technically not needed.
// TODO: Determine the cause of this issue, provide a better fix.

// NOTE: To reproduce the issue (when the following code is not present):
//       1. Open Notes, create a new note with the word (for example) "Test".
//       2. Respring.
//       3. Open Notes, immediately tap the note to bring up the keyboard.
//       4. Immediately tap the shift key.

static BOOL shouldFixCase$ = NO;

%hook UIKBTree %group GFirmware_GTE_60_LT_70

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

%hook UIKeyboardLayoutStar %group GFirmware_GTE_60_LT_70

- (id)cachedKeyplaneNameForKeyplane:(id)keyplane
{
    shouldFixCase$ = YES;
    id result = %orig();
    shouldFixCase$ = NO;
    return result;
}

%end %end

//==============================================================================

// DESC: Use separate cache keys for "small" and "capital" keyplanes.
// NOTE: By default, iOS uses the same key ("small-letters") for both cases.

// NOTE: While iOS 3.1 contains this method (as well as UIKeyboardCache), it
//       appears that it is not actually used until a later iOS version.
// TODO: Determine from which iOS version this is actually used.

%hook UIKBKeyplaneView

- (NSString *)cacheKey
{
    NSString *result = %orig();
    if ([[self keyplane] isShiftKeyplane]) {
        // iOS 4.2.1, 7.0.4
        result = [result stringByReplacingOccurrencesOfString:@"Small" withString:@"Capital"];

        // iOS 5.1.1, 6.1.2
        result = [result stringByReplacingOccurrencesOfString:@"small" withString:@"capital"];
    }
    return result;
}

%end

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
    Class $KBKeyTree = (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_5_0) ?
        %c(UIKBTree) : %c(UIKBKey);
    %init(GHonorCase, KBKeyTree = $KBKeyTree);

    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_6_0 &&
            kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
        %init(GFirmware_GTE_60_LT_70);
    }

    // Setup app-dependent hooks
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        %init(GSpringBoard);
    }

    [pool release];
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
