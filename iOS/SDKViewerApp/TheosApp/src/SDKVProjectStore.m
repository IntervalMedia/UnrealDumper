#import "SDKVProjectStore.h"
#import "SDKVParser.h"
#import "SSZipArchive.h"

@implementation SDKVProjectStore

- (nullable NSString *)readTextFileAtURL:(NSURL *)url required:(BOOL)required error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) {
        return nil;
    }

    NSArray<NSNumber *> *encodings = @[
        @(NSUTF8StringEncoding),
        @(NSUnicodeStringEncoding),
        @(NSUTF16LittleEndianStringEncoding),
        @(NSUTF16BigEndianStringEncoding),
        @(NSWindowsCP1252StringEncoding),
        @(NSISOLatin1StringEncoding),
        @(NSASCIIStringEncoding),
    ];

    for (NSNumber *encodingNumber in encodings) {
        NSStringEncoding encoding = (NSStringEncoding)encodingNumber.unsignedIntegerValue;
        NSString *text = [[NSString alloc] initWithData:data encoding:encoding];
        if (text) {
            return text;
        }
    }

    if (required && error) {
        *error = [NSError errorWithDomain:@"SDKViewer"
                                     code:1003
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to decode %@ using supported encodings.", url.lastPathComponent ?: @"text file"]
                                 }];
    }
    return nil;
}

- (NSURL *)projectsRootURL {
    NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    return [documents URLByAppendingPathComponent:@"SDKViewerProjects" isDirectory:YES];
}

- (NSString *)sanitizeProjectName:(NSString *)name {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < name.length; i++) {
        unichar c = [name characterAtIndex:i];
        if ([allowed characterIsMember:c]) {
            [result appendFormat:@"%C", c];
        } else if (![[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) {
            [result appendString:@"_"];
        }
    }
    if (result.length == 0) {
        return @"Project";
    }
    return result;
}

- (BOOL)ensureProjectsRoot:(NSError **)error {
    return [[NSFileManager defaultManager] createDirectoryAtURL:[self projectsRootURL] withIntermediateDirectories:YES attributes:nil error:error];
}

- (NSArray<NSString *> *)listProjects:(NSError **)error {
    if (![self ensureProjectsRoot:error]) {
        return @[];
    }

    NSArray<NSURL *> *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self projectsRootURL]
                                                               includingPropertiesForKeys:nil
                                                                                  options:0
                                                                                    error:error];
    if (!entries) {
        return @[];
    }

    NSMutableArray<NSString *> *projects = [NSMutableArray array];
    for (NSURL *url in entries) {
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDir] && isDir) {
            [projects addObject:url.lastPathComponent];
        }
    }
    return [projects sortedArrayUsingSelector:@selector(compare:)];
}

- (nullable NSDictionary *)createProjectNamed:(NSString *)name error:(NSError **)error {
    NSString *sanitized = [self sanitizeProjectName:name];
    NSURL *projectDir = [[self projectsRootURL] URLByAppendingPathComponent:sanitized isDirectory:YES];

    if (![self ensureProjectsRoot:error]) {
        return nil;
    }

    if (![[NSFileManager defaultManager] createDirectoryAtURL:projectDir withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }

    NSDictionary *metadata = @{
        @"name": sanitized,
        @"createdAt": @([[NSDate date] timeIntervalSince1970]),
    };

    NSDictionary *record = @{ @"metadata": metadata };
    if (![self saveProjectRecord:record forProject:sanitized error:error]) {
        return nil;
    }
    return record;
}

- (nullable NSDictionary *)loadProjectNamed:(NSString *)name error:(NSError **)error {
    NSURL *projectDir = [[self projectsRootURL] URLByAppendingPathComponent:name isDirectory:YES];
    NSURL *recordURL = [projectDir URLByAppendingPathComponent:@"project.json"];

    NSData *data = [NSData dataWithContentsOfURL:recordURL options:0 error:error];
    if (!data) return nil;

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    return (NSDictionary *)json;
}

- (BOOL)saveProjectRecord:(NSDictionary *)record forProject:(NSString *)projectName error:(NSError **)error {
    NSURL *projectDir = [[self projectsRootURL] URLByAppendingPathComponent:projectName isDirectory:YES];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:projectDir withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;

    NSURL *recordURL = [projectDir URLByAppendingPathComponent:@"project.json"];
    return [data writeToURL:recordURL options:NSDataWritingAtomic error:error];
}

- (nullable NSDictionary *)importDumpZipAtURL:(NSURL *)zipURL toProject:(NSString *)projectName error:(NSError **)error {
    NSURL *projectDir = [[self projectsRootURL] URLByAppendingPathComponent:projectName isDirectory:YES];
    NSURL *zipCopy = [projectDir URLByAppendingPathComponent:@"sdk_dump.zip"];
    NSURL *extractDir = [projectDir URLByAppendingPathComponent:@"sdk_dump" isDirectory:YES];

    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:extractDir.path]) {
        [fm removeItemAtURL:extractDir error:nil];
    }
    if ([fm fileExistsAtPath:zipCopy.path]) {
        [fm removeItemAtURL:zipCopy error:nil];
    }

    if (![fm copyItemAtURL:zipURL toURL:zipCopy error:error]) {
        return nil;
    }
    if (![fm createDirectoryAtURL:extractDir withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }

    BOOL ok = [SSZipArchive unzipFileAtPath:zipCopy.path toDestination:extractDir.path];
    if (!ok) {
        if (error) {
            *error = [NSError errorWithDomain:@"SDKViewer" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Failed to unzip SDK dump archive"}];
        }
        return nil;
    }

    NSString *aioPath = [[extractDir URLByAppendingPathComponent:@"AIOHeader.hpp"] path];
    NSString *scriptPath = [[extractDir URLByAppendingPathComponent:@"script.json"] path];

    NSString *aio = [self readTextFileAtURL:[NSURL fileURLWithPath:aioPath] required:YES error:error];
    if (!aio) {
        return nil;
    }

    NSString *script = nil;
    if ([fm fileExistsAtPath:scriptPath]) {
        script = [self readTextFileAtURL:[NSURL fileURLWithPath:scriptPath] required:NO error:nil];
    }

    NSDictionary *dump = [SDKVParser parseAIOHeader:aio scriptJSON:script error:error];
    if (!dump) return nil;

    NSMutableDictionary *record = [[self loadProjectNamed:projectName error:error] mutableCopy];
    if (!record) return nil;

    NSMutableDictionary *metadata = [record[@"metadata"] mutableCopy] ?: [NSMutableDictionary dictionary];
    metadata[@"lastImportedAt"] = @([[NSDate date] timeIntervalSince1970]);
    metadata[@"sourceArchiveName"] = zipURL.lastPathComponent ?: @"sdk_dump.zip";

    record[@"metadata"] = metadata;
    record[@"dump"] = dump;

    if (![self saveProjectRecord:record forProject:projectName error:error]) {
        return nil;
    }

    return record;
}

@end
