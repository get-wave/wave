import Foundation
import FluidAudio

enum ParakeetModel: String, CaseIterable, Identifiable {
    case ultra, v2

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ultra: return "Parakeet Ultra"
        case .v2: return "Parakeet v2"
        }
    }

    var detail: String {
        switch self {
        case .ultra: return "25 European languages · about 630 MB"
        case .v2: return "English only · highest accuracy"
        }
    }

    fileprivate var version: AsrModelVersion {
        switch self {
        case .ultra: return .ultra
        case .v2: return .v2
        }
    }

    fileprivate var cacheDirectory: URL { AsrModels.defaultCacheDirectory(for: version) }
}

@MainActor
final class ParakeetService {
    private var manager: AsrManager?
    private(set) var loadedModel: ParakeetModel?

    func isDownloaded(_ model: ParakeetModel) -> Bool {
        AsrModels.modelsExist(at: model.cacheDirectory, version: model.version)
    }

    /// Downloads the model if needed, then loads it onto the Neural Engine.
    func load(_ model: ParakeetModel, progress: @escaping @MainActor (Double) -> Void) async throws {
        if loadedModel == model, manager != nil { return }
        unload()
        let models = try await AsrModels.downloadAndLoad(version: model.version, progressHandler: { update in
            Task { @MainActor in progress(update.fractionCompleted) }
        })
        let asrManager = AsrManager(config: .default)
        try await asrManager.loadModels(models)
        manager = asrManager
        loadedModel = model
    }

    func unload() {
        manager = nil
        loadedModel = nil
    }

    func delete(_ model: ParakeetModel) {
        if loadedModel == model { unload() }
        try? FileManager.default.removeItem(at: model.cacheDirectory)
    }

    func transcribe(_ samples: [Float]) async throws -> String? {
        guard let manager else { return nil }
        var decoderState = TdtDecoderState.make()
        return try await manager.transcribe(samples, decoderState: &decoderState).text
    }
}
