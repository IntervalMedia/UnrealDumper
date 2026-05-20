#import "SDKVParser.h"

@implementation SDKVParser

+ (nullable NSDictionary *)parseAIOHeader:(NSString *)aioHeader scriptJSON:(nullable NSString *)scriptJSON error:(NSError **)error {
    NSMutableArray *packages = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray *> *packageMap = [NSMutableDictionary dictionary];

    NSArray<NSString *> *lines = [aioHeader componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *currentPackage = @"Unknown";

    NSUInteger idx = 0;
    while (idx < lines.count) {
        NSString *line = lines[idx] ?: @"";
        if ([line hasPrefix:@"// Package: "]) {
            currentPackage = [[line substringFromIndex:12] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (!packageMap[currentPackage]) {
                packageMap[currentPackage] = [NSMutableArray array];
            }
            idx++;
            continue;
        }

        if ([line hasPrefix:@"// Object: "]) {
            NSString *fullName = [[line substringFromIndex:11] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

            NSUInteger probe = idx + 1;
            NSString *decl = nil;
            while (probe < lines.count) {
                NSString *candidate = [lines[probe] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([candidate hasPrefix:@"struct "] || [candidate hasPrefix:@"class "] || [candidate hasPrefix:@"enum class "]) {
                    decl = candidate;
                    break;
                }
                if ([candidate hasPrefix:@"// Object: "] || [candidate hasPrefix:@"// Package: "]) {
                    break;
                }
                probe++;
            }

            if (!decl) {
                idx++;
                continue;
            }

            NSString *kind = @"struct";
            NSString *trimmed = decl;
            if ([decl hasPrefix:@"enum class "]) {
                kind = @"enum";
                trimmed = [decl substringFromIndex:11];
            } else if ([decl hasPrefix:@"class "]) {
                kind = @"class";
                trimmed = [decl substringFromIndex:6];
            } else if ([decl hasPrefix:@"struct "]) {
                trimmed = [decl substringFromIndex:7];
            }

            NSRange brace = [trimmed rangeOfString:@"{"];
            if (brace.location != NSNotFound) {
                trimmed = [trimmed substringToIndex:brace.location];
            }
            NSRange colon = [trimmed rangeOfString:@":"];
            if (colon.location != NSNotFound) {
                trimmed = [trimmed substringToIndex:colon.location];
            }
            NSString *name = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            NSMutableArray<NSString *> *bodyLines = [NSMutableArray arrayWithObject:decl];
            NSUInteger cursor = probe + 1;
            while (cursor < lines.count) {
                NSString *bodyLine = lines[cursor] ?: @"";
                [bodyLines addObject:bodyLine];
                if ([[bodyLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"};"]) {
                    break;
                }
                cursor++;
            }

            NSDictionary *type = @{
                @"name": name ?: @"Unknown",
                @"fullName": fullName ?: @"Unknown",
                @"kind": kind,
                @"declaration": decl,
                @"body": [bodyLines componentsJoinedByString:@"\n"]
            };
            [packageMap[currentPackage] addObject:type];
            idx = cursor + 1;
            continue;
        }

        idx++;
    }

    NSArray<NSString *> *sortedNames = [[packageMap allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *pkgName in sortedNames) {
        NSArray *types = [packageMap[pkgName] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"name"] compare:b[@"name"]];
        }];
        [packages addObject:@{ @"name": pkgName, @"types": types }];
    }

    NSArray *functions = @[];
    if (scriptJSON.length > 0) {
        NSData *data = [scriptJSON dataUsingEncoding:NSUTF8StringEncoding];
        id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([root isKindOfClass:[NSDictionary class]] && [root[@"Functions"] isKindOfClass:[NSArray class]]) {
            functions = root[@"Functions"];
        }
    }

    if (packages.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"SDKViewer" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"No packages parsed from AIOHeader.hpp"}];
        }
        return nil;
    }

    return @{ @"packages": packages, @"scriptFunctions": functions };
}

@end
