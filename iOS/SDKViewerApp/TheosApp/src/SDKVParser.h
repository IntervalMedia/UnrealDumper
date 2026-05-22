#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SDKVParser : NSObject
+ (nullable NSDictionary *)parseAIOHeader:(NSString *)aioHeader scriptJSON:(nullable NSString *)scriptJSON error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
