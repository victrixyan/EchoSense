//
//  SMILEBridge.mm
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

#import "SMILEBridge.h"
#include <vector>
#include <iostream>
#include <cmath>

@interface SMILEBridge () {
    int sampleRate_;
    std::vector<float> featureBuffer_;
}
@end

@implementation SMILEBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        sampleRate_ = 16000;  // Default to 16kHz
        featureBuffer_.reserve(9);  // Pre-allocate for 9 features
    }
    return self;
}

- (void)initialize:(int)sampleRate {
    sampleRate_ = sampleRate;
}

- (NSArray<NSNumber *> *)extractFeaturesNormalized:(const float *)audioData length:(int)length {
    if (audioData == nil || length <= 0) {
        return @[];
    }
    
    NSMutableArray<NSNumber *> *features = [NSMutableArray array];
    
    // Compute basic acoustic features from raw audio
    // These are placeholder implementations - in production, would use full OpenSMILE
    
    // 1. RMS Energy
    float rmsEnergy = 0.0f;
    for (int i = 0; i < length; i++) {
        rmsEnergy += audioData[i] * audioData[i];
    }
    rmsEnergy = sqrtf(rmsEnergy / length);
    [features addObject:@(fminf(rmsEnergy, 1.0f))];  // Normalize to 0-1
    
    // 2. Zero Crossing Rate
    float zcr = 0.0f;
    for (int i = 1; i < length; i++) {
        if ((audioData[i] >= 0 && audioData[i-1] < 0) ||
            (audioData[i] < 0 && audioData[i-1] >= 0)) {
            zcr += 1.0f;
        }
    }
    zcr = zcr / length;
    [features addObject:@(zcr)];
    
    // 3-9. Additional placeholder features
    for (int i = 0; i < 7; i++) {
        [features addObject:@(0.5f)];  // Default normalized value
    }
    
    return features;
}

@end
