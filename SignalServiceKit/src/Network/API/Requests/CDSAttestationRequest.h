//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface CDSAttestationRequest : TSRequest

- (instancetype)init NS_UNAVAILABLE;

- (TSRequest *)initWithURL:(NSURL *)URL
                    method:(NSString *)method
                parameters:(nullable NSDictionary<NSString *, id> *)parameters
              authUsername:(NSString *)username
              authPassword:(NSString *)authPassword;

@end

NS_ASSUME_NONNULL_END
