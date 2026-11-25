import Foundation
import CoreGraphics

struct TransformProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var prompt: String
    var keyCode: UInt16
    var modifiers: UInt64
    var isEnabled: Bool
    let isBuiltIn: Bool

    static let polishID = UUID(uuidString: "2C6B2D87-1C1D-4D75-B52A-7EDCB6F66CF1")!
    static let promptEngineerID = UUID(uuidString: "F64DBF93-4F16-47F8-9E44-4E5BB2B8E4D0")!
    static let turnIntoListID = UUID(uuidString: "69A98013-3CE1-4B5C-8D4B-6E50C3EE8C1F")!
    static let translateToEnglishID = UUID(uuidString: "8E8FC4E1-5F47-43E0-BB9C-27C9A04E2A7A")!
    static let empathizeID = UUID(uuidString: "A3C9F269-6D75-4A4B-9B2B-50B5D7D3B0A1")!
    static let makeConciseID = UUID(uuidString: "4B2A7A77-4B5F-4E12-9A86-4A8CE60D1F36")!

    static let polish = TransformProfile(
        id: polishID,
        name: "Polish",
        prompt: """
        Rewrite the selected text to be clear, concise, and grammatically correct.

        Apply these rules in order:
        1. Fix grammar, spelling, and punctuation.
        2. Make the text more concise without removing necessary meaning.
        3. Reword unclear sentences.
        4. Reorder ideas only when it improves readability.
        5. Add paragraph breaks or light structure only when it improves readability.

        Preserve the author's meaning, intent, tone, technical terms, names, URLs, and important formatting. Do not add facts, claims, greetings, or commentary. Return only the rewritten text.
        """,
        keyCode: 18,
        modifiers: CGEventFlags.maskAlternate.rawValue,
        isEnabled: true,
        isBuiltIn: true
    )

    static let promptEngineer = TransformProfile(
        id: promptEngineerID,
        name: "Prompt Engineer",
        prompt: "Rewrite the selected text as a clear, self-contained prompt for an AI assistant. Preserve the user's intent and all important details. Make the task explicit, add useful context only when it is already implied, state constraints and the desired output format when they are apparent, and remove ambiguity without inventing requirements. Return only the rewritten prompt.",
        keyCode: 19,
        modifiers: CGEventFlags.maskAlternate.rawValue,
        isEnabled: true,
        isBuiltIn: true
    )

    static let turnIntoList = TransformProfile(
        id: turnIntoListID,
        name: "Turn into a List",
        prompt: "Rewrite the selected text as a clear, scannable list. Preserve every important fact and the original intent. Use short bullet points, one idea per item, and group related items when helpful. Do not add commentary or information. Return only the list.",
        keyCode: 0,
        modifiers: 0,
        isEnabled: true,
        isBuiltIn: false
    )

    static let translateToEnglish = TransformProfile(
        id: translateToEnglishID,
        name: "Translate to English",
        prompt: "Translate the selected text into natural, idiomatic English. Preserve the meaning, tone, names, numbers, URLs, and formatting. Do not summarize, explain, or add information. Return only the translation.",
        keyCode: 0,
        modifiers: 0,
        isEnabled: true,
        isBuiltIn: false
    )

    static let empathize = TransformProfile(
        id: empathizeID,
        name: "Empathize",
        prompt: "Rewrite the selected text in a warm, empathetic, and respectful tone. Acknowledge the other person's perspective when appropriate without sounding patronizing. Preserve the original intent, facts, and level of directness. Do not add promises or commentary. Return only the rewritten text.",
        keyCode: 0,
        modifiers: 0,
        isEnabled: true,
        isBuiltIn: false
    )

    static let makeConcise = TransformProfile(
        id: makeConciseID,
        name: "Make More Concise",
        prompt: "Rewrite the selected text as concisely as possible while preserving all essential meaning, facts, commitments, and tone. Remove repetition, filler, and unnecessary words. Do not introduce new information. Return only the rewritten text.",
        keyCode: 0,
        modifiers: 0,
        isEnabled: true,
        isBuiltIn: false
    )

    static let defaultSlotProfiles = [promptEngineer, turnIntoList, translateToEnglish, empathize, makeConcise]
}

