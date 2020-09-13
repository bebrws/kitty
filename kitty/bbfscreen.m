// File: bbfscreen.m
// Original information and license is below. Modifed to quickly give me a keyboard listener
// for command control a to set kitty as always on top.
// This code used a global keybaord event listener.
//
// I added code to fallback to a local keyboard event listener as well.

//
//  File: listen.m
//  Project: listenM&K
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See
//  License:    Creative Commons Attribution-NonCommercial 4.0 International License
//
//  Compile:
//   a) Xcode, Product->Build
//
//   or ...
//
//   b) $ clang -o listenMK listen.m -framework Cocoa -framework Carbon
//
//   Run (as root):
//   # ./listenMK
//
//  Notes:
//   a) code, largely based on altermouse.c/alterkeys.c (amit singh/http://osxbook.com)
//   b) run with '-mouse' for just mouse events or '-keyboard' for just key events
//
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

id eventMonitor;
NSWindow *globalw;
int isOnTop  = 0;

//event tap
static CFMachPortRef eventTap = NULL;

//map a printable keycode to a string
// ->code based on: https://stackoverflow.com/a/33584460
NSString* keyCodeToString(CGEventRef event, CGEventType type)
{
    //keycode as string
    NSString* keyCodeAsString = nil;
    
    //status
    OSStatus status = !noErr;
    
    //(key) code
    CGKeyCode keyCode = 0;
    
    //keyboard layout data
    CFDataRef keylayoutData = NULL;
    
    //keyboard layout
    const UCKeyboardLayout* keyboardLayout = NULL;
    
    //key action
    UInt16 keyAction = 0;
    
    //modifer state
    UInt32 modifierState = 0;
    
    //dead key
    UInt32 deadKeyState = 0;
    
    //max length
    UniCharCount maxStringLength = 255;
    
    //actual lenth
    UniCharCount actualStringLength = 0;
    
    //string
    UniChar unicodeString[maxStringLength];
    
    //zero out
    memset(unicodeString, 0x0, sizeof(unicodeString));
    
    //get code
    keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    
    //get key layout data
    keylayoutData = (CFDataRef)TISGetInputSourceProperty(TISCopyCurrentKeyboardInputSource(), kTISPropertyUnicodeKeyLayoutData);
    if(NULL == keylayoutData)
    {
        //bail
        goto bail;
    }
    
    //get keyboard layout
    keyboardLayout = (const UCKeyboardLayout*)CFDataGetBytePtr(keylayoutData);
    if(NULL == keyboardLayout)
    {
        //bail
        goto bail;
    }
    
    //set key action down
    if(kCGEventKeyDown == type)
    {
        //down
        keyAction = kUCKeyActionDown;
    }
    //set key action up
    else
    {
        //up
        keyAction = kUCKeyActionUp;
    }
    
    status = UCKeyTranslate(keyboardLayout, keyCode, keyAction, modifierState, LMGetKbdType(), 0, &deadKeyState, maxStringLength, &actualStringLength, unicodeString);
    if( (noErr != status) ||
        (0 == actualStringLength) )
    {
        //bail
        goto bail;
    }

    //init string
    keyCodeAsString = [[NSString stringWithCharacters:unicodeString length:(NSUInteger)actualStringLength] lowercaseString];
    
bail:
    
    return keyCodeAsString;
}

//build string of key modifiers (shift, command, etc)
// ->code based on: https://stackoverflow.com/a/4425180/3854841
NSMutableString* extractKeyModifiers(CGEventRef event)
{
    //key modify(ers)
    NSMutableString* keyModifiers = nil;
    
    //flags
    CGEventFlags flags = 0;
    
    //alloc
    keyModifiers = [NSMutableString string];
    
    //get flags
    flags = CGEventGetFlags(event);
    
    //control
    if(YES == !!(flags & kCGEventFlagMaskControl))
    {
        //add
        [keyModifiers appendString:@"control "];
    }
    
    //alt
    if(YES == !!(flags & kCGEventFlagMaskAlternate))
    {
        //add
        [keyModifiers appendString:@"alt "];
    }
    
    //command
    if(YES == !!(flags & kCGEventFlagMaskCommand))
    {
        //add
        [keyModifiers appendString:@"command "];
    }
    
    //shift
    if(YES == !!(flags & kCGEventFlagMaskShift))
    {
        //add
        [keyModifiers appendString:@"shift "];
    }
    
    //caps lock
    if(YES == !!(flags & kCGEventFlagMaskAlphaShift))
    {
        //add
        [keyModifiers appendString:@"caps lock "];
    }
    
    return keyModifiers;
}

CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    CGPoint location = {0};
    
    CGKeyCode keyCode = 0;
    
    NSMutableString* keyModifiers = nil;

    switch(type)
    {
        case kCGEventLeftMouseDown:
            break;
            
        case kCGEventLeftMouseUp:
            break;
            
        
        case kCGEventRightMouseDown:
            break;
        case kCGEventRightMouseUp:
            break;
            
        case kCGEventLeftMouseDragged:
            break;
        case kCGEventRightMouseDragged:
            break;
        case kCGEventKeyDown:
            keyModifiers = extractKeyModifiers(event);
            break;
            
        
        case kCGEventKeyUp:
            break;
        case kCGEventTapDisabledByTimeout:
            CGEventTapEnable(eventTap, true);
            return event;
        
        default:
            break;
    }
    
    if( (kCGEventKeyDown == type) || (kCGEventKeyUp == type) )
    {
        keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        
        if(0 != keyModifiers.length)
        {
            if ([keyModifiers rangeOfString:@"command"].location != NSNotFound && [keyModifiers rangeOfString:@"control"].location != NSNotFound) {
                if (keyCode == 0) {

                    if(isOnTop) {
                        [globalw setLevel:0];
                        isOnTop = 0;
                    } else { 
                        [globalw setLevel:9];
                        isOnTop = 1;
                    }
                }
                
            }
        }
    }
    else
    {
        location = CGEventGetLocation(event);
    }
    
    return event;
}

void bbsetup_fs_handler(void *vw)
{
    NSWindow *w = (NSWindow *)vw;
    globalw = w;
    CGEventMask eventMask = 0;
    CFRunLoopSourceRef runLoopSource = NULL;
    @autoreleasepool
    {
        // must be root to setup a global keyboard listener - this will let you press command control a anywhere though
        // and git the kitty terminal to pop up always on top
        // unless this program has been added to 'Security & Privacy' -> 'Accessibility'
        if(0 != geteuid())
        {
            printf("ERROR: run as root to setup system wide shortcuts\n\n");
            goto bail;
        }
        
        eventMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
        eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, eventCallback, NULL);
        if(NULL == eventTap)
        {
            printf("ERROR: failed to create event tap\n");
            goto bail;
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(eventTap, true);
        CFRunLoopRun();
    }
    
bail:
    
    //release event tap
    if(NULL != eventTap)
    {
        //release
        CFRelease(eventTap);
        
        //unset
        eventTap = NULL;
    }
    
    //release run loop src
    if(NULL != runLoopSource)
    {
        //release
        CFRelease(runLoopSource);
        
        //unset
        runLoopSource = NULL;
    }

    printf("Will try to setup local keyboard listener for command-control-a to set window as always on top.\n");

    NSEvent* (^handler)(NSEvent*) = ^(NSEvent *theEvent) {
        BOOL isCommandDown = !!([theEvent modifierFlags] & NSCommandKeyMask);
        BOOL isControlDown = !!([theEvent modifierFlags] & NSControlKeyMask);

        if (isCommandDown && isControlDown && theEvent.keyCode == 0) {
            printf("Always on top keyboard combo hit");
            if(isOnTop) {
                [globalw setLevel:0];
                isOnTop = 0;
            } else { 
                [globalw setLevel:9];
                isOnTop = 1;
            }        
        }
        return theEvent;
    };
    eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:handler];

    
}
