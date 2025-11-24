import AVFoundation
import Dependencies
import DependenciesMacros
import Foundation
import Logging
import WhisperKit
import SherpaOnnx

#if canImport(FluidAudio)
import FluidAudio
#endif

private let transcriptionLogger = HexLog.transcription
private let modelsLogger = HexLog.models
private let parakeetLogger = HexLog.parakeet

@DependencyClient
public struct TranscriptionClient: Sendable {
  public var transcribe: @Sendable (URL, String, DecodingOptions, @escaping (Progress) -> Void) async throws -> String
  public var downloadModel: @Sendable (String, @escaping (Progress) -> Void) async throws -> Void
  public var deleteModel: @Sendable (String) async throws -> Void
  public var isModelDownloaded: @Sendable (String) async -> Bool = { _ in false }
  public var getRecommendedModels: @Sendable () async throws -> ModelSupport
  public var getAvailableModels: @Sendable () async throws -> [String]
}

extension TranscriptionClient: DependencyKey {
  public static var liveValue: Self {
    let live = TranscriptionClientLive()
    return Self(
      transcribe: { try await live.transcribe(url: $0, model: $1, options: $2, progressCallback: $3) },
      downloadModel: { try await live.downloadAndLoadModel(variant: $0, progressCallback: $1) },
      deleteModel: { try await live.deleteModel(variant: $0) },
      isModelDownloaded: { await live.isModelDownloaded($0) },
      getRecommendedModels: { await live.getRecommendedModels() },
      getAvailableModels: { try await live.getAvailableModels() }
    )
  }
}

public extension DependencyValues {
  var transcription: TranscriptionClient {
    get { self[TranscriptionClient.self] }
    set { self[TranscriptionClient.self] = newValue }
  }
}

