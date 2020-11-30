#import "MigrateLocalStorage.h"
#import <Cordova/CDVViewController.h>
#import <sqlite3.h>

@implementation MigrateLocalStorage

- (BOOL) copyFrom:(NSString*)src to:(NSString*)dest
{
    NSFileManager* fileManager = [NSFileManager defaultManager];

    // Bail out if source file does not exist
    if (![fileManager fileExistsAtPath:src]) {
        return NO;
    }

    // Bail out if dest file exists
    if ([fileManager fileExistsAtPath:dest]) {
        return NO;
    }

    // create path to dest
    if (![fileManager createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        return NO;
    }

    // copy src to dest
    NSError* err;
    BOOL res =[fileManager copyItemAtPath:src toPath:dest error:&err];
    return res;
}

- (BOOL) moveFrom:(NSString*)src to:(NSString*)dest
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    // Bail out if source file does not exist
    if (![fileManager fileExistsAtPath:src]) {
        return NO;
    }
    
    // Bail out if dest file exists
    if ([fileManager fileExistsAtPath:dest]) {
        return NO;
    }
    
    // create path to dest
    if (![fileManager createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        return NO;
    }
    
    // copy src to dest
    return [fileManager moveItemAtPath:src toPath:dest error:nil];
}

- (void) migrateLocalStorage:(NSString*)targetName
{
    // Migrate UIWebView local storage files to WKWebView. Adapted from
    // https://github.com/Telerik-Verified-Plugins/WKWebView/blob/master/src/ios/MyMainViewController.m

    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* original;
    
    NSMutableString* targetFileName = [[NSMutableString alloc]init];
    [targetFileName appendString:(targetName)];
    [targetFileName appendString:(@".localstorage")];

    if ([[NSFileManager defaultManager] fileExistsAtPath:[appLibraryFolder stringByAppendingPathComponent:@"WebKit/LocalStorage/file__0.localstorage"]]) {
        original = [appLibraryFolder stringByAppendingPathComponent:@"WebKit/LocalStorage"];
    } else {
        original = [appLibraryFolder stringByAppendingPathComponent:@"Caches"];
    }

    original = [original stringByAppendingPathComponent:@"file__0.localstorage"];

    NSString* target = [[NSString alloc] initWithString: [appLibraryFolder stringByAppendingPathComponent:@"WebKit"]];

#if TARGET_IPHONE_SIMULATOR
    // the simulutor squeezes the bundle id into the path
    NSString* bundleIdentifier = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    target = [target stringByAppendingPathComponent:bundleIdentifier];
#endif


    target = [[target stringByAppendingPathComponent:@"WebsiteData/LocalStorage/"] stringByAppendingPathComponent:targetFileName];
    // Only copy data if no existing localstorage data exists yet for wkwebview
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        NSLog(@"No existing localstorage data found for WKWebView. Migrating data from UIWebView");
        [self copyFrom:original to:target];
        [self copyFrom:[original stringByAppendingString:@"-shm"] to:[target stringByAppendingString:@"-shm"]];
        [self copyFrom:[original stringByAppendingString:@"-wal"] to:[target stringByAppendingString:@"-wal"]];
    }
}

