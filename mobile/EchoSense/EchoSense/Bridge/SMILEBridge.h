//
//  SMILEBridge.h
//  EchoSense
//
//  Objective-C bridge for OpenSMILE acoustic feature extraction
//  Compatible with Swift via bridging header
//
//  Created by Victrix Yan on 2026/2/23.
//

#ifndef SMILEBridge_h
#define SMILEBridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SMILEBridge : NSObject

/// Initialize the SMILE feature extractor with sample rate
/// @param sampleRate Sample rate in Hz
- (void)initialize:(int)sampleRate;

/// Extract acoustic features from audio data (normalized)
/// @param audioData Raw audio samples as float array
/// @param length Number of samples
/// @return Array of normalized features
- (NSArray<NSNumber *> *)extractFeaturesNormalized:(const float *)audioData length:(int)length;

@end

NS_ASSUME_NONNULL_END

#endif /* SMILEBridge_h */
