//
//  SpeechManager.swift
//  EchoSense
//
//  Created by Victrix Yan on 2026/2/23.
//

import AVFoundation
import Foundation
import Combine
import os.log

/// Manages microphone access, audio recording, and preprocessing.
/// Captures raw PCM audio for SMILE feature extraction and CoreML inference.
class SpeechManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private let logger = Logger(subsystem: "com.echosense.speech", category: "recording")
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var audioSession: AVAudioSession?
    private var recordedURL: URL?
    
    struct AudioRecordingData {
        let pcmBuffer: [Float]
        let sampleRate: Int
        let duration: TimeInterval
    }
    
    override init() {
        super.init()
        // Delay audio session setup until first use to avoid privacy check during app launch
    }
    
    private func setupAudioSession() {
        // Only setup once
        guard audioSession == nil else { return }
        
        do {
            audioSession = AVAudioSession.sharedInstance()
            try audioSession?.setCategory(.record, mode: .measurement, options: [])
            try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Audio session setup failed: \(error.localizedDescription)")
            errorMessage = "Failed to configure audio session"
        }
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        setupAudioSession()
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startRecording() {
        setupAudioSession()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordedURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        
        guard let recordedURL = recordedURL else {
            errorMessage = "Failed to create recording file"
            return
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordedURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingDuration = 0
                self.errorMessage = nil
            }
            
            startRecordingTimer()
            logger.info("Recording started at \(recordedURL.lastPathComponent)")
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() -> AudioRecordingData? {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        guard let recordedURL = recordedURL else {
            logger.error("No recorded URL available")
            return nil
        }
        
        // Convert audio file to PCM data
        do {
            let audioFile = try AVAudioFile(forReading: recordedURL)
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: AVAudioFrameCount(audioFile.length)
            ) else {
                logger.error("Failed to create PCM buffer")
                return nil
            }
            
            try audioFile.read(into: pcmBuffer)
            
            guard let audioData = pcmBuffer.floatChannelData?[0] else {
                logger.error("Failed to access PCM data")
                return nil
            }
            
            let pcmData = Array(UnsafeBufferPointer(start: audioData, count: Int(pcmBuffer.frameLength)))
            let sampleRate = Int(audioFile.processingFormat.sampleRate)
            let duration = TimeInterval(audioFile.length) / audioFile.processingFormat.sampleRate
            
            logger.info("Audio recorded: \(duration)s at \(sampleRate)Hz, \(pcmData.count) samples")
            
            return AudioRecordingData(pcmBuffer: pcmData, sampleRate: sampleRate, duration: duration)
        } catch {
            logger.error("Failed to process audio: \(error.localizedDescription)")
            errorMessage = "Failed to process audio: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.recordingDuration += 0.1
            }
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            logger.error("Recording failed")
            errorMessage = "Recording failed"
        }
    }
}
