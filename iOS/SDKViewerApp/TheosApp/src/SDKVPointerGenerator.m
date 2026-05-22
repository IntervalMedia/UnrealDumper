#import "SDKVPointerGenerator.h"

@implementation SDKVPointerGenerator

+ (NSArray<NSNumber *> *)parseOffsetsFromText:(NSString *)text {
    NSMutableArray<NSNumber *> *offsets = [NSMutableArray array];
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@","];
    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) continue;

        unsigned long long value = 0;
        if ([trimmed.lowercaseString hasPrefix:@"0x"]) {
            NSScanner *scanner = [NSScanner scannerWithString:[trimmed substringFromIndex:2]];
            [scanner scanHexLongLong:&value];
        } else {
            value = strtoull(trimmed.UTF8String, NULL, 10);
        }
        [offsets addObject:@(value)];
    }
    return offsets;
}

+ (NSString *)generateCPPWithBaseExpression:(NSString *)baseExpression
                                    offsets:(NSArray<NSNumber *> *)offsets
                                 resultType:(NSString *)resultType
                                 resultName:(NSString *)resultName {
    if (offsets.count == 0) {
        return @"// No offsets were provided.";
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"uintptr_t chain = static_cast<uintptr_t>(%@);", baseExpression]];

    for (NSUInteger i = 0; i + 1 < offsets.count; i++) {
        [lines addObject:[NSString stringWithFormat:@"chain = *reinterpret_cast<uintptr_t*>(chain + 0x%llX);", offsets[i].unsignedLongLongValue]];
    }

    NSNumber *last = offsets.lastObject;
    [lines addObject:[NSString stringWithFormat:@"auto %@ = reinterpret_cast<%@*>(chain + 0x%llX);", resultName, resultType, last.unsignedLongLongValue]];

    return [lines componentsJoinedByString:@"\n"];
}

@end
