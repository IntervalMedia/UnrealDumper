#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SDKVPointerGenerator : NSObject
+ (NSString *)generateCPPWithBaseExpression:(NSString *)baseExpression
                                    offsets:(NSArray<NSNumber *> *)offsets
                                 resultType:(NSString *)resultType
                                 resultName:(NSString *)resultName;
+ (NSArray<NSNumber *> *)parseOffsetsFromText:(NSString *)text;
@end

NS_ASSUME_NONNULL_END
