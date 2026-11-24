import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case groq, openai, openrouter, ollama, lmstudio, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .ollama: return "Ollama"
        case .lmstudio: return "LM Studio"
        case .custom: return "Custom"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1"
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .lmstudio: return "http://localhost:1234/v1"
        case .custom: return ""
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .groq, .openai, .openrouter: return true
        case .ollama, .lmstudio, .custom: return false
        }
    }

    var acceptsAPIKey: Bool { self != .ollama && self != .lmstudio }

    var runsOnThisMac: Bool { self == .ollama || self == .lmstudio }

    var keyPlaceholder: String {
        switch self {
        case .groq: return "API Key (gsk_...)"
        case .openai: return "API Key (sk-...)"
        case .openrouter: return "API Key (sk-or-...)"
        default: return "API Key (optional)"
        }
    }

    var defaultChatModel: String {
        switch self {
        case .groq: return "openai/gpt-oss-20b"
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openai/gpt-oss-20b"
        case .ollama: return "llama3.2"
        case .lmstudio, .custom: return ""
        }
    }

    /// Speech-to-text models offered for providers with an /audio/transcriptions endpoint.
    var transcriptionModels: [String] {
        switch self {
        case .groq: return ["whisper-large-v3-turbo", "whisper-large-v3"]
        case .openai: return ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"]
        case .custom: return ["whisper-1"]
        default: return []
        }
    }

    var supportsTranscription: Bool { !transcriptionModels.isEmpty }

    var keychainAccount: String { "\(rawValue)APIKey" }
}
