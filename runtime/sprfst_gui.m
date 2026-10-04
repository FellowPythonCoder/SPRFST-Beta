#import <Cocoa/Cocoa.h>
#include "sprfst_rt.h"

static NSWindow *g_window = nil;
static NSView *g_content = nil;

int64_t spf_gui_window(SpfText *title, int64_t w, int64_t h) {
    if (w < 200) w = 200;
    if (h < 120) h = 120;
    if (NSApp == nil) {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    NSRect rect = NSMakeRect(180, 180, (CGFloat)w, (CGFloat)h);
    g_window = [[NSWindow alloc] initWithContentRect:rect
                                           styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                                             backing:NSBackingStoreBuffered
                                               defer:NO];
    g_window.title = [NSString stringWithUTF8String:spf_text_cstr(title)];
    g_window.backgroundColor = [NSColor colorWithWhite:0.06 alpha:1];
    g_content = [[NSView alloc] initWithFrame:rect];
    g_window.contentView = g_content;
    [g_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    return 1;
}

void spf_gui_label(int64_t win, SpfText *text, int64_t x, int64_t y) {
    (void)win;
    NSTextField *lab = [NSTextField labelWithString:[NSString stringWithUTF8String:spf_text_cstr(text)]];
    lab.textColor = [NSColor colorWithWhite:0.92 alpha:1];
    lab.frame = NSMakeRect((CGFloat)x, (CGFloat)y, 420, 24);
    [g_content addSubview:lab];
}

int64_t spf_gui_button(int64_t win, SpfText *title, int64_t x, int64_t y, int64_t w, int64_t h) {
    (void)win;
    NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect((CGFloat)x, (CGFloat)y, (CGFloat)w, (CGFloat)h)];
    b.title = [NSString stringWithUTF8String:spf_text_cstr(title)];
    b.bezelStyle = NSBezelStyleRounded;
    [g_content addSubview:b];
    return 1;
}

void spf_gui_run(int64_t win) {
    (void)win;
    [NSApp run];
}
