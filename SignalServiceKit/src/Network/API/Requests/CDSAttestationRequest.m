//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "CDSAttestationRequest.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CDSAttestationRequest

- (TSRequest *)initWithURL:(NSURL *)URL
                    method:(NSString *)method
                parameters:(nullable NSDictionary<NSString *, id> *)parameters
              authUsername:(NSString *)authUsername
              authPassword:(NSString *)authPassword
{
    OWSAssert(authUsername.length > 0);
    OWSAssert(authPassword.length > 0);

    if (self = [super initWithURL:URL method:method parameters:parameters]) {
        self.authUsername = authUsername;
        self.authPassword = authPassword;
    }

    return self;
}

@end

NS_ASSUME_NONNULL_END
