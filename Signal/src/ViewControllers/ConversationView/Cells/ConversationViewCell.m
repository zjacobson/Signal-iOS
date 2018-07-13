//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationViewCell.h"
#import "ConversationViewItem.h"
#import <SignalMessaging/UIView+OWS.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ConversationViewCell

// `[UIView init]` invokes `[self initWithFrame:...]`.
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self configureTopSpacingView];
    }

    return self;
}

- (void)configureTopSpacingView
{
    // Ensure only called once.
    OWSAssert(!self.topSpacingView);

    _topSpacingView = [UIView containerView];
    self.topSpacingView.userInteractionEnabled = YES;
    [self.contentView addSubview:self.topSpacingView];
    [self.topSpacingView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [self.topSpacingView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [self.topSpacingView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
}

@end

NS_ASSUME_NONNULL_END
