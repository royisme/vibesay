import Foundation
import Dependencies

public struct HuggingFaceClient: Sendable {
    public var download: @Sendable (_ repoId: String, _ destination: URL, _ progress: @escaping (Progress) -> Void) async throws -> Void
}

extension HuggingFaceClient: DependencyKey {
    public static let liveValue = HuggingFaceClient(
        download: { repoId, destination, progress in
            let encodedRepoId = repoId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repoId
            guard let apiURL = URL(string: "https://huggingface.co/api/models/\(encodedRepoId)/tree/main?recursive=true") else {
                 throw NSError(domain: "HuggingFaceClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Repo ID: \(repoId)"])
            }

            let (data, _) = try await URLSession.shared.data(from: apiURL)

            struct HFFileDetailed: Decodable {
                let path: String
                let type: String
                let size: Int?
            }

             let detailedFiles = try JSONDecoder().decode([HFFileDetailed].self, from: data)
                .filter { $0.type == "file" }

            let totalBytes = detailedFiles.reduce(0) { $0 + ($1.size ?? 0) }
            let overallProgress = Progress(totalUnitCount: Int64(totalBytes))

            for file in detailedFiles {
                let encodedPath = file.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.path
                guard let fileURL = URL(string: "https://huggingface.co/\(encodedRepoId)/resolve/main/\(encodedPath)") else {
                     throw NSError(domain: "HuggingFaceClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid file URL for path: \(file.path)"])
                }
                let destURL = destination.appendingPathComponent(file.path)

                try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                let (tempURL, _) = try await URLSession.shared.download(from: fileURL)

                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)

                overallProgress.completedUnitCount += Int64(file.size ?? 0)
                progress(overallProgress)
            }
        }
    )
}

public extension DependencyValues {
    var huggingFace: HuggingFaceClient {
        get { self[HuggingFaceClient.self] }
        set { self[HuggingFaceClient.self] = newValue }
    }
}
