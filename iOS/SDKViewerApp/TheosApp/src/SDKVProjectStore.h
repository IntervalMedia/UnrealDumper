#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SDKVProjectStore : NSObject

- (NSURL *)projectsRootURL;
- (NSArray<NSString *> *)listProjects:(NSError **)error;
- (nullable NSDictionary *)createProjectNamed:(NSString *)name error:(NSError **)error;
- (nullable NSDictionary *)loadProjectNamed:(NSString *)name error:(NSError **)error;
- (BOOL)saveProjectRecord:(NSDictionary *)record forProject:(NSString *)projectName error:(NSError **)error;
- (nullable NSDictionary *)importDumpZipAtURL:(NSURL *)zipURL toProject:(NSString *)projectName error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