public actor TranscriptionClientLive {
  private var whisperKit: WhisperKit?
  private var currentModelName: String?
  private var parakeet: ParakeetClient = ParakeetClient()
  private var senseVoice: SenseVoiceClient = SenseVoiceClient()

  @Dependency(\.huggingFace) var huggingFace

  private lazy var modelsBaseFolder: URL = {
    do {
      let appSupportURL = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      // Typically: .../Application Support/com.kitlangton.Hex
      let ourAppFolder = appSupportURL.appendingPathComponent("com.kitlangton.Hex", isDirectory: true)
      // Inside there, store everything in /models
      let baseURL = ourAppFolder.appendingPathComponent("models", isDirectory: true)
      try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
      return baseURL
    } catch {
      fatalError("Could not create Application Support folder: \(error)")
    }
  }()

  public init() {}

  public func downloadAndLoadModel(variant: String, progressCallback: @escaping (Progress) -> Void) async throws {
    if isParakeet(variant) {
      try await parakeet.ensureLoaded(modelName: variant, progress: progressCallback)
      currentModelName = variant
      return
    }

    if isSenseVoice(variant) {
        try await downloadModelIfNeeded(variant: variant, progressCallback: progressCallback)
        try await senseVoice.ensureLoaded(modelPath: modelPath(for: variant).path)
        currentModelName = variant
        return
    }

    // Resolve wildcard patterns or use direct name
    let variant = await resolveVariant(variant)
    if variant.isEmpty {
      throw NSError(domain: "TranscriptionClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot download model: Empty model name"])
    }

    let overallProgress = Progress(totalUnitCount: 100)
    overallProgress.completedUnitCount = 0
    progressCallback(overallProgress)

    modelsLogger.info("Preparing model download and load for \(variant)")

    if !(await isModelDownloaded(variant)) {
      try await downloadModelIfNeeded(variant: variant) { downloadProgress in
        let fraction = downloadProgress.fractionCompleted * 0.5
        overallProgress.completedUnitCount = Int64(fraction * 100)
        progressCallback(overallProgress)
      }
    } else {
      overallProgress.completedUnitCount = 50
      progressCallback(overallProgress)
    }

    try await loadWhisperKitModel(variant) { loadingProgress in
      let fraction = 0.5 + (loadingProgress.fractionCompleted * 0.5)
      overallProgress.completedUnitCount = Int64(fraction * 100)
      progressCallback(overallProgress)
    }

    overallProgress.completedUnitCount = 100
    progressCallback(overallProgress)
  }

  public func deleteModel(variant: String) async throws {
    if isParakeet(variant) {
      try await parakeet.deleteCaches(modelName: variant)
      if currentModelName == variant { unloadCurrentModel() }
      return
    }
    let modelFolder = modelPath(for: variant)
    guard FileManager.default.fileExists(atPath: modelFolder.path) else { return }
    if currentModelName == variant { unloadCurrentModel() }
    try FileManager.default.removeItem(at: modelFolder)
    modelsLogger.info("Deleted model \(variant)")
  }

  public func isModelDownloaded(_ modelName: String) async -> Bool {
    if isParakeet(modelName) {
      return await parakeet.isModelAvailable(modelName)
    }
    if isSenseVoice(modelName) {
        return await senseVoice.isModelAvailable(modelPath(for: modelName).path)
    }

    let modelFolderPath = modelPath(for: modelName).path
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: modelFolderPath) else { return false }

    do {
      let contents = try fileManager.contentsOfDirectory(atPath: modelFolderPath)
      guard !contents.isEmpty else { return false }

      let hasModelFiles = contents.contains { $0.hasSuffix(".mlmodelc") || $0.contains("model") }

      let tPath = tokenizerPath(for: modelName)
      let hasTokenizer = fileManager.fileExists(atPath: tPath.appendingPathComponent("tokenizer.json").path)

      return hasModelFiles && hasTokenizer
    } catch {
      return false
    }
  }

  public func getRecommendedModels() async -> ModelSupport {
    await WhisperKit.recommendedRemoteModels()
  }

  public func getAvailableModels() async throws -> [String] {
    var names = try await WhisperKit.fetchAvailableModels()
    #if canImport(FluidAudio)
    for model in ParakeetModel.allCases.reversed() {
      if !names.contains(model.identifier) { names.insert(model.identifier, at: 0) }
    }
    #endif
    return names
  }

  public func transcribe(url: URL, model: String, options: DecodingOptions, progressCallback: @escaping (Progress) -> Void) async throws -> String {
    let startAll = Date()
    if isParakeet(model) {
      transcriptionLogger.notice("Transcribing with Parakeet model=\(model) file=\(url.lastPathComponent)")
      let startLoad = Date()
      try await downloadAndLoadModel(variant: model) { p in progressCallback(p) }
      transcriptionLogger.info("Parakeet ensureLoaded took \(String(format: "%.2f", Date().timeIntervalSince(startLoad)))s")
      let preparedClip = try ParakeetClipPreparer.ensureMinimumDuration(url: url, logger: parakeetLogger)
      defer { preparedClip.cleanup() }
      let startTx = Date()
      let text = try await parakeet.transcribe(preparedClip.url)
      transcriptionLogger.info("Parakeet transcription took \(String(format: "%.2f", Date().timeIntervalSince(startTx)))s")
      transcriptionLogger.info("Parakeet request total elapsed \(String(format: "%.2f", Date().timeIntervalSince(startAll)))s")
      return text
    }

    if isSenseVoice(model) {
        transcriptionLogger.notice("Transcribing with SenseVoice model=\(model)")
        try await downloadAndLoadModel(variant: model) { p in progressCallback(p) }
        let text = try await senseVoice.transcribe(audioURL: url)
        transcriptionLogger.info("SenseVoice transcription finished")
        return text
    }

    let model = await resolveVariant(model)
    if whisperKit == nil || model != currentModelName {
      unloadCurrentModel()
      let startLoad = Date()
      try await downloadAndLoadModel(variant: model) { p in progressCallback(p) }
      let loadDuration = Date().timeIntervalSince(startLoad)
      transcriptionLogger.info("WhisperKit ensureLoaded model=\(model) took \(String(format: "%.2f", loadDuration))s")
    }

    guard let whisperKit = whisperKit else {
      throw NSError(domain: "TranscriptionClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize WhisperKit for model: \(model)"])
    }

    transcriptionLogger.notice("Transcribing with WhisperKit model=\(model) file=\(url.lastPathComponent)")
    let startTx = Date()
    let results = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options)
    transcriptionLogger.info("WhisperKit transcription took \(String(format: "%.2f", Date().timeIntervalSince(startTx)))s")
    transcriptionLogger.info("WhisperKit request total elapsed \(String(format: "%.2f", Date().timeIntervalSince(startAll)))s")
    return results.map(\.text).joined(separator: " ")
  }

  private func resolveVariant(_ variant: String) async -> String {
    if variant.contains("/") { return variant } // Assume direct User/Repo
    if !(variant.contains("*") || variant.contains("?")) { return variant }
    let names: [String]
    do { names = try await WhisperKit.fetchAvailableModels() } catch { return variant }
    let matches = names.filter { fnmatch(variant, $0, 0) == 0 }
    guard !matches.isEmpty else { return variant }
    var downloaded: [String] = []
    for name in matches { if await isModelDownloaded(name) { downloaded.append(name) } }
    if !downloaded.isEmpty {
      if let nonTurbo = downloaded.first(where: { !$0.localizedCaseInsensitiveContains("turbo") }) { return nonTurbo }
      return downloaded[0]
    }
    if let nonTurbo = matches.first(where: { !$0.localizedCaseInsensitiveContains("turbo") }) { return nonTurbo }
    return matches[0]
  }

  private func isParakeet(_ name: String) -> Bool {
    ParakeetModel(rawValue: name) != nil
  }

  private func isSenseVoice(_ name: String) -> Bool {
    name.localizedCaseInsensitiveContains("SenseVoice")
  }

  private func modelPath(for variant: String) -> URL {
    if variant.contains("/") {
        let components = variant.components(separatedBy: "/")
        if components.count >= 2 {
            var path = modelsBaseFolder
            for component in components {
                path.appendPathComponent(component)
            }
            return path
        }
    }

    // Default legacy path (argmaxinc/whisperkit-coreml)
    let sanitizedVariant = variant.components(separatedBy: CharacterSet(charactersIn: "./\\")).joined(separator: "_")
    return modelsBaseFolder
      .appendingPathComponent("argmaxinc")
      .appendingPathComponent("whisperkit-coreml")
      .appendingPathComponent(sanitizedVariant, isDirectory: true)
  }

  private func tokenizerPath(for variant: String) -> URL {
    let modelFolder = modelPath(for: variant)
    let tokenizerSubdir = modelFolder.appendingPathComponent("tokenizer", isDirectory: true)
    // Check if tokenizer directory exists
    return FileManager.default.fileExists(atPath: tokenizerSubdir.path) ? tokenizerSubdir : modelFolder
  }

  private func unloadCurrentModel() {
    whisperKit = nil
    currentModelName = nil
  }

  private func downloadModelIfNeeded(variant: String, progressCallback: @escaping (Progress) -> Void) async throws {
    let modelFolder = modelPath(for: variant)
    let isDownloaded = await isModelDownloaded(variant)
    if FileManager.default.fileExists(atPath: modelFolder.path), !isDownloaded {
      try? FileManager.default.removeItem(at: modelFolder)
    }
    if isDownloaded { return }

    modelsLogger.info("Downloading model \(variant)")
    let parentDir = modelFolder.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

    if isSenseVoice(variant) {
        try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)
        let files = ["model.int8.onnx", "tokens.txt"]
        var repo = variant
        if variant == "FunAudioLLM/SenseVoiceSmall" {
            repo = "sherpa-ai/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"
        }

        let totalProgress = Progress(totalUnitCount: Int64(files.count * 100))
        progressCallback(totalProgress)
        for (index, file) in files.enumerated() {
            let encodedFile = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file
            let urlStr = "https://huggingface.co/\(repo)/resolve/main/\(encodedFile)"
            guard let url = URL(string: urlStr) else { continue }
            let dest = modelFolder.appendingPathComponent(file)
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: dest)
            totalProgress.completedUnitCount = Int64((index + 1) * 100)
            progressCallback(totalProgress)
        }
        return
    }

    // Generic User/Repo -> Use HuggingFaceClient
    if variant.contains("/") {
        try await huggingFace.download(variant, modelFolder, progressCallback)
        return
    }

    // Default WhisperKit (argmaxinc)
    do {
      let tempFolder = try await WhisperKit.download(
        variant: variant,
        downloadBase: nil,
        useBackgroundSession: false,
        progressCallback: { progressCallback($0) }
      )
      try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)
      try moveContents(of: tempFolder, to: modelFolder)
      modelsLogger.info("Downloaded model to \(modelFolder.path)")
    } catch {
      if FileManager.default.fileExists(atPath: modelFolder.path) {
        try? FileManager.default.removeItem(at: modelFolder)
      }
      modelsLogger.error("Error downloading model \(variant): \(error.localizedDescription)")
      throw error
    }
  }

  private func loadWhisperKitModel(_ modelName: String, progressCallback: @escaping (Progress) -> Void) async throws {
    let loadingProgress = Progress(totalUnitCount: 100)
    loadingProgress.completedUnitCount = 0
    progressCallback(loadingProgress)

    let modelFolder = modelPath(for: modelName)
    let tPath = tokenizerPath(for: modelName)

    let config = WhisperKitConfig(
      model: modelName,
      modelFolder: modelFolder.path,
      tokenizerFolder: tPath,
      prewarm: false,
      load: true
    )

    whisperKit = try await WhisperKit(config)
    currentModelName = modelName
    loadingProgress.completedUnitCount = 100
    progressCallback(loadingProgress)
    modelsLogger.info("Loaded WhisperKit model \(modelName)")
  }

  private func moveContents(of sourceFolder: URL, to destFolder: URL) throws {
    let fileManager = FileManager.default
    let items = try fileManager.contentsOfDirectory(atPath: sourceFolder.path)
    for item in items {
      let src = sourceFolder.appendingPathComponent(item)
      let dst = destFolder.appendingPathComponent(item)
      try fileManager.moveItem(at: src, to: dst)
    }
  }
}
