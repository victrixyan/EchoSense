//
//  SMILEBridge.h
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

#ifndef SMILEBridge_h
#define SMILEBridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SMILEBridge : NSObject

/// Initialize the SMILE feature extractor
- (instancetype)init;

/// Extract acoustic features from audio data
/// @param audioData Raw audio samples
/// @param sampleRate Sample rate in Hz
/// @return Dictionary with extracted features or nil on error
- (NSDictionary<NSString *, NSNumber *> *)extractFeaturesFromAudioData:(NSData *)audioData
                                                            sampleRate:(int)sampleRate;

@end

NS_ASSUME_NONNULL_END

#endif /* SMILEBridge_h */
