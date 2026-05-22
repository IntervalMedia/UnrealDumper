#import "SDKVParser.h"

@implementation SDKVParser

+ (nullable NSDictionary *)parseAIOHeader:(NSString *)aioHeader scriptJSON:(nullable NSString *)scriptJSON error:(NSError **)error {
    NSArray<NSString *> *lines = [aioHeader componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSMutableDictionary *> *packages = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableDictionary *> *packageMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *currentPackage = nil;
    NSUInteger sourceOrder = 0;
    NSUInteger idx = 0;

    while (idx < lines.count) {
        NSString *line = lines[idx] ?: @"";
        if ([line hasPrefix:@"// Package: "]) {
            NSString *packageName = [[line substringFromIndex:12] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSDictionary *summaryResult = [self parsePackageSummaryInLines:lines startingAtIndex:idx + 1];
            NSMutableDictionary *package = [@{
                @"name": packageName.length > 0 ? packageName : @"Unknown",
                @"sourceOrder": @(packages.count),
                @"types": [NSMutableArray array]
            } mutableCopy];

            NSDictionary *summary = summaryResult[@"summary"];
            if (summary) {
                package[@"summary"] = summary;
            }

            [packages addObject:package];
            packageMap[package[@"name"]] = package;
            currentPackage = package;
            idx = [summaryResult[@"nextIndex"] unsignedIntegerValue];
            continue;
        }

        NSDictionary *metadata = [self parseObjectMetadataFromLine:line];
        if (metadata) {
            NSUInteger probe = idx + 1;
            NSString *declaration = nil;
            NSNumber *sizeBytes = nil;
            NSNumber *inheritedSizeBytes = nil;

            while (probe < lines.count) {
                NSString *candidate = [lines[probe] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSDictionary *sizeMetadata = [self parseSizeMetadataFromLine:candidate];
                if (sizeMetadata) {
                    sizeBytes = sizeMetadata[@"sizeBytes"];
                    inheritedSizeBytes = sizeMetadata[@"inheritedSizeBytes"];
                }

                if ([self declaredTypeNameFromDeclaration:candidate].length > 0) {
                    declaration = candidate;
                    break;
                }
                if ([candidate hasPrefix:@"// Object: "] || [candidate hasPrefix:@"// Package: "]) {
                    break;
                }
                probe++;
            }

            if (declaration.length == 0) {
                idx++;
                continue;
            }

            NSString *typeName = [self declaredTypeNameFromDeclaration:declaration];
            if (typeName.length == 0) {
                idx++;
                continue;
            }

            NSMutableArray<NSString *> *bodyLines = [NSMutableArray arrayWithObject:declaration];
            NSUInteger cursor = probe + 1;
            while (cursor < lines.count) {
                NSString *bodyLine = lines[cursor] ?: @"";
                [bodyLines addObject:bodyLine];
                if ([[bodyLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"};"]) {
                    break;
                }
                cursor++;
            }

            if (!currentPackage) {
                currentPackage = [@{
                    @"name": @"Unknown",
                    @"sourceOrder": @(packages.count),
                    @"types": [NSMutableArray array]
                } mutableCopy];
                [packages addObject:currentPackage];
                packageMap[@"Unknown"] = currentPackage;
            }

            NSMutableDictionary *type = [@{
                @"name": typeName,
                @"fullName": metadata[@"fullName"] ?: @"Unknown",
                @"declaration": declaration,
                @"body": [bodyLines componentsJoinedByString:@"\n"],
                @"kind": metadata[@"kind"] ?: @"struct",
                @"objectLabel": metadata[@"objectLabel"] ?: @"ScriptStruct",
                @"fields": [self parseFieldsFromBodyLines:bodyLines],
                @"sourceOrder": @(sourceOrder)
            } mutableCopy];

            NSString *parentTypeName = [self parentTypeNameFromDeclaration:declaration];
            if (parentTypeName.length > 0) {
                type[@"parentTypeName"] = parentTypeName;
            }
            if (sizeBytes) {
                type[@"sizeBytes"] = sizeBytes;
            }
            if (inheritedSizeBytes) {
                type[@"inheritedSizeBytes"] = inheritedSizeBytes;
            }

            [currentPackage[@"types"] addObject:type];
            sourceOrder += 1;
            idx = cursor + 1;
            continue;
        }

        idx++;
    }

    NSArray *functions = [self parseScriptFunctionsFromJSON:scriptJSON];

    if (packages.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"SDKViewer" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"No packages parsed from AIOHeader.hpp"}];
        }
        return nil;
    }

    return @{ @"packages": packages, @"scriptFunctions": functions ?: @[] };
}

+ (NSArray<NSDictionary *> *)parseScriptFunctionsFromJSON:(nullable NSString *)scriptJSON {
    if (scriptJSON.length == 0) {
        return @[];
    }

    NSData *data = [scriptJSON dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return @[];
    }

    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![root isKindOfClass:[NSDictionary class]] || ![root[@"Functions"] isKindOfClass:[NSArray class]]) {
        return @[];
    }

    NSMutableArray<NSDictionary *> *functions = [NSMutableArray array];
    for (id entry in root[@"Functions"]) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *name = entry[@"Name"];
        NSNumber *address = entry[@"Address"];
        if (![name isKindOfClass:[NSString class]] || ![address isKindOfClass:[NSNumber class]]) {
            continue;
        }
        [functions addObject:@{ @"name": name, @"address": address }];
    }

    return [functions sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        return [lhs[@"name"] compare:rhs[@"name"]];
    }];
}

