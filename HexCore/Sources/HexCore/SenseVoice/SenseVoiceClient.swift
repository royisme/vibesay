import AVFoundation
import Dependencies
import Foundation
import Logging
import SherpaOnnx

public actor SenseVoiceClient {
    private var recognizer: OfflineRecognizer?
    private var currentModelPath: String?
    private let logger = Logger(label: "SenseVoice")

    public init() {}

    public func isModelAvailable(_ modelPath: String) async -> Bool {
        let tokens = URL(fileURLWithPath: modelPath).appendingPathComponent("tokens.txt").path
        let model = URL(fileURLWithPath: modelPath).appendingPathComponent("model.int8.onnx").path
        let fallbackModel = URL(fileURLWithPath: modelPath).appendingPathComponent("model.onnx").path

        return FileManager.default.fileExists(atPath: tokens) &&
               (FileManager.default.fileExists(atPath: model) || FileManager.default.fileExists(atPath: fallbackModel))
    }

    public func ensureLoaded(modelPath: String) throws {
        if currentModelPath == modelPath && recognizer != nil { return }

        let tokens = URL(fileURLWithPath: modelPath).appendingPathComponent("tokens.txt").path
        let model = URL(fileURLWithPath: modelPath).appendingPathComponent("model.int8.onnx").path
        let fallbackModel = URL(fileURLWithPath: modelPath).appendingPathComponent("model.onnx").path
        let finalModel = FileManager.default.fileExists(atPath: model) ? model : fallbackModel

        guard FileManager.default.fileExists(atPath: tokens),
              FileManager.default.fileExists(atPath: finalModel) else {
             throw NSError(domain: "SenseVoice", code: 404, userInfo: [NSLocalizedDescriptionKey: "Missing model files in \(modelPath)"])
        }

        logger.info("Loading SenseVoice model from \(finalModel)")

        let featConfig = OfflineFeatureExtractorConfig(
            sampleRate: 16000,
            featureDim: 80
        )

        let senseVoiceConfig = OfflineSenseVoiceModelConfig(
            model: finalModel,
            language: "auto",
            useItn: true
        )

        let modelConfig = OfflineModelConfig(
            transducer: .init(),
            paraformer: .init(),
            nemoCtc: .init(),
            whisper: .init(),
            tdnn: .init(),
            zipformer: .init(),
            zipformer2Ctc: .init(),
            senseVoice: senseVoiceConfig,
            tokens: tokens,
            numThreads: 4,
            debug: false,
            provider: "cpu",
            modelType: "sense_voice"
        )

        let config = OfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            lmConfig: .init(),
            ctcFstDecoderConfig: .init()
        )

        self.recognizer = try OfflineRecognizer(config: config)
        self.currentModelPath = modelPath
    }

    public func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer else {
            throw NSError(domain: "SenseVoice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not initialized"])
        }

        logger.info("Transcribing audio: \(audioURL.lastPathComponent)")

        let (samples, sampleRate) = try readAudioSamples(from: audioURL)

        let stream = try recognizer.createStream()
        stream.acceptWaveform(samples: samples, sampleRate: sampleRate)

        try recognizer.decode(stream: stream)
        let result = recognizer.getResult(stream: stream)

        logger.info("Transcription complete: \(result.text.count) chars")
        return result.text
    }

    private func readAudioSamples(from url: URL) throws -> (samples: [Float], sampleRate: Int) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
             throw NSError(domain: "SenseVoice", code: -2, userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed"])
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
             throw NSError(domain: "SenseVoice", code: -3, userInfo: [NSLocalizedDescriptionKey: "No float channel data"])
        }

        // Use first channel (mono)
        let ptr = channelData[0]
        let count = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: ptr, count: count))

        return (samples, Int(format.sampleRate))
    }
}
