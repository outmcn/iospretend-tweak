#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <math.h>

static NSString * const CFOPreferencesPath = @"/var/jb/var/mobile/Library/Preferences/com.iospretend.iospretend.plist";
static NSString * const CFOPreferencesChanged = @"com.iospretend.iospretend/ReloadPrefs";

static BOOL cfoGPSEnabled = NO;
static double cfoLatitude = 39.9042;
static double cfoLongitude = 116.4074;
static NSSet<NSString *> *cfoSelectedApps = nil;

static BOOL CFOIsValidLatitude(double latitude) {
    return isfinite(latitude) && latitude >= -90.0 && latitude <= 90.0;
}

static BOOL CFOIsValidLongitude(double longitude) {
    return isfinite(longitude) && longitude >= -180.0 && longitude <= 180.0;
}

static void CFOGPSReload(void) {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:CFOPreferencesPath] ?: @{};
    cfoGPSEnabled = [prefs[@"gpsEnabled"] boolValue];
    double latitude = [prefs[@"latitude"] doubleValue];
    double longitude = [prefs[@"longitude"] doubleValue];
    cfoLatitude = CFOIsValidLatitude(latitude) ? latitude : 39.9042;
    cfoLongitude = CFOIsValidLongitude(longitude) ? longitude : 116.4074;
    NSArray *apps = prefs[@"selectedApps"];
    cfoSelectedApps = [apps isKindOfClass:[NSArray class]] ? [NSSet setWithArray:apps] : [NSSet set];
}

static BOOL CFOGPSShouldApply(void) {
    if (!cfoGPSEnabled) return NO;
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (bundleID.length == 0) return NO;
    if ([bundleID isEqualToString:@"com.apple.locationd"] ||
        [bundleID isEqualToString:@"com.apple.Preferences"] ||
        [bundleID isEqualToString:@"com.apple.springboard"]) return NO;
    return [cfoSelectedApps containsObject:bundleID];
}

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    if (CFOGPSShouldApply() && CFOIsValidLatitude(cfoLatitude) && CFOIsValidLongitude(cfoLongitude)) {
        return CLLocationCoordinate2DMake(cfoLatitude, cfoLongitude);
    }
    return %orig;
}
%end

static void CFOGPSPreferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    CFOGPSReload();
}

%ctor {
    @autoreleasepool {
        CFOGPSReload();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, CFOGPSPreferencesChanged,
                                        (__bridge CFStringRef)CFOPreferencesChanged, NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        %init;
    }
}