- (void) migrateWebSQL:(NSString*)targetName
{
    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString* originalDatabases;
    NSString* originalWebSQL;
    
    NSString* targetDatabases;
    NSString* targetWebSQL;
    
    originalDatabases = [appLibraryFolder stringByAppendingPathComponent:(@"Caches/Databases.db")];
    originalWebSQL = [appLibraryFolder stringByAppendingPathComponent:(@"Caches/file__0")];
    
    
    targetDatabases = [appLibraryFolder stringByAppendingPathComponent:@"WebKit"];
    targetWebSQL = [appLibraryFolder stringByAppendingPathComponent:@"WebKit"];
    
#if TARGET_IPHONE_SIMULATOR
    // the simulutor squeezes the bundle id into the path
    NSString* bundleIdentifier = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    targetDatabases = [targetDatabases stringByAppendingPathComponent:bundleIdentifier];
    targetWebSQL = [targetWebSQL stringByAppendingPathComponent:bundleIdentifier];
#endif
    
    targetDatabases = [targetDatabases stringByAppendingPathComponent:@"WebsiteData/WebSQL/Databases.db"];
    targetWebSQL = [[targetWebSQL stringByAppendingPathComponent:@"WebsiteData/WebSQL"] stringByAppendingPathComponent:(targetName)];
    
    // Copy Databases.db files
    if (![[NSFileManager defaultManager] fileExistsAtPath:targetDatabases]) {
        sqlite3* _db = nil;
        NSLog(@"No existing WebSQL data found for WKWebView. Migrating data from UIWebView");
        if (sqlite3_open([originalDatabases UTF8String], &_db) != SQLITE_OK) {
            NSLog(@"Could not open Databases.db!");
        }
        else {
            NSString* query = [NSString stringWithFormat:@"UPDATE Databases SET origin = '%@' WHERE origin = 'file__0'", targetName];
            sqlite3_stmt* stmt;
            if(sqlite3_prepare_v2(_db, [query UTF8String], -1, &stmt, nil) == SQLITE_OK) {
                if(sqlite3_step(stmt) == SQLITE_DONE) {
                    NSLog(@"Updated Databases.db!");
                    //NSFileManager* fileManager = [NSFileManager defaultManager];
                } else {
                    NSLog(@"Failed to update Databases.db! %s", sqlite3_errmsg(_db));
                }
                sqlite3_finalize(stmt);
                [self moveFrom:originalDatabases to:targetDatabases];
                [self moveFrom:[originalDatabases stringByAppendingString:@"-shm"] to:[targetDatabases stringByAppendingString:@"-shm"]];
                [self moveFrom:[originalDatabases stringByAppendingString:@"-wal"] to:[targetDatabases stringByAppendingString:@"-wal"]];
            }
            else {
                NSLog(@"Failed to update Databases.db! %s", sqlite3_errmsg(_db));
            }
        }
    }
    
    // Copy database directory
    if (![[NSFileManager defaultManager] fileExistsAtPath:targetWebSQL]) {
        NSLog(@"No existing WebSQL databases found for WKWebView. Migrating data from UIWebView");
        [self moveFrom:originalWebSQL to:targetWebSQL];
    }
}

- (void) migrateIndexedDB:(NSString*)targetName
{
    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString* original;
    NSString* target;
    
    original = [appLibraryFolder stringByAppendingPathComponent:(@"Caches/v1/___IndexedDB/file__0")];
    target = [appLibraryFolder stringByAppendingPathComponent:@"WebKit"];
    
#if TARGET_IPHONE_SIMULATOR
    // the simulutor squeezes the bundle id into the path
    NSString* bundleIdentifier = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    target = [target stringByAppendingPathComponent:bundleIdentifier];
#endif
    
    target = [[target stringByAppendingPathComponent:@"WebsiteData/IndexedDB"] stringByAppendingPathComponent:(targetName)];
    
    // Copy IndexedDB directory
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        NSLog(@"No existing IndexedDB databases found for WKWebView. Migrating data from UIWebView");
        [self moveFrom:original to:target];
        [self moveFrom:[original stringByAppendingString:@"-shm"] to:[target stringByAppendingString:@"-shm"]];
        [self moveFrom:[original stringByAppendingString:@"-wal"] to:[target stringByAppendingString:@"-wal"]];
    }
}

- (NSString*) getFileNameFromScheme
{
    CDVViewController* vController = (CDVViewController*)self.viewController;
    NSURL* mainURL = [NSURL URLWithString:vController.startPage];
    NSMutableString* targetFileName = [[NSMutableString alloc]init];
    if([mainURL scheme] == nil) {
        [targetFileName appendString:(@"file__0")];
    }
    else {
        [targetFileName appendString:([mainURL scheme])];
        [targetFileName appendString:(@"_")];
        if(!([[mainURL host] isEqualToString:@"localhost"] || [[mainURL host] isEqualToString:@"127.0.0.1"])) {
            return @"file__0";
        }
        [targetFileName appendString:([mainURL host])];
        if([mainURL port] != nil) {
            [targetFileName appendString:(@"_")];
            [targetFileName appendString:([[mainURL port] stringValue])];
        }
    }
    return [NSString stringWithString:targetFileName];
}

- (void)pluginInitialize
{
    NSString* targetName = [self getFileNameFromScheme];
    [self migrateLocalStorage:targetName];
    [self migrateWebSQL:targetName];
    [self migrateIndexedDB:targetName];
}


@end
