/**
 * Name: ShowCase
 * Type: iOS SpringBoard extension (MobileSubstrate-based)
 * Desc: Make keyboard show current case.
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 *
 * Last-modified: 2011-03-01 00:45:25
 */


#include <objc/runtime.h>

// Class declarations
// NOTE: These are not 100% accurate; protocol information has been stripped,
//       and super classes may change between firmware versions.
@interface CALayer : NSObject
- (void)_display;
@end

@interface UIKeyboardImpl : UIView
+ (id)activeInstance;
@end

@interface UIKBKeyplaneView : UIView @end

@interface UIKeyboardLayout : UIView @end
@interface UIKeyboardLayoutStar : UIKeyboardLayout
@property(assign, nonatomic) BOOL shift;
@end

@interface UIKBShape : NSObject @end
@interface UIKBKey : UIKBShape
@property(copy, nonatomic) NSString *name;
@end

//==============================================================================

static inline void updateKeyplaneView(id object)
{
    UIKBKeyplaneView *_keyplaneView = NULL;
    if (object_getInstanceVariable(object, "_keyplaneView", (void **)&_keyplaneView) == NULL)
        object_getInstanceVariable(object, "m_keyplaneView", (void **)&_keyplaneView);
    [_keyplaneView setNeedsDisplay];
}

//==============================================================================

%hook UIKeyboard

- (void)activate
{
    %orig;

    // Force keys to redraw to prevent cached uppercase letters from showing
    // FIXME: Determine why redraw is needed and prevent this need.
    UIKeyboardImpl *impl = [objc_getClass("UIKeyboardImpl") activeInstance];
    if (impl != nil) {
        UIKeyboardLayout *m_layout = MSHookIvar<UIKeyboardLayout *>(impl, "m_layout");
        if ([m_layout isKindOfClass:objc_getClass("UIKeyboardLayoutStar")])
            updateKeyplaneView(m_layout);
    }
}

%end

//==============================================================================

%hook UIKeyboardLayoutStar

- (void)setShift:(BOOL)shift
{
    BOOL currentShiftState = self.shift;

    %orig;

    // If shift state changed, force keys to redraw
    if (currentShiftState != shift)
        updateKeyplaneView(self);
}

%end

//==============================================================================

%hook UIKBKey

- (NSString *)displayString
{
    // If key represents a lowercase letter, then actually return a lowercase letter
    NSString *result = %orig;
    return [self.name hasPrefix:@"Latin-Small"] ? [result lowercaseString] : result;
}

%end

//==============================================================================

// NOTE: Only needed for iOS 4.2.1+.
%group GKeyboardCache

%hook UIKeyboardCache

- (void)displayView:(id)view withKey:(id)key fromLayout:(id)layout
{
    // Don't allow use of cached keyplane view
    if ([view isKindOfClass:objc_getClass("UIKBKeyplaneView")])
        [[view layer] _display];
    else
        %orig;
}

%end

%end // GKeyboardCache

//==============================================================================

__attribute__((constructor)) static void init()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // Setup hooks
    %init;

    if (objc_getClass("UIKeyboardCache") != nil)
        // Include additional hooks for iOS 4.2.1+
        %init(GKeyboardCache);

    [pool release];
}

/* vim: set filetype=objcpp sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