@Observable
final class TransformManager {
    static let maxTransformCount = 9

    private(set) var polish: TransformProfile
    private(set) var transforms: [TransformProfile]

    var allTransforms: [TransformProfile] { [polish] + transforms }

    init() {
        if let data = UserDefaults.standard.data(forKey: "transformProfiles"),
           let saved = try? JSONDecoder().decode([TransformProfile].self, from: data) {
            polish = saved.first(where: { $0.id == TransformProfile.polishID }) ?? .polish
            let savedSlots = saved.filter { $0.id != TransformProfile.polishID }
            let shouldAddNewPresets = UserDefaults.standard.integer(forKey: "transformProfilesVersion") < 2
            let defaultIDs = Set(TransformProfile.defaultSlotProfiles.map(\.id))
            var loadedSlots: [TransformProfile]
            if shouldAddNewPresets {
                loadedSlots = TransformProfile.defaultSlotProfiles.map { preset in
                    savedSlots.first(where: { $0.id == preset.id }) ?? preset
                }
                loadedSlots += savedSlots.filter { !defaultIDs.contains($0.id) }
            } else {
                loadedSlots = savedSlots
                if !loadedSlots.contains(where: { $0.id == TransformProfile.promptEngineerID }) {
                    loadedSlots.insert(.promptEngineer, at: 0)
                }
            }
            transforms = Array(loadedSlots.prefix(Self.maxTransformCount))
        } else {
            polish = .polish
            transforms = TransformProfile.defaultSlotProfiles
        }
    }

    func add(name: String, prompt: String, keyCode: UInt16, modifiers: UInt64) {
        guard transforms.count < Self.maxTransformCount else { return }
        transforms.append(TransformProfile(
            id: UUID(),
            name: name,
            prompt: prompt,
            keyCode: keyCode,
            modifiers: modifiers,
            isEnabled: true,
            isBuiltIn: false
        ))
        save()
    }

    func update(_ transform: TransformProfile) {
        if transform.id == TransformProfile.polishID {
            polish = transform
            save()
            return
        }
        guard let index = transforms.firstIndex(where: { $0.id == transform.id }) else { return }
        transforms[index] = transform
        save()
    }

    func remove(_ transform: TransformProfile) {
        guard !transform.isBuiltIn else { return }
        transforms.removeAll { $0.id == transform.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(allTransforms) {
            UserDefaults.standard.set(data, forKey: "transformProfiles")
            UserDefaults.standard.set(2, forKey: "transformProfilesVersion")
        }
    }
}

struct AppProfile: Identifiable, Codable, Equatable {
    var id: String { bundleID }
    let bundleID: String
    let appName: String
    /// The transform run on dictations in this app; nil pastes the dictation as spoken.
    var transformID: UUID?
}

struct InstalledApp: Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
}

@Observable
final class AppProfileManager {
    private(set) var profiles: [AppProfile] = []

    init() {
        guard let data = UserDefaults.standard.data(forKey: "appProfiles"),
              let decoded = try? JSONDecoder().decode([AppProfile].self, from: data)
        else { return }
        profiles = decoded
    }

    func profile(for bundleID: String?) -> AppProfile? {
        guard let bundleID else { return nil }
        return profiles.first { $0.bundleID == bundleID }
    }

    func add(_ app: InstalledApp, transformID: UUID?) {
        guard profile(for: app.bundleID) == nil else { return }
        profiles.append(AppProfile(bundleID: app.bundleID, appName: app.name, transformID: transformID))
        profiles.sort { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        save()
    }

    func setTransform(_ transformID: UUID?, for bundleID: String) {
        guard let index = profiles.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        profiles[index].transformID = transformID
        save()
    }

    func remove(_ bundleID: String) {
        profiles.removeAll { $0.bundleID == bundleID }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "appProfiles")
        }
    }
}
