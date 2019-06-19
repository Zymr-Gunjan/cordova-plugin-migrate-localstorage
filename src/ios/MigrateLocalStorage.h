#import <Cordova/CDVPlugin.h>

@interface MigrateLocalStorage : CDVPlugin {}

- (BOOL) copyFrom:(NSString*)src to:(NSString*)dest;
- (BOOL) moveFrom:(NSString*)src to:(NSString*)dest;
- (void) migrateLocalStorage:(NSString*) targetName;
- (void) migrateWebSQL:(NSString*)targetName;
- (void) migrateIndexedDB:(NSString*)targetName;
- (NSString*) getFileNameFromScheme;

@end
