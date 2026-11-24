import Foundation
import SwiftUI

enum DictationMode: String, CaseIterable {
    case pushToTalk = "Push to Talk"
    case toggle = "Toggle"
}

enum TranscriptionProvider: String {
    case local = "local"
    case groq = "groq"
}

enum AppStatus: Equatable {
    case idle
    case recording
    case transcribing
    case error(String)
}

enum GroqAPIStatus: Equatable {
    case unknown
    case checking
    case operational
    case error(String)
}

@Observable
@MainActor
final class AppState {
    // MARK: - State
    var status: AppStatus = .idle
    var isOnboardingComplete: Bool {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete") }
    }
    var showOnboarding = false

    // MARK: - Settings
    var dictationMode: DictationMode {
        didSet { UserDefaults.standard.set(dictationMode.rawValue, forKey: "dictationMode") }
    }
    var hotkeyKeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(hotkeyKeyCode), forKey: "hotkeyKeyCode") }
    }
    var hotkeyModifiers: UInt64 {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }
    var includePunctuation: Bool {
        didSet { UserDefaults.standard.set(includePunctuation, forKey: "includePunctuation") }
    }
    var muteSystemAudio: Bool {
        didSet { UserDefaults.standard.set(muteSystemAudio, forKey: "muteSystemAudio") }
    }
    var hideIdlePill: Bool {
        didSet {
            UserDefaults.standard.set(hideIdlePill, forKey: "hideIdlePill")
            if hideIdlePill { overlayPanel?.orderOut(nil) } else { startPersistentOverlay() }
        }
    }
    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            updateDockVisibility()
        }
    }
    var customVocabulary: [String] {
        didSet { UserDefaults.standard.set(customVocabulary, forKey: "customVocabulary") }
    }
    var transcriptionProvider: TranscriptionProvider {
        didSet {
            UserDefaults.standard.set(transcriptionProvider.rawValue, forKey: "transcriptionProvider")
            if transcriptionProvider == .groq {
                transcriptionService.unloadModel()
                isModelLoaded = false
            }
        }
    }
    var groqAPIKey: String {
        didSet { KeychainService.set(groqAPIKey, for: "groqAPIKey") }
    }
    var groqModel: String {
        didSet { UserDefaults.standard.set(groqModel, forKey: "groqModel") }
    }
    var transcriptionLanguage: String {
        didSet { UserDefaults.standard.set(transcriptionLanguage, forKey: "transcriptionLanguage") }
    }
    var selectedMicUID: String {
        didSet {
            UserDefaults.standard.set(selectedMicUID, forKey: "selectedMicUID")
            microphoneManager.applySelection(uid: selectedMicUID)
        }
    }

    // MARK: - Prompts
    var whisperPrompt: String {
        didSet { UserDefaults.standard.set(whisperPrompt, forKey: "whisperPrompt") }
    }
    var llmSystemPrompt: String {
        didSet { UserDefaults.standard.set(llmSystemPrompt, forKey: "llmSystemPrompt") }
    }

    // MARK: - Groq
    var groqAPIStatus: GroqAPIStatus = .unknown
    var groqFetchedModels: [String] = []

    // MARK: - Usage (cumulative, persisted)
    var usagePromptTokens: Int {
        didSet { UserDefaults.standard.set(usagePromptTokens, forKey: "usagePromptTokens") }
    }
    var usageCompletionTokens: Int {
        didSet { UserDefaults.standard.set(usageCompletionTokens, forKey: "usageCompletionTokens") }
    }
    var usageTotalTokens: Int {
        didSet { UserDefaults.standard.set(usageTotalTokens, forKey: "usageTotalTokens") }
    }
    var usageTotalTime: Double {
        didSet { UserDefaults.standard.set(usageTotalTime, forKey: "usageTotalTime") }
    }
    var usageRequestCount: Int {
        didSet { UserDefaults.standard.set(usageRequestCount, forKey: "usageRequestCount") }
    }

    // MARK: - AI Mode Settings
    var aiModeKeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(aiModeKeyCode), forKey: "aiModeKeyCode") }
    }
    var aiModeModifiers: UInt64 {
        didSet { UserDefaults.standard.set(aiModeModifiers, forKey: "aiModeModifiers") }
    }
    var cancelHotkeyKeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(cancelHotkeyKeyCode), forKey: "cancelHotkeyKeyCode") }
    }
    var cancelHotkeyModifiers: UInt64 {
        didSet { UserDefaults.standard.set(cancelHotkeyModifiers, forKey: "cancelHotkeyModifiers") }
    }
    var pasteLastHotkeyKeyCode: UInt16 {
        didSet { UserDefaults.standard.set(Int(pasteLastHotkeyKeyCode), forKey: "pasteLastHotkeyKeyCode") }
    }
    var pasteLastHotkeyModifiers: UInt64 {
        didSet { UserDefaults.standard.set(pasteLastHotkeyModifiers, forKey: "pasteLastHotkeyModifiers") }
    }
    var aiModel: String {
        didSet { UserDefaults.standard.set(aiModel, forKey: "aiModel") }
    }

    // MARK: - Services
    let modelManager = ModelManager()
    let transcriptionService = TranscriptionService()
    let hotkeyService = HotkeyService()
    let aiHotkeyService = HotkeyService()
    let cancelHotkeyService = HotkeyService()
    let pasteLastHotkeyService = HotkeyService()
    let historyManager = HistoryManager()
    let snippetManager = SnippetManager()
    let microphoneManager = MicrophoneManager()
    var isModelLoaded = false   // tracked by @Observable — TranscriptionService is not
    var isAIMode = false
    var selectedContext: String? = nil

    var isReady: Bool {
        switch transcriptionProvider {
        case .local: return isModelLoaded
        case .groq: return !groqAPIKey.isEmpty
        }
    }

    // MARK: - Overlay
    var overlayPanel: OverlayPanel?
    var pendingNavSelection: NavItem? = nil


    // MARK: - Private
    private var isKeyHeld = false
    private var accessibilityWasGranted = false

    var shortcutDisplayString: String {
        KeyCodeMapping.displayString(
            keyCode: hotkeyKeyCode,
            modifiers: CGEventFlags(rawValue: hotkeyModifiers)
        )
    }

    var aiShortcutDisplayString: String {
        KeyCodeMapping.displayString(
            keyCode: aiModeKeyCode,
            modifiers: CGEventFlags(rawValue: aiModeModifiers)
        )
    }

    var cancelShortcutDisplayString: String {
        KeyCodeMapping.displayString(
            keyCode: cancelHotkeyKeyCode,
            modifiers: CGEventFlags(rawValue: cancelHotkeyModifiers)
        )
    }

    var pasteLastShortcutDisplayString: String {
        KeyCodeMapping.displayString(
            keyCode: pasteLastHotkeyKeyCode,
            modifiers: CGEventFlags(rawValue: pasteLastHotkeyModifiers)
        )
    }

    init() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        dictationMode = DictationMode(rawValue: UserDefaults.standard.string(forKey: "dictationMode") ?? "") ?? .pushToTalk
        hotkeyKeyCode = UInt16(UserDefaults.standard.integer(forKey: "hotkeyKeyCode"))
        hotkeyModifiers = UInt64(UserDefaults.standard.integer(forKey: "hotkeyModifiers"))
        if UserDefaults.standard.object(forKey: "includePunctuation") == nil {
            includePunctuation = true
        } else {
            includePunctuation = UserDefaults.standard.bool(forKey: "includePunctuation")
        }
        muteSystemAudio = UserDefaults.standard.bool(forKey: "muteSystemAudio")
        hideIdlePill = UserDefaults.standard.bool(forKey: "hideIdlePill")
        showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        customVocabulary = UserDefaults.standard.stringArray(forKey: "customVocabulary") ?? []
        transcriptionProvider = TranscriptionProvider(rawValue: UserDefaults.standard.string(forKey: "transcriptionProvider") ?? "") ?? .local
        if let legacyKey = UserDefaults.standard.string(forKey: "groqAPIKey") {
            KeychainService.set(legacyKey, for: "groqAPIKey")
            UserDefaults.standard.removeObject(forKey: "groqAPIKey")
        }
        groqAPIKey = KeychainService.string(for: "groqAPIKey") ?? ""
        groqModel = UserDefaults.standard.string(forKey: "groqModel") ?? "whisper-large-v3-turbo"
        transcriptionLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
        selectedMicUID = UserDefaults.standard.string(forKey: "selectedMicUID") ?? ""
        aiModeKeyCode = UInt16(UserDefaults.standard.integer(forKey: "aiModeKeyCode"))
        aiModeModifiers = UInt64(UserDefaults.standard.integer(forKey: "aiModeModifiers"))
        cancelHotkeyKeyCode = UInt16(UserDefaults.standard.integer(forKey: "cancelHotkeyKeyCode"))
        cancelHotkeyModifiers = UInt64(UserDefaults.standard.integer(forKey: "cancelHotkeyModifiers"))
        pasteLastHotkeyKeyCode = UInt16(UserDefaults.standard.integer(forKey: "pasteLastHotkeyKeyCode"))
        pasteLastHotkeyModifiers = UInt64(UserDefaults.standard.integer(forKey: "pasteLastHotkeyModifiers"))
        aiModel = UserDefaults.standard.string(forKey: "aiModel") ?? "openai/gpt-oss-20b"
        groqFetchedModels = UserDefaults.standard.stringArray(forKey: "groqFetchedModels") ?? []
        whisperPrompt = UserDefaults.standard.string(forKey: "whisperPrompt") ?? ""
        llmSystemPrompt = UserDefaults.standard.string(forKey: "llmSystemPrompt") ?? "You are a concise assistant inside a macOS voice dictation app. The user spoke their request and it was transcribed. Answer directly — no preamble, no filler, no sign-off. If the answer is a single word or number, just say it. Match the brevity of the question."
        usagePromptTokens = UserDefaults.standard.integer(forKey: "usagePromptTokens")
        usageCompletionTokens = UserDefaults.standard.integer(forKey: "usageCompletionTokens")
        usageTotalTokens = UserDefaults.standard.integer(forKey: "usageTotalTokens")
        usageTotalTime = UserDefaults.standard.double(forKey: "usageTotalTime")
        usageRequestCount = UserDefaults.standard.integer(forKey: "usageRequestCount")

        // Apply saved mic selection — didSet doesn't fire during init
        if !selectedMicUID.isEmpty {
            microphoneManager.applySelection(uid: selectedMicUID)
        }

        // Default shortcut: Fn (debug uses Right Shift to avoid conflicting with prod)
        if hotkeyKeyCode == 0 && hotkeyModifiers == 0 {
            #if DEBUG
            hotkeyKeyCode = 60 // kVK_RightShift
            hotkeyModifiers = CGEventFlags.maskShift.rawValue
            #else
            hotkeyKeyCode = 63 // kVK_Function
            hotkeyModifiers = CGEventFlags.maskSecondaryFn.rawValue
            #endif
        }

        // Default AI shortcut: Right Option (debug uses Right Control)
        if aiModeKeyCode == 0 && aiModeModifiers == 0 {
            #if DEBUG
            aiModeKeyCode = 62 // kVK_RightControl
            aiModeModifiers = CGEventFlags.maskControl.rawValue
            #else
            aiModeKeyCode = 61 // kVK_RightOption
            aiModeModifiers = CGEventFlags.maskAlternate.rawValue
            #endif
        }

        // Default dismiss shortcut: Control + Option + Esc
        if cancelHotkeyKeyCode == 0 && cancelHotkeyModifiers == 0 {
            cancelHotkeyKeyCode = 53 // kVK_Escape
            cancelHotkeyModifiers = CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
        }

        // Default paste-last shortcut: Control + Option + V
        if pasteLastHotkeyKeyCode == 0 && pasteLastHotkeyModifiers == 0 {
            pasteLastHotkeyKeyCode = 9 // kVK_ANSI_V
            pasteLastHotkeyModifiers = CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
        }

        if !isOnboardingComplete {
            showOnboarding = true
        }

        accessibilityWasGranted = PermissionService.isAccessibilityGranted()

        Task {
            await loadSelectedModel()
            if !groqAPIKey.isEmpty { await verifyAndFetchGroqModels() }
            setupHotkey()
            await MainActor.run { startPersistentOverlay() }
        }

        startAccessibilityMonitor()
    }

    private func startAccessibilityMonitor() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let granted = PermissionService.isAccessibilityGranted()
            if granted && !self.accessibilityWasGranted {
                DispatchQueue.main.async {
                    self.hotkeyService.stop()
                    self.aiHotkeyService.stop()
                    self.cancelHotkeyService.stop()
                    self.pasteLastHotkeyService.stop()
                    self.setupHotkey()
                }
            }
            self.accessibilityWasGranted = granted
        }
    }

    func setupHotkey() {
        hotkeyService.stop()
        aiHotkeyService.stop()
        cancelHotkeyService.stop()
        pasteLastHotkeyService.stop()

        let isToggleMode = dictationMode == .toggle

        // Normal dictation hotkey
        hotkeyService.targetKeyCode = CGKeyCode(hotkeyKeyCode)
        hotkeyService.targetModifiers = CGEventFlags(rawValue: hotkeyModifiers)
        hotkeyService.isToggleMode = isToggleMode

        hotkeyService.onKeyDown = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAIMode = false
                switch self.dictationMode {
                case .pushToTalk:
                    if self.status == .idle {
                        self.isKeyHeld = true
                        Task { await self.startDictation() }
                    }
                case .toggle:
                    if self.status == .idle {
                        Task { await self.startDictation() }
                    } else if self.status == .recording {
                        Task { await self.stopDictationAndPaste() }
                    }
                }
            }
        }

        hotkeyService.onKeyUp = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.dictationMode == .pushToTalk && self.isKeyHeld && self.status == .recording {
                    self.isKeyHeld = false
                    Task { await self.stopDictationAndPaste() }
                }
            }
        }

        hotkeyService.start()

        // AI mode hotkey
        aiHotkeyService.targetKeyCode = CGKeyCode(aiModeKeyCode)
        aiHotkeyService.targetModifiers = CGEventFlags(rawValue: aiModeModifiers)
        aiHotkeyService.isToggleMode = isToggleMode

        aiHotkeyService.onKeyDown = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isAIMode = true
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.selectedContext = await PasteService.getSelectedText()
                    switch self.dictationMode {
                    case .pushToTalk:
                        if self.status == .idle {
                            self.isKeyHeld = true
                            await self.startDictation()
                        }
                    case .toggle:
                        if self.status == .idle {
                            await self.startDictation()
                        } else if self.status == .recording {
                            await self.stopDictationAndPaste()
                        }
                    }
                }
            }
        }

        aiHotkeyService.onKeyUp = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.dictationMode == .pushToTalk && self.isKeyHeld && self.status == .recording {
                    self.isKeyHeld = false
                    Task { await self.stopDictationAndPaste() }
                }
            }
        }

        aiHotkeyService.start()

        // Dismiss current prompt hotkey
        cancelHotkeyService.targetKeyCode = CGKeyCode(cancelHotkeyKeyCode)
        cancelHotkeyService.targetModifiers = CGEventFlags(rawValue: cancelHotkeyModifiers)

        cancelHotkeyService.onKeyDown = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                Task { await self.dismissVoicePrompt() }
            }
        }

        cancelHotkeyService.start()

        // Paste last transcription hotkey
        pasteLastHotkeyService.targetKeyCode = CGKeyCode(pasteLastHotkeyKeyCode)
        pasteLastHotkeyService.targetModifiers = CGEventFlags(rawValue: pasteLastHotkeyModifiers)

        pasteLastHotkeyService.onKeyDown = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.pasteLastTranscription()
            }
        }

        pasteLastHotkeyService.start()

        overlayPanel?.setShortcutLabel(shortcutDisplayString)
        setupPillPressAndHold()
    }

    func setupPillPressAndHold() {
        overlayPanel?.onMouseDown = { [weak self] in
            guard let self else { return }
            self.isAIMode = false
            switch self.dictationMode {
            case .pushToTalk:
                if self.status == .idle {
                    self.isKeyHeld = true
                    Task { await self.startDictation() }
                }
            case .toggle:
                if self.status == .idle {
                    Task { await self.startDictation() }
                } else if self.status == .recording {
                    Task { await self.stopDictationAndPaste() }
                }
            }
        }
        overlayPanel?.onMouseUp = { [weak self] in
            guard let self else { return }
            if self.dictationMode == .pushToTalk && self.isKeyHeld && self.status == .recording {
                self.isKeyHeld = false
                Task { await self.stopDictationAndPaste() }
            }
        }
    }

    func updateDockVisibility() {
        let mainWindow = NSApp.windows.first { window in
            window.title == "Wave" || window.identifier?.rawValue.contains("main") == true
        }
        let windowVisible = mainWindow?.isVisible == true
        if windowVisible || showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func startDictation() async {
        guard isReady else {
            status = .error(transcriptionProvider == .groq ? "Groq API key required" : "No model loaded")
            try? await Task.sleep(for: .seconds(2))
            status = .idle
            return
        }

        // Dismiss any visible answer card before starting a new session
        overlayPanel?.hideAnswer()

        do {
            status = .recording
            showOverlay()
            overlayPanel?.setAIMode(isAIMode)
            if !selectedMicUID.isEmpty { microphoneManager.applySelection(uid: selectedMicUID) }
            if muteSystemAudio { SystemAudioDucker.duck() }
            try await transcriptionService.startRecording()
            // Poll mic level and drive overlay visualization
            Task { [weak self] in
                while let self, self.status == .recording {
                    let level = await self.transcriptionService.audioLevel()
                    self.overlayPanel?.setAudioLevel(level)
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
        } catch {
            if muteSystemAudio { SystemAudioDucker.restore() }
            status = .error("Recording failed")
            overlayPanel?.updateStatus(status)
            try? await Task.sleep(for: .seconds(2))
            status = .idle
            hideOverlayIfIdle()
            overlayPanel?.setAIMode(false)
            isAIMode = false
        }
    }

    func dismissVoicePrompt() async {
        guard status == .recording || status == .transcribing else { return }

        if status == .recording {
            await transcriptionService.stopRecordingAndDiscard()
        }
        if muteSystemAudio { SystemAudioDucker.restore() }

        status = .idle
        isKeyHeld = false
        isAIMode = false
        selectedContext = nil
        overlayPanel?.setAIMode(false)
        overlayPanel?.hideAnswer()
        hideOverlayIfIdle()
    }

    func pasteLastTranscription() {
        guard status == .idle else { return }
        guard let text = historyManager.records.first?.text else { return }
        PasteService.paste(text: text)
    }

    func stopDictationAndPaste() async {
        status = .transcribing
        updateOverlay()

        let prompt = customVocabulary.isEmpty ? nil : customVocabulary.joined(separator: " ")
        let lang = transcriptionLanguage == "auto" ? nil : transcriptionLanguage
        let transcribed: String?
        switch transcriptionProvider {
        case .local:
            transcribed = await transcriptionService.stopRecordingAndTranscribe(includePunctuation: includePunctuation, language: lang, initialPrompt: prompt)
        case .groq:
            transcribed = await transcriptionService.stopRecordingAndTranscribeWithGroq(
                apiKey: groqAPIKey,
                model: groqModel,
                includePunctuation: includePunctuation,
                language: lang,
                initialPrompt: prompt
            )
        }
        if muteSystemAudio { SystemAudioDucker.restore() }

        let text: String?
        if isAIMode, let query = transcribed, !query.isEmpty, !groqAPIKey.isEmpty {
            var fullPrompt = llmSystemPrompt
            if !snippetManager.snippets.isEmpty {
                let snippetLines = snippetManager.snippets.map { "- \($0.name): \($0.value)" }.joined(separator: "\n")
                fullPrompt += "\n\nUser snippets (use when relevant):\n\(snippetLines)"
            }
            var userMessage = query
            if let context = selectedContext {
                userMessage = "Selected text:\n\"\"\"\n\(context)\n\"\"\"\n\nInstruction: \(query)"
            }
            let result = await transcriptionService.sendToAI(text: userMessage, apiKey: groqAPIKey, model: aiModel, systemPrompt: fullPrompt)
            usagePromptTokens += result.promptTokens
            usageCompletionTokens += result.completionTokens
            usageTotalTokens += result.totalTokens
            usageTotalTime += result.totalTime
            usageRequestCount += 1
            text = result.text
        } else {
            text = transcribed
        }

        status = .idle
        overlayPanel?.setAIMode(false)
        let wasAIMode = isAIMode
        isAIMode = false
        selectedContext = nil
        hideOverlayIfIdle()

        if let text = text, !text.isEmpty {
            historyManager.add(text)

            // Route:
            // - Regular dictation → always paste
            // - AI mode: paste only if there's an editable field to paste into.
            //   Otherwise (reading webpage, PDF, etc.), show the answer card.
            //   Selected text is just context for the LLM, not a routing signal.
            let shouldShowCard = wasAIMode && !PasteService.hasEditableFocus()

            if shouldShowCard {
                overlayPanel?.showAnswer(
                    text,
                    onCopy: { [weak self] in
                        self?.copyAnswerToClipboard(text)
                    },
                    onClose: { [weak self] in
                        self?.overlayPanel?.hideAnswer()
                    }
                )
            } else {
                try? await Task.sleep(for: .milliseconds(100))
                PasteService.paste(text: text)
            }
        } else {
            print("[wave] nothing to paste")
        }

        status = .idle
    }

    private func copyAnswerToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func verifyAndFetchGroqModels() async {
        guard !groqAPIKey.isEmpty else { groqAPIStatus = .unknown; return }
        groqAPIStatus = .checking

        let url = URL(string: "https://api.groq.com/openai/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(groqAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                groqAPIStatus = .error("Invalid API key")
                return
            }
            struct GroqModelEntry: Decodable {
                let id: String
                let active: Bool
                enum CodingKeys: String, CodingKey { case id, active }
            }
            struct GroqModelList: Decodable { let data: [GroqModelEntry] }
            let list = try JSONDecoder().decode(GroqModelList.self, from: data)
            let chatModels = list.data
                .filter { $0.active && !$0.id.localizedCaseInsensitiveContains("whisper") && !$0.id.localizedCaseInsensitiveContains("distil") }
                .map { $0.id }
                .sorted()
            groqFetchedModels = chatModels
            UserDefaults.standard.set(chatModels, forKey: "groqFetchedModels")
            groqAPIStatus = .operational
        } catch {
            groqAPIStatus = .error("Connection failed")
        }
    }

    func loadSelectedModel() async {
        guard let path = modelManager.selectedModelPath else { return }
        do {
            try await transcriptionService.loadModel(path: path)
            isModelLoaded = true
        } catch {
            print("Failed to load model: \(error)")
            isModelLoaded = false
            status = .error("Failed to load model")
            try? await Task.sleep(for: .seconds(2))
            status = .idle
        }
    }

    // MARK: - Overlay

    func showOverlay() {
        if overlayPanel == nil {
            overlayPanel = OverlayPanel()
            overlayPanel?.setShortcutLabel(shortcutDisplayString)
            setupPillPressAndHold()
        }
        overlayPanel?.updateStatus(status)
    }

    func hideOverlayIfIdle() {
        if hideIdlePill {
            overlayPanel?.orderOut(nil)
        } else {
            overlayPanel?.updateStatus(.idle)
        }
    }

    func updateOverlay() {
        overlayPanel?.updateStatus(status)
    }

    func hideOverlay() {
        status = .idle
        hideOverlayIfIdle()
    }

    func startPersistentOverlay() {
        guard !hideIdlePill else { return }
        if overlayPanel == nil {
            overlayPanel = OverlayPanel()
            overlayPanel?.setShortcutLabel(shortcutDisplayString)
            setupPillPressAndHold()
        }
        overlayPanel?.updateStatus(.idle)
    }
}