+ (nullable NSDictionary *)parseObjectMetadataFromLine:(NSString *)line {
    if (![line hasPrefix:@"// Object: "]) {
        return nil;
    }

    NSString *payload = [[line substringFromIndex:11] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRange separator = [payload rangeOfString:@" "];
    if (separator.location == NSNotFound) {
        return nil;
    }

    NSString *objectLabel = [payload substringToIndex:separator.location];
    NSString *fullName = [[payload substringFromIndex:separator.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *kind = [self semanticKindForObjectLabel:objectLabel];
    if (kind.length == 0) {
        return nil;
    }

    return @{
        @"objectLabel": objectLabel,
        @"fullName": fullName.length > 0 ? fullName : @"Unknown",
        @"kind": kind
    };
}

+ (NSString *)semanticKindForObjectLabel:(NSString *)objectLabel {
    static NSDictionary<NSString *, NSString *> *mapping;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mapping = @{
            @"Enum": @"enum",
            @"UserDefinedEnum": @"enum",
            @"ScriptStruct": @"struct",
            @"UserDefinedStruct": @"struct",
            @"PropertyBag": @"struct",
            @"Class": @"class",
            @"BlueprintGeneratedClass": @"class",
            @"WidgetBlueprintGeneratedClass": @"class",
            @"AnimBlueprintGeneratedClass": @"class",
            @"ControlRigBlueprintGeneratedClass": @"class",
            @"DynamicClass": @"class",
            @"LinkerPlaceholderClass": @"class",
            @"AISenseBlueprintListener": @"class"
        };
    });

    NSString *kind = mapping[objectLabel];
    if (kind.length > 0) {
        return kind;
    }
    if ([objectLabel hasSuffix:@"Class"] || [objectLabel containsString:@"Blueprint"]) {
        return @"class";
    }
    if ([objectLabel containsString:@"Struct"] || [objectLabel isEqualToString:@"PropertyBag"]) {
        return @"struct";
    }
    if ([objectLabel containsString:@"Enum"]) {
        return @"enum";
    }
    return @"";
}

+ (NSDictionary *)parsePackageSummaryInLines:(NSArray<NSString *> *)lines startingAtIndex:(NSUInteger)startIndex {
    NSNumber *enumCount = nil;
    NSNumber *structCount = nil;
    NSNumber *classCount = nil;
    NSUInteger index = startIndex;

    while (index < lines.count) {
        NSString *line = [lines[index] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSNumber *count = [self countFromLine:line prefix:@"// Enums: "];
        if (count) {
            enumCount = count;
            index++;
            continue;
        }

        count = [self countFromLine:line prefix:@"// Structs: "];
        if (count) {
            structCount = count;
            index++;
            continue;
        }

        count = [self countFromLine:line prefix:@"// Classes: "];
        if (count) {
            classCount = count;
            index++;
            continue;
        }

        if (line.length == 0) {
            index++;
            continue;
        }
        break;
    }

    NSMutableDictionary *result = [@{ @"nextIndex": @(index) } mutableCopy];
    if (enumCount && structCount && classCount) {
        result[@"summary"] = @{
            @"enumCount": enumCount,
            @"structCount": structCount,
            @"classCount": classCount
        };
    }
    return result;
}

+ (nullable NSNumber *)countFromLine:(NSString *)line prefix:(NSString *)prefix {
    if (![line hasPrefix:prefix]) {
        return nil;
    }
    NSInteger value = [[line substringFromIndex:prefix.length] integerValue];
    return @(value);
}

+ (NSString *)declaredTypeNameFromDeclaration:(NSString *)declaration {
    for (NSString *keyword in @[ @"enum class ", @"struct ", @"class " ]) {
        if (![declaration hasPrefix:keyword]) {
            continue;
        }

        NSString *remainder = [declaration substringFromIndex:keyword.length];
        NSRange brace = [remainder rangeOfString:@"{"];
        if (brace.location != NSNotFound) {
            remainder = [remainder substringToIndex:brace.location];
        }
        NSRange colon = [remainder rangeOfString:@":"];
        if (colon.location != NSNotFound) {
            remainder = [remainder substringToIndex:colon.location];
        }

        return [remainder stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    return @"";
}

+ (NSString *)parentTypeNameFromDeclaration:(NSString *)declaration {
    NSRange colon = [declaration rangeOfString:@":"];
    if (colon.location == NSNotFound) {
        return @"";
    }

    NSString *tail = [declaration substringFromIndex:colon.location + 1];
    NSRange brace = [tail rangeOfString:@"{"];
    if (brace.location != NSNotFound) {
        tail = [tail substringToIndex:brace.location];
    }

    NSString *cleaned = [[[[tail stringByReplacingOccurrencesOfString:@"public " withString:@""]
        stringByReplacingOccurrencesOfString:@"protected " withString:@""]
        stringByReplacingOccurrencesOfString:@"private " withString:@""]
        stringByReplacingOccurrencesOfString:@"virtual " withString:@""];

    NSString *parent = [[[cleaned componentsSeparatedByString:@","] firstObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return parent ?: @"";
}

+ (nullable NSDictionary *)parseSizeMetadataFromLine:(NSString *)line {
    if (![line hasPrefix:@"// Size: "]) {
        return nil;
    }

    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
                regex = [NSRegularExpression regularExpressionWithPattern:@"^// Size: 0x([0-9A-Fa-f]+) \\(Inherited: 0x([0-9A-Fa-f]+)\\)$"
                                                            options:0
                                                              error:nil];
    });

    NSRange range = NSMakeRange(0, line.length);
    NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:range];
    if (!match || match.numberOfRanges < 3) {
        return nil;
    }

    NSString *sizeHex = [line substringWithRange:[match rangeAtIndex:1]];
    NSString *inheritedHex = [line substringWithRange:[match rangeAtIndex:2]];
    unsigned long long sizeValue = 0;
    unsigned long long inheritedValue = 0;
    [[NSScanner scannerWithString:sizeHex] scanHexLongLong:&sizeValue];
    [[NSScanner scannerWithString:inheritedHex] scanHexLongLong:&inheritedValue];
    return @{
        @"sizeBytes": @(sizeValue),
        @"inheritedSizeBytes": @(inheritedValue)
    };
}

+ (NSArray<NSDictionary *> *)parseFieldsFromBodyLines:(NSArray<NSString *> *)bodyLines {
    NSMutableArray<NSDictionary *> *fields = [NSMutableArray array];
    NSUInteger sourceOrder = 0;

    for (NSString *line in bodyLines) {
        NSDictionary *field = [self parseFieldFromLine:line sourceOrder:sourceOrder];
        if (!field) {
            continue;
        }
        [fields addObject:field];
        sourceOrder += 1;
    }

    return fields;
}

+ (nullable NSDictionary *)parseFieldFromLine:(NSString *)line sourceOrder:(NSUInteger)sourceOrder {
    NSRange commentRange = [line rangeOfString:@"//"];
    if (commentRange.location == NSNotFound) {
        return nil;
    }

    NSString *declarationWithSemicolon = [[line substringToIndex:commentRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![declarationWithSemicolon hasSuffix:@";"]) {
        return nil;
    }

    NSDictionary *offsetMetadata = [self parseOffsetComment:[[line substringFromIndex:commentRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    if (!offsetMetadata) {
        return nil;
    }

    NSString *declaration = [[declarationWithSemicolon substringToIndex:declarationWithSemicolon.length - 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDictionary *splitDeclaration = [self splitFieldDeclaration:declaration];
    if (!splitDeclaration) {
        return nil;
    }

    NSString *name = splitDeclaration[@"name"] ?: @"Field";
    return @{
        @"name": name,
        @"declaration": declaration,
        @"typeName": splitDeclaration[@"typeName"] ?: @"unknown",
        @"offsetBytes": offsetMetadata[@"offsetBytes"] ?: @0,
        @"sizeBytes": offsetMetadata[@"sizeBytes"] ?: @0,
        @"sourceOrder": @(sourceOrder),
        @"isPadding": @([name hasPrefix:@"Pad_0x"])
    };
}

+ (nullable NSDictionary *)splitFieldDeclaration:(NSString *)declaration {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"^(.+?)\\s+([A-Za-z_][A-Za-z0-9_]*)(\\[[^\\]]+\\])?(?:\\s*:\\s*\\d+)?$"
                                                            options:0
                                                              error:nil];
    });

    NSRange range = NSMakeRange(0, declaration.length);
    NSTextCheckingResult *match = [regex firstMatchInString:declaration options:0 range:range];
    if (!match || match.numberOfRanges < 3) {
        return nil;
    }

    NSString *typeName = [[declaration substringWithRange:[match rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *name = [[declaration substringWithRange:[match rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return @{
        @"typeName": typeName ?: @"unknown",
        @"name": name ?: @"Field"
    };
}

+ (nullable NSDictionary *)parseOffsetComment:(NSString *)comment {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"^//\\s*0x([0-9A-Fa-f]+)\\(0x([0-9A-Fa-f]+)\\)$"
                                                            options:0
                                                              error:nil];
    });

    NSRange range = NSMakeRange(0, comment.length);
    NSTextCheckingResult *match = [regex firstMatchInString:comment options:0 range:range];
    if (!match || match.numberOfRanges != 3) {
        return nil;
    }

    NSString *offsetHex = [comment substringWithRange:[match rangeAtIndex:1]];
    NSString *sizeHex = [comment substringWithRange:[match rangeAtIndex:2]];
    unsigned long long offsetValue = 0;
    unsigned long long sizeValue = 0;
    [[NSScanner scannerWithString:offsetHex] scanHexLongLong:&offsetValue];
    [[NSScanner scannerWithString:sizeHex] scanHexLongLong:&sizeValue];

    return @{
        @"offsetBytes": @(offsetValue),
        @"sizeBytes": @(sizeValue)
    };
}

@end
