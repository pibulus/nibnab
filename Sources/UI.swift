import SwiftUI
import Cocoa

enum TagLink {
    static let scheme = "nibnab-tag"

    /// Clip text with any #tags tinted and turned into links. They ride the
    /// standard link attribute so Text handles hit-testing for us; an
    /// OpenURLAction upstream turns a click into a search.
    static func attributed(_ text: String, tint: Color) -> AttributedString {
        var attributed = AttributedString(text)
        // Map by character offset, not by searching for the tag's text — the
        // same tag can appear twice and range(of:) only ever finds the first.
        for range in NibTag.matches(in: text) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let length = text.distance(from: range.lowerBound, to: range.upperBound)
            let characters = attributed.characters
            guard start >= 0, length > 0,
                  start + length <= characters.count else { continue }
            let from = characters.index(characters.startIndex, offsetBy: start)
            let to = characters.index(from, offsetBy: length)

            attributed[from..<to].foregroundColor = tint
            attributed[from..<to].font = .system(size: 12, weight: .bold)
            let tag = String(text[range]).dropFirst().lowercased()
            if let url = URL(string: "\(scheme)://\(tag)") {
                attributed[from..<to].link = url
            }
        }
        return attributed
    }
}

extension Color {
    /// Warm near-black, fully opaque. Modal cards used to be 90% black, so the
    /// clip list showed through them and read as a rendering fault. Anything
    /// stacked over the list gets this.
    static let nibSurface = Color(red: 0.086, green: 0.075, blue: 0.071)
}

private enum DateFormatters {
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    static let full: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return f
    }()
}

// Every tappable thing in the popover squishes the same way.
struct NibPressStyle: ButtonStyle {
    var scale: CGFloat = 0.88

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// The stock .switch reads as a system checkbox dropped into a neon app and
// gives nothing back on press. This one is a chunky pill that lights up in the
// active colour, squishes, and stretches its knob as it travels.
struct NibToggleStyle: ToggleStyle {
    let tint: Color

    @State private var isPressed = false
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn

        return ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on
                    ? LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.65)],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.10)],
                                     startPoint: .leading, endPoint: .trailing))
                .overlay(
                    Capsule().stroke(on ? tint.opacity(0.9) : Color.white.opacity(0.22),
                                     lineWidth: 1.5)
                )
                .shadow(color: tint.opacity(on ? (isHovered ? 0.55 : 0.35) : 0), radius: 7, y: 1)

            Capsule()
                .fill(Color.white)
                .frame(width: isPressed ? 26 : 19, height: 19)
                .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                .padding(.horizontal, 3.5)
        }
        .frame(width: 46, height: 26)
        .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.06 : 1.0))
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
                        isPressed = false
                        configuration.isOn.toggle()
                    }
                }
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { isHovered = hovering }
        }
    }
}

struct HeaderIconButton: View {
    let systemName: String
    let action: () -> Void
    var help: String? = nil
    var isDisabled: Bool = false

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(isDisabled ? 0.35 : (isHovered ? 1.0 : 0.75)))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(isHovered ? 0.24 : 0.1))
                )
        }
        .buttonStyle(NibPressStyle())
        .disabled(isDisabled)
        .help(help ?? "")
        .accessibilityLabel(help ?? systemName)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                isHovered = hovering && !isDisabled
            }
        }
    }
}

// Same 26x26 pill as HeaderIconButton — the chrome lives outside the label
// because a borderlessButton Menu doesn't reliably paint a label background.
struct HeaderMenuButton<Content: View>: View {
    let systemName: String
    let help: String
    var isDisabled: Bool = false
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Menu(content: content) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(isDisabled ? 0.35 : (isHovered ? 1.0 : 0.75)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(isHovered ? 0.24 : 0.1))
        )
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                isHovered = hovering && !isDisabled
            }
        }
    }
}

struct ContentHeaderView: View {
    @EnvironmentObject var appState: AppState
    @Binding var sortOrder: ContentView.SortOrder
    @Binding var searchText: String
    @Binding var showAddClipModal: Bool
    @Binding var showClearConfirm: Bool
    @Binding var showHelp: Bool
    @Binding var showApiKeyModal: Bool
    @Binding var showWelcomeModal: Bool
    @Binding var editingLabel: Bool
    @Binding var labelText: String
    @Binding var labelHovered: Bool
    var labelFocused: FocusState<Bool>.Binding
    let clipCount: Int
    /// The clips currently on screen. While searching these span colours, and
    /// every collection action follows them instead of the active colour.
    let visibleClips: [Clip]
    let searchLabel: String?
    let horizontalPadding: CGFloat

    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            primaryControls
            searchControls
                .frame(maxWidth: .infinity)
            actionControls
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onChange(of: appState.activeColor.name) { _ in
            if editingLabel {
                editingLabel = false
                labelFocused.wrappedValue = false
            }
        }
    }

    private var primaryControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "highlighter")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(appState.activeColor.nsColor))

            if editingLabel {
                HStack(spacing: 4) {
                    TextField("", text: $labelText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(Color(appState.activeColor.nsColor))
                        .frame(maxWidth: 110)
                        .focused(labelFocused)
                        .onSubmit {
                            appState.setLabel(labelText, forColor: appState.activeColor.name)
                            editingLabel = false
                            labelFocused.wrappedValue = false
                        }
                        .onExitCommand {
                            editingLabel = false
                            labelFocused.wrappedValue = false
                        }

                    Text("\(labelText.count)/12")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color.white.opacity(labelText.count > 12 ? 0.8 : 0.4))
                }
            } else {
                Button(action: {
                    labelText = appState.labelForColor(appState.activeColor.name)
                    editingLabel = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        labelFocused.wrappedValue = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(appState.labelForColor(appState.activeColor.name))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(Color(appState.activeColor.nsColor))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 120, alignment: .leading)

                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundColor(Color(appState.activeColor.nsColor).opacity(labelHovered ? 0.9 : 0.4))
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        labelHovered = hovering
                    }
                }
                .help("Click to rename collection")
            }

            Toggle(
                "",
                isOn: Binding(
                    get: { appState.isMonitoring },
                    set: { newValue in
                        appState.setMonitoring(newValue, suppressToast: false)
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(NibToggleStyle(tint: Color(appState.activeColor.nsColor)))
            .help(appState.isMonitoring ? "Capturing ON (⌃⌘M) — click to pause" : "Capturing OFF (⌃⌘M) — click to resume")
            .accessibilityLabel("Auto-capture")
            .accessibilityValue(appState.isMonitoring ? "on" : "off")
        }
    }

    private var searchControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(minWidth: 40)
                    .accessibilityLabel("Search clips")
                    .focused($searchFieldFocused)
                    .onAppear {
                        searchFieldFocused = false
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.12))
            )

            HeaderMenuButton(systemName: "line.3.horizontal.decrease", help: "Sort clips") {
                Button(action: { sortOrder = .newestFirst }) {
                    Label("Newest First", systemImage: sortOrder == .newestFirst ? "checkmark" : "")
                }
                Button(action: { sortOrder = .oldestFirst }) {
                    Label("Oldest First", systemImage: sortOrder == .oldestFirst ? "checkmark" : "")
                }
                Divider()
                Button(action: { sortOrder = .manual }) {
                    Label("Manual (drag to reorder)", systemImage: sortOrder == .manual ? "checkmark" : "")
                }
                Divider()
                Button(action: { sortOrder = .byAppName }) {
                    Label("By App Name", systemImage: sortOrder == .byAppName ? "checkmark" : "")
                }
                Button(action: { sortOrder = .byLength }) {
                    Label("By Length", systemImage: sortOrder == .byLength ? "checkmark" : "")
                }
            }
        }
    }

    private var actionControls: some View {
        HStack(alignment: .center, spacing: 6) {
            HeaderIconButton(systemName: "plus", action: {
                showAddClipModal = true
            }, help: "Add clip (manual entry)")

            HeaderMenuButton(
                systemName: "ellipsis",
                help: searchLabel.map { "Actions for \($0)" } ?? "More options & actions",
                isDisabled: false
            ) {
                let scope = searchLabel ?? appState.labelForColor(appState.activeColor.name)
                let stem = (searchLabel ?? appState.activeColor.name)
                    .replacingOccurrences(of: "Highlighter ", with: "")
                    .replacingOccurrences(of: "#", with: "tag-")
                    .lowercased()

                if !visibleClips.isEmpty {
                    Section(searchLabel.map { "\(visibleClips.count) matching \($0)" } ?? scope) {
                        Button("Export as Markdown") {
                            appState.exportAsMarkdown(visibleClips, title: scope, stem: stem)
                        }
                        Button("Export as Plain Text") {
                            appState.exportAsPlainText(visibleClips, stem: stem)
                        }
                    }

                    Divider()

                    Button(searchLabel == nil ? "Merge All Into One Clip"
                                              : "Merge \(visibleClips.count) Results Into One Clip") {
                        appState.mergeClips(visibleClips, into: appState.activeColor.name)
                    }
                    .disabled(visibleClips.count < 2)

                    Divider()

                    Button("Export & Clear \(appState.labelForColor(appState.activeColor.name))\u{2026}") {
                        appState.exportAndClear(for: appState.activeColor.name)
                    }
                    Button("Clear \(appState.labelForColor(appState.activeColor.name))\u{2026}", role: .destructive) {
                        showClearConfirm = true
                    }

                    Divider()
                }

                Section("NibNab") {
                    Button {
                        showApiKeyModal = true
                    } label: {
                        Label(appState.hasAiSuperpowers ? "AI Superpowers (Active ✨)" : "Configure AI Superpowers...", systemImage: "sparkles")
                    }

                    Button {
                        showHelp = true
                    } label: {
                        Label("Help & Shortcuts...", systemImage: "questionmark.circle")
                    }

                    Button {
                        showWelcomeModal = true
                    } label: {
                        Label("Welcome Guide...", systemImage: "hand.wave")
                    }

                    Button {
                        appState.delegate?.showAbout()
                    } label: {
                        Label("About NibNab...", systemImage: "info.circle")
                    }
                }
            }
        }
    }
}

// MARK: - ZipList-style Tag Rack Shelf
struct TagRackShelfView: View {
    @EnvironmentObject var appState: AppState
    @Binding var searchText: String
    let horizontalPadding: CGFloat

    var body: some View {
        let tags = appState.allTagsWithCounts
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    TagPill(
                        title: "All",
                        count: nil,
                        isSelected: searchText.isEmpty,
                        tint: Color(appState.activeColor.nsColor),
                        action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                searchText = ""
                            }
                        }
                    )

                    ForEach(tags, id: \.tag) { item in
                        let isSelected = searchText.lowercased() == item.tag.lowercased()
                        TagPill(
                            title: item.tag,
                            count: item.count,
                            isSelected: isSelected,
                            tint: Color(appState.activeColor.nsColor),
                            action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    if isSelected {
                                        searchText = ""
                                    } else {
                                        searchText = item.tag
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 6)
            }
            .background(Color.black.opacity(0.45))
        }
    }
}

struct TagPill: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Color.black : (isHovered ? tint : Color.white.opacity(0.85)))

                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? Color.black.opacity(0.7) : (isHovered ? tint.opacity(0.9) : Color.white.opacity(0.45)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSelected ? tint : Color.white.opacity(isHovered ? 0.16 : 0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint : (isHovered ? tint.opacity(0.5) : Color.white.opacity(0.15)), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .shadow(color: isSelected ? tint.opacity(0.4) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

struct ContentFooterView: View {
    @EnvironmentObject var appState: AppState
    let horizontalPadding: CGFloat
    let viewedClipCount: Int
    let resultCount: Int?
    let handleColorDrop: ([Clip], NibColor) -> Void

    var body: some View {
        ZStack {
            HStack {
                if appState.canUndo {
                    Button(action: { appState.undoLast() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9, weight: .bold))
                            Text("Undo (⌘Z)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Undo last delete or merge (⌘Z)")
                } else {
                    Text("NibNab")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(appState.activeColor.nsColor).opacity(0.85))
                        .tracking(0.5)
                }
                Spacer()
                clipCounter
            }

            HStack(spacing: 8) {
                ForEach(NibColor.all, id: \.name) { color in
                    ColorDropTarget(
                        color: color,
                        isActive: appState.activeColor.name == color.name,
                        onTap: {
                            appState.switchToColor(color, announce: true)
                        },
                        onDrop: { clips in
                            handleColorDrop(clips, color)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // WIN 3: a full collection silently evicted its oldest clip on the next
    // capture. In an app about keeping things, say so.
    private var isFull: Bool { viewedClipCount >= AppState.maxClipsPerColor }

    @ViewBuilder
    private var clipCounter: some View {
        if let resultCount {
            Text("\(resultCount) found")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color(appState.activeColor.nsColor).opacity(0.85))
                .help("Searching every collection")
        } else if isFull {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("\(viewedClipCount) / \(AppState.maxClipsPerColor) full")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(NibColor.orange.nsColor))
            .help("This collection is full — the next capture drops the oldest clip. Export, merge, or clear to keep them.")
        } else {
            Text("\(viewedClipCount) clips")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color(appState.activeColor.nsColor).opacity(0.85))
        }
    }
}

struct ContentOverlaysView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedClip: Clip?
    @Binding var showAddClipModal: Bool
    @Binding var editingClip: Clip?
    @Binding var showHelp: Bool
    @Binding var showApiKeyModal: Bool
    @Binding var showWelcomeModal: Bool
    // The color the open modal belongs to, captured when it was opened —
    // a ⌃⌘1-5 hotkey can change the active colour while a modal is up, and
    // saving/deleting against the new color would hit the wrong file.
    let modalColorName: String

    var body: some View {
        Group {
            if let clip = selectedClip {
                overlayBackground {
                    ClipDetailView(clip: clip, colorName: modalColorName) {
                        appState.play(.close)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedClip = nil
                        }
                    }
                    .environmentObject(appState)
                }
            }

            if showAddClipModal {
                overlayBackground {
                    AddClipModal(
                        onDismiss: {
                            appState.play(.close)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                showAddClipModal = false
                            }
                        },
                        onSave: { text in
                            appState.saveClip(text, to: appState.activeColor, from: "Manual Entry")
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                showAddClipModal = false
                            }
                        }
                    )
                    .environmentObject(appState)
                }
            }

            if let clip = editingClip {
                overlayBackground {
                    EditClipModal(
                        clip: clip,
                        onDismiss: {
                            appState.play(.close)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                editingClip = nil
                            }
                        },
                        onSave: { newText in
                            appState.updateClip(clip, newText: newText, in: modalColorName)
                            appState.play(.capture)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                editingClip = nil
                            }
                        }
                    )
                    .environmentObject(appState)
                }
            }

            if showHelp {
                overlayBackground {
                    HelpModal {
                        appState.play(.close)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            showHelp = false
                        }
                    }
                    .environmentObject(appState)
                }
            }

            if showApiKeyModal {
                overlayBackground {
                    ApiKeyModal {
                        appState.play(.close)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            showApiKeyModal = false
                        }
                    }
                    .environmentObject(appState)
                }
            }

            if showWelcomeModal {
                overlayBackground {
                    WelcomeModal(onDismiss: {
                        appState.play(.close)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            showWelcomeModal = false
                        }
                        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        appState.delegate?.pulseMenuBarIcon()
                    })
                    .environmentObject(appState)
                }
            }
        }
    }

    private func overlayBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.play(.close)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        showAddClipModal = false
                        editingClip = nil
                        selectedClip = nil
                        showHelp = false
                        showApiKeyModal = false
                        if showWelcomeModal {
                            showWelcomeModal = false
                            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                            appState.delegate?.pulseMenuBarIcon()
                        }
                    }
                }
                .transition(.opacity)

            content()
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    private static let popoverSize = CGSize(width: 520, height: 480)
    private static let horizontalPadding: CGFloat = 28
    @EnvironmentObject var appState: AppState
    @State private var selectedClip: Clip?
    @State private var sortOrder: SortOrder = .newestFirst
    @State private var searchText = ""
    @State private var showClearConfirm = false
    @State private var editingLabel = false
    @State private var labelText = ""
    @State private var labelHovered = false
    @State private var showAddClipModal = false
    @State private var showHelp = false
    @State private var showApiKeyModal = false
    @State private var showWelcomeModal = false
    @State private var editingClip: Clip?
    @State private var modalColorName = ""
    @State private var dropTargetedClipID: UUID? = nil
    @State private var focusedClipID: UUID? = nil
    @State private var keyMonitor: Any? = nil
    @FocusState private var labelFocused: Bool

    enum SortOrder {
        case newestFirst, oldestFirst, byAppName, byLength, manual
    }

    /// A clip plus the collection it actually lives in. Search spans every
    /// colour, so a row can no longer assume it belongs to the viewed one.
    struct ClipRow: Identifiable {
        let clip: Clip
        let color: NibColor
        var id: UUID { clip.id }
    }

    /// Searching looks everywhere. Capture is easy; the hard part was ever
    /// finding the thing again, and "which colour was it?" is not a question
    /// the user should have to answer.
    var isSearching: Bool { !searchText.isEmpty }

    var rows: [ClipRow] {
        let source: [ClipRow]
        if isSearching {
            source = NibColor.all.flatMap { color in
                (appState.clips[color.name] ?? []).map { ClipRow(clip: $0, color: color) }
            }.filter {
                $0.clip.text.localizedCaseInsensitiveContains(searchText) ||
                $0.clip.appName.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            let color = appState.activeColor
            source = (appState.clips[color.name] ?? []).map { ClipRow(clip: $0, color: color) }
        }

        switch sortOrder {
        case .newestFirst:
            return source.sorted { $0.clip.timestamp > $1.clip.timestamp }
        case .oldestFirst:
            return source.sorted { $0.clip.timestamp < $1.clip.timestamp }
        case .byAppName:
            return source.sorted { $0.clip.appName < $1.clip.appName }
        case .byLength:
            return source.sorted { $0.clip.text.count > $1.clip.text.count }
        case .manual:
            return source.sorted { $0.clip.order < $1.clip.order }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ContentHeaderView(
                    sortOrder: $sortOrder,
                    searchText: $searchText,
                    showAddClipModal: $showAddClipModal,
                    showClearConfirm: $showClearConfirm,
                    showHelp: $showHelp,
                    showApiKeyModal: $showApiKeyModal,
                    showWelcomeModal: $showWelcomeModal,
                    editingLabel: $editingLabel,
                    labelText: $labelText,
                    labelHovered: $labelHovered,
                    labelFocused: $labelFocused,
                    clipCount: appState.clips[appState.activeColor.name]?.count ?? 0,
                    visibleClips: rows.map(\.clip),
                    searchLabel: isSearching ? "\u{201C}\(searchText)\u{201D}" : nil,
                    horizontalPadding: Self.horizontalPadding - 10
                )
                .environmentObject(appState)

                TagRackShelfView(
                    searchText: $searchText,
                    horizontalPadding: Self.horizontalPadding - 10
                )
                .environmentObject(appState)

                Divider()
                contentArea
                ContentFooterView(
                    horizontalPadding: Self.horizontalPadding - 10,
                    viewedClipCount: appState.clips[appState.activeColor.name]?.count ?? 0,
                    resultCount: isSearching ? rows.count : nil,
                    handleColorDrop: { clips, color in
                        handleColorDrop(clips: clips, targetColor: color)
                    }
                )
                .environmentObject(appState)
            }
            ContentOverlaysView(
                selectedClip: $selectedClip,
                showAddClipModal: $showAddClipModal,
                editingClip: $editingClip,
                showHelp: $showHelp,
                showApiKeyModal: $showApiKeyModal,
                showWelcomeModal: $showWelcomeModal,
                modalColorName: modalColorName
            )
            .environmentObject(appState)
            toastOverlay
        }
        .frame(width: Self.popoverSize.width, height: Self.popoverSize.height)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == TagLink.scheme else { return .systemAction }
            searchText = "#" + (url.host() ?? url.lastPathComponent)
            selectedClip = nil
            editingClip = nil
            appState.play(.copy)
            return .handled
        })
        .onAppear {
            startKeyMonitor()
            let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            if !hasLaunched {
                showWelcomeModal = true
            }
        }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: appState.showWelcomeModal) { val in
            if val {
                showWelcomeModal = true
                appState.showWelcomeModal = false
            }
        }
        .onChange(of: appState.activeColor.name) { _ in focusedClipID = nil }
        .onChange(of: appState.popoverClosedCount) { _ in
            selectedClip = nil
            editingClip = nil
            showAddClipModal = false
            showHelp = false
            showApiKeyModal = false
            showWelcomeModal = false
            editingLabel = false
            focusedClipID = nil
        }
        .onChange(of: searchText) { _ in focusedClipID = nil }
        .background(
            ZStack {
                Color.black.opacity(0.85)
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.063, blue: 0.941).opacity(0.05),
                        Color(red: 0, green: 0.831, blue: 1.0).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .alert("Clear All Clips?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                appState.clearAllClips(for: appState.activeColor.name)
            }
        } message: {
            let shortName = appState.activeColor.name.replacingOccurrences(of: "Highlighter ", with: "")
            let count = appState.clips[appState.activeColor.name]?.count ?? 0
            Text("This will permanently delete all \(count) \(shortName) clips.")
        }
    }

    private var contentArea: some View {
        ScrollViewReader { proxy in
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                if !rows.isEmpty {
                    ForEach(rows) { row in
                        let clip = row.clip
                        ClipView(
                            clip: clip,
                            color: row.color,
                            showColorPip: isSearching,
                            isDropTargeted: dropTargetedClipID == clip.id,
                            isKeyFocused: focusedClipID == clip.id
                        )
                            .id(clip.id)
                            // Reordering and merging are meaningless against a
                            // filtered, cross-colour list — the indices don't
                            // line up with what's on disk.
                            .dropDestination(for: Clip.self) { droppedClips, location in
                                guard !isSearching else { return false }
                                guard let dropped = droppedClips.first,
                                      dropped.id != clip.id else { return false }
                                let colorName = row.color.name
                                let targetIndex = rows.firstIndex(where: { $0.id == clip.id }) ?? 0
                                let isMergeZone = location.y > 18 && location.y < 42
                                let insertIndex = location.y > 42 ? targetIndex + 1 : targetIndex

                                if let sourceColor = appState.clips.first(where: { $0.value.contains(dropped) })?.key {
                                    if sourceColor == colorName {
                                        if isMergeZone {
                                            appState.mergeClip(dropped, into: clip, in: colorName)
                                        } else {
                                            appState.reorderClip(dropped, in: colorName, to: insertIndex)
                                        }
                                    } else {
                                        appState.moveClip(dropped, from: sourceColor, to: colorName)
                                        if isMergeZone {
                                            appState.mergeClip(dropped, into: clip, in: colorName)
                                        } else {
                                            appState.reorderClip(dropped, in: colorName, to: insertIndex)
                                        }
                                    }
                                }
                                dropTargetedClipID = nil
                                return true
                            } isTargeted: { targeted in
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                    dropTargetedClipID = (targeted && !isSearching) ? clip.id : nil
                                }
                            }
                            .onTapGesture {
                                modalColorName = row.color.name
                                selectedClip = clip
                            }
                            .contextMenu {
                                Button(action: {
                                    appState.copyToPasteboard(clip.text)
                                }) {
                                    Label("Copy", systemImage: "doc.on.clipboard")
                                }

                                Button(action: {
                                    modalColorName = row.color.name
                                    editingClip = clip
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }

                                // Dragging onto a footer dot is the fast path, but
                                // it's a 20px target and invisible to the keyboard.
                                Menu {
                                    ForEach(NibColor.all.filter { $0.name != row.color.name }, id: \.name) { target in
                                        Button(appState.labelForColor(target.name)) {
                                            appState.moveClip(clip, from: row.color.name, to: target.name)
                                        }
                                    }
                                } label: {
                                    Label("Move to", systemImage: "arrow.left.arrow.right")
                                }

                                Button(action: {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.deleteClip(clip, from: row.color.name)
                                    }
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }

                                if appState.hasAiSuperpowers {
                                    Divider()
                                    Menu {
                                        Button(action: {
                                            appState.aiAutoTagClip(clip, in: row.color.name)
                                        }) {
                                            Label("Auto-Tag", systemImage: "tag")
                                        }

                                        Button(action: {
                                            appState.aiCleanClipText(clip, in: row.color.name)
                                        }) {
                                            Label("Clean to Markdown", systemImage: "sparkles")
                                        }

                                        Button(action: {
                                            appState.aiSummarizeClip(clip, in: row.color.name)
                                        }) {
                                            Label("Summarize to Bullets", systemImage: "list.bullet")
                                        }
                                    } label: {
                                        Label("AI Superpowers", systemImage: "sparkles")
                                    }
                                }
                            }
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: focusedClipID) { id in
            guard let id else { return }
            withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) }
        }
        }
    }

    // MARK: - Keyboard Navigation
    // A local NSEvent monitor rather than .onKeyPress — that needs macOS 14 and
    // this app ships to 13.0.
    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleListKey(event)
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        focusedClipID = nil
    }

    private func handleListKey(_ event: NSEvent) -> NSEvent? {
        // Never steal keys from a text field, a modal, or a shortcut chord.
        guard appState.delegate?.popover.isShown == true else { return event }
        guard selectedClip == nil, editingClip == nil,
              !showAddClipModal, !showHelp, !showApiKeyModal, !editingLabel else { return event }
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }

        // Escape dismisses search or closes popover when no modal is active
        if event.keyCode == 53 /* Escape */ {
            if !searchText.isEmpty {
                searchText = ""
                return nil
            }
            appState.delegate?.closePopover()
            return nil
        }

        // ⌘Z is the one chord the list claims.
        if event.modifierFlags.contains(.command),
           !event.modifierFlags.contains(.shift),
           event.keyCode == 6 /* Z */ {
            guard appState.canUndo else { return event }
            appState.undoLast()
            return nil
        }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }

        let visible = rows
        guard !visible.isEmpty else { return event }
        let index = focusedClipID.flatMap { id in visible.firstIndex(where: { $0.id == id }) }

        switch event.keyCode {
        case 126: // up
            focusedClipID = visible[index.map { max(0, $0 - 1) } ?? visible.count - 1].id
        case 125: // down
            focusedClipID = visible[index.map { min(visible.count - 1, $0 + 1) } ?? 0].id
        case 36: // return — copy and dismiss
            guard let i = index else { return event }
            appState.copyToPasteboard(visible[i].clip.text)
            appState.delegate?.closePopover()
        case 49: // space — detail
            guard let i = index else { return event }
            modalColorName = visible[i].color.name
            selectedClip = visible[i].clip
        case 51: // delete
            guard let i = index else { return event }
            let survivor = visible.count > 1 ? visible[i == visible.count - 1 ? i - 1 : i + 1].id : nil
            appState.deleteClip(visible[i].clip, from: visible[i].color.name)
            focusedClipID = survivor
        default:
            return event
        }
        return nil
    }

    private var shortColorName: String {
        appState.activeColor.name.replacingOccurrences(of: "Highlighter ", with: "")
    }

    private var isSearchingWithNoMatches: Bool { isSearching }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: isSearchingWithNoMatches ? "magnifyingglass"
                : !appState.isMonitoring ? "pause.circle"
                : "doc.on.clipboard")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(Color.white.opacity(0.3))

            VStack(spacing: 8) {
                Text(isSearchingWithNoMatches ? "No matches"
                    : !appState.isMonitoring ? "Capture is paused"
                    : "\(shortColorName) is empty")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.8))
                Text(isSearchingWithNoMatches ? "Nothing in any collection matches \"\(searchText)\""
                    : !appState.isMonitoring ? "Flip the switch up top, then copy anything — it lands here."
                    : "Copy anything (⌘C) and it lands in \(shortColorName) — good for \(appState.activeColor.suggestion). Rename it by clicking the name below.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = appState.toastMessage, let color = appState.toastColor {
            VStack {
                Spacer()
                ToastView(
                    message: message,
                    color: color,
                    onUndo: (appState.toastUndoable && appState.canUndo)
                        ? { appState.undoLast() }
                        : nil
                )
                    .padding(.bottom, 72) // clear the footer color dots
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appState.toastMessage)
        }
    }

    private func handleColorDrop(clips: [Clip], targetColor: NibColor) {
        guard let droppedClip = clips.first else { return }
        guard let (sourceColor, _) = appState.clips.first(where: { $0.value.contains(droppedClip) }) else { return }
        appState.moveClip(droppedClip, from: sourceColor, to: targetColor.name)
        appState.switchToColor(targetColor, announce: true)
    }
}

// MARK: - Color Drop Target (Footer Color Circles)
struct ColorDropTarget: View {
    let color: NibColor
    let isActive: Bool
    let onTap: () -> Void
    let onDrop: ([Clip]) -> Void

    @State private var isTargeted = false
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    isPressed = false
                }
            }
            onTap()
        }) {
            ZStack {
                Circle()
                    .fill(Color(color.nsColor))
                    .frame(width: 28, height: 28)
                    .blur(radius: 8)
                    .opacity(isHovered || isActive ? 0.4 : 0)

                Circle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(Color(color.nsColor))
                    .frame(width: 20, height: 20)
                    .shadow(color: Color(color.nsColor).opacity(isHovered || isActive ? 0.7 : 0.35), radius: 6, y: 2)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isActive ? 3 : 0)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: isTargeted ? 2 : 0)
                            .scaleEffect(isTargeted ? 1.3 : 1.0)
                    )
            }
            .scaleEffect(isPressed ? 0.85 : (isTargeted ? 1.15 : (isHovered ? 1.18 : 1.0)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.name.replacingOccurrences(of: "Highlighter ", with: "") + (isActive ? ", active" : ""))
        .accessibilityHint("Double-tap to switch. Drop clips to move them here.")
        .help("Switch to \(color.name)\nDrag clips here to change color")
        .dropDestination(for: Clip.self) { clips, _ in
            onDrop(clips)
            return true
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isTargeted = targeted
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Clip View Component
struct ClipView: View {
    let clip: Clip
    /// The collection this clip actually lives in — during a cross-colour
    /// search that is not necessarily the one being viewed.
    let color: NibColor
    var showColorPip: Bool = false
    let isDropTargeted: Bool
    var isKeyFocused: Bool = false
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    @State private var copyHovered = false
    @State private var deleteHovered = false

    private var thumbnailImage: NSImage? {
        guard let path = clip.imagePath else { return nil }
        let url = appState.storageManager.imageURL(for: path, in: color.name)
        return ThumbnailLoader.thumbnail(for: url)
    }

    private var formattedUrlHost: (url: URL, host: String)? {
        guard let urlString = clip.url, let url = URL(string: urlString) else { return nil }
        let cleanHost = url.host?.replacingOccurrences(of: "www.", with: "") ?? "link"
        return (url, cleanHost)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            if showColorPip {
                Circle()
                    .fill(Color(color.nsColor))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color(color.nsColor).opacity(0.7), radius: 3)
                    .help(appState.labelForColor(color.name))
                    .accessibilityLabel("in \(appState.labelForColor(color.name))")
            }

            Text(clip.appName)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.659, green: 0.855, blue: 0.863))

            if let (url, host) = formattedUrlHost {
                Link(destination: url) {
                    HStack(spacing: 3) {
                        Image(systemName: "globe")
                            .font(.system(size: 8))
                        Text(host)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(4)
                    .foregroundColor(Color(color.nsColor))
                }
                .buttonStyle(.plain)
                .help(url.absoluteString)
            }

            Spacer()

            Text(timeAgo(from: clip.timestamp))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
                .padding(.trailing, isHovered ? 56 : 0)
        }
    }

    private var contentRow: some View {
        HStack(alignment: .top, spacing: 8) {
            if !clip.imagePaths.isEmpty {
                ZStack(alignment: .bottomTrailing) {
                    if let thumb = thumbnailImage {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(color.nsColor).opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: Color(color.nsColor).opacity(0.3), radius: 3)
                    }
                    if clip.imagePaths.count > 1 {
                        Text("\(clip.imagePaths.count)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(color.nsColor))
                            .clipShape(Capsule())
                            .offset(x: 2, y: 2)
                    }
                }
            }

            Text(TagLink.attributed(
                String(clip.text.prefix(150)) + (clip.text.count > 150 ? "..." : ""),
                tint: Color(color.nsColor)
            ))
            .font(.system(size: 12))
            .lineLimit(3)
            .foregroundColor(Color.white.opacity(0.9))
            .tint(Color(color.nsColor))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: isDropTargeted ?
                        [Color(color.nsColor).opacity(0.25), Color(color.nsColor).opacity(0.15)] :
                        isHovered ?
                        [Color.white.opacity(0.18), Color.white.opacity(0.12)] :
                        [Color.white.opacity(0.10), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var mergeOverlay: some View {
        Group {
            if isDropTargeted {
                VStack(spacing: 0) {
                    insertHint
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 10, weight: .bold))
                        Text("merge")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(Color.black.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background(Color(color.nsColor).opacity(0.85))
                    insertHint
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var hoverActions: some View {
        Group {
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: {
                        appState.copyToPasteboard(clip.text)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(copyHovered ? 0.2 : 0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Copy clip")
                    .accessibilityLabel("Copy clip")
                    .scaleEffect(copyHovered ? 1.15 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            copyHovered = hovering
                        }
                    }

                    Button(action: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            appState.deleteClip(clip, from: color.name)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(deleteHovered ? 0.2 : 0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Delete clip")
                    .accessibilityLabel("Delete clip")
                    .scaleEffect(deleteHovered ? 1.15 : 1.0)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            deleteHovered = hovering
                        }
                    }
                }
                .padding(6)
            }
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: { appState.copyToPasteboard(clip.text) }) {
            Label("Copy Text", systemImage: "doc.on.doc")
        }
        if let img = thumbnailImage {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([img])
                appState.play(.copy)
            }) {
                Label("Copy Image", systemImage: "photo")
            }
        }
        Divider()
        if let clipsList = appState.clips[color.name],
           let idx = clipsList.firstIndex(where: { $0.id == clip.id }) {
            if idx > 0 {
                let prev = clipsList[idx - 1]
                Button(action: {
                    appState.mergeClip(clip, into: prev, in: color.name)
                }) {
                    Label("Merge with Previous Clip", systemImage: "arrow.up.and.line.horizontal.and.arrow.down")
                }
            }
            if idx < clipsList.count - 1 {
                let next = clipsList[idx + 1]
                Button(action: {
                    appState.mergeClip(next, into: clip, in: color.name)
                }) {
                    Label("Merge with Next Clip", systemImage: "arrow.down.and.line.horizontal.and.arrow.up")
                }
            }
        }
        Divider()
        Menu("Move to Color") {
            ForEach(NibColor.all.filter { $0.name != color.name }) { targetColor in
                Button(action: {
                    appState.moveClip(clip, from: color.name, to: targetColor.name)
                }) {
                    Label(appState.labelForColor(targetColor.name), systemImage: "circle.fill")
                }
            }
        }
        Divider()
        Button(role: .destructive, action: {
            appState.deleteClip(clip, from: color.name)
        }) {
            Label("Delete Clip", systemImage: "trash")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow
            contentRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(color.nsColor).opacity(isDropTargeted || isKeyFocused ? 0.9 : (isHovered ? 0.55 : 0.2)), lineWidth: isDropTargeted || isKeyFocused ? 2 : 1.5)
        )
        .shadow(color: Color(color.nsColor).opacity(isKeyFocused ? 0.5 : 0), radius: 8)
        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
        // The merge zone used to be an invisible 24px band. Dropping there
        // destroys two clips to make one, so while a drag is over this card
        // the band names itself and the edges show where an insert would go.
        .overlay(mergeOverlay)
        .overlay(hoverActions, alignment: .topTrailing)
        .draggable(clip) {
            // Drag preview
            Text(clip.text.prefix(50))
                .font(.system(size: 12))
                .padding(8)
                .background(Color(color.nsColor).opacity(0.3))
                .cornerRadius(8)
        }
        .contextMenu {
            contextMenuContent
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                isHovered = hovering
            }
        }
    }

    private var insertHint: some View {
        VStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(color.nsColor))
                .frame(height: 3)
                .shadow(color: Color(color.nsColor).opacity(0.8), radius: 4)
            Spacer(minLength: 0)
        }
    }

    func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval/60))m ago" }
        if interval < 86400 { return "\(Int(interval/3600))h ago" }
        return "\(Int(interval/86400))d ago"
    }
}

// MARK: - Edit Clip Modal
struct EditClipModal: View {
    let clip: Clip
    let onDismiss: () -> Void
    let onSave: (String) -> Void
    @EnvironmentObject var appState: AppState
    @State private var clipText: String
    @State private var saveHovered = false
    @State private var cancelHovered = false
    @FocusState private var textFocused: Bool

    init(clip: Clip, onDismiss: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        self.clip = clip
        self.onDismiss = onDismiss
        self.onSave = onSave
        _clipText = State(initialValue: clip.text)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Clip")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(clip.appName) \(formatDate(clip.timestamp))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }

            // Content
            TextEditor(text: $clipText)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.9))
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.7))
                .focused($textFocused)

            // Tag suggestions
            if !appState.allTagsWithCounts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appState.allTagsWithCounts.prefix(10), id: \.tag) { item in
                            Button(action: {
                                if !clipText.contains(item.tag) {
                                    clipText = (clipText.isEmpty ? "" : clipText + " ") + item.tag
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text(item.tag)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                    Text("\(item.count)")
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .opacity(0.6)
                                }
                                .foregroundColor(Color(appState.activeColor.nsColor))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(appState.activeColor.nsColor).opacity(0.14))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .background(Color.black.opacity(0.5))
            }

            // Footer with actions
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(cancelHovered ? 0.2 : 0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .scaleEffect(cancelHovered ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        cancelHovered = hovering
                    }
                }

                Button(action: {
                    if !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSave(clipText)
                    }
                }) {
                    Text("Save Changes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                Color.gray.opacity(0.3) :
                                Color(appState.activeColor.nsColor).opacity(saveHovered ? 1.0 : 0.8)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .scaleEffect(saveHovered ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        saveHovered = hovering
                    }
                }

                Spacer()

                Text("\(clipText.count) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }
        }
        .frame(width: 430, height: 350)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1.5)
        )
        .onAppear {
            textFocused = true
            appState.play(.open)
        }
        .onExitCommand {
            // Allow Escape key to close without saving
            onDismiss()
        }
    }

    func formatDate(_ date: Date) -> String {
        DateFormatters.short.string(from: date)
    }
}

// MARK: - Add Clip Modal
struct AddClipModal: View {
    let onDismiss: () -> Void
    let onSave: (String) -> Void
    @EnvironmentObject var appState: AppState
    @State private var clipText = ""
    @State private var saveHovered = false
    @State private var cancelHovered = false
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Clip Manually")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Text("Saving to:")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))

                        Circle()
                            .fill(Color(appState.activeColor.nsColor))
                            .frame(width: 12, height: 12)

                        Text(appState.labelForColor(appState.activeColor.name))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(appState.activeColor.nsColor))
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }

            // Content
            TextEditor(text: $clipText)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.9))
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.7))
                .focused($textFocused)
                .onAppear {
                    textFocused = true
                }

            // Tag suggestions
            if !appState.allTagsWithCounts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appState.allTagsWithCounts.prefix(10), id: \.tag) { item in
                            Button(action: {
                                if !clipText.contains(item.tag) {
                                    clipText = (clipText.isEmpty ? "" : clipText + " ") + item.tag
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text(item.tag)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                    Text("\(item.count)")
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .opacity(0.6)
                                }
                                .foregroundColor(Color(appState.activeColor.nsColor))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(appState.activeColor.nsColor).opacity(0.14))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .background(Color.black.opacity(0.5))
            }

            // Footer with actions
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(cancelHovered ? 0.2 : 0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .scaleEffect(cancelHovered ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        cancelHovered = hovering
                    }
                }

                Button(action: {
                    if !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSave(clipText)
                    }
                }) {
                    Text("Save Clip")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                Color.gray.opacity(0.3) :
                                Color(appState.activeColor.nsColor).opacity(saveHovered ? 1.0 : 0.8)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .scaleEffect(saveHovered ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        saveHovered = hovering
                    }
                }

                Spacer()

                Text("\(clipText.count) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }
        }
        .frame(width: 430, height: 350)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1.5)
        )
        .onExitCommand {
            // Allow Escape key to close without saving
            onDismiss()
        }
    }
}

// MARK: - Help Modal
struct HelpModal: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var hoveredStep: Int? = nil

    private let shortcuts: [(keys: String, action: String)] = [
        ("⌃⌘N", "Show / hide NibNab"),
        ("⌃⌘M", "Pause / resume capturing"),
        ("⌃⌘1–5", "Switch active color"),
        ("⌃⌥⌘1–5", "Direct copy into color"),
        ("⌘Z", "Undo delete or merge"),
        ("Esc", "Close this window")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("How NibNab works")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }

            // Content
            VStack(alignment: .leading, spacing: 18) {
                helpStep(number: "1", index: 0, text: "Flip the switch and NibNab quietly nabs everything you copy.")
                helpStep(number: "2", index: 1, text: "Clips land in the active color — click the dots below to flip between collections.")
                helpStep(number: "3", index: 2, text: "Drag a clip onto a dot to re-file it. Click a clip to read, edit, or copy it.")

                Divider()
                    .overlay(Color.white.opacity(0.15))

                VStack(alignment: .leading, spacing: 8) {
                    Text("KEYBOARD SHORTCUTS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))

                    ForEach(shortcuts, id: \.keys) { shortcut in
                        HStack(spacing: 10) {
                            Text(shortcut.keys)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(appState.activeColor.nsColor))
                                .frame(width: 84, alignment: .leading)
                            Text(shortcut.action)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }

                Text("Right-click the menubar pen for capture settings, sounds, and more.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.black.opacity(0.7))
        }
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1.5)
        )
        .onExitCommand {
            onDismiss()
        }
    }

    private func helpStep(number: String, index: Int, text: String) -> some View {
        let isHovered = hoveredStep == index
        return HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color(appState.activeColor.nsColor)))
                .scaleEffect(isHovered ? 1.18 : 1.0)
                .shadow(color: Color(appState.activeColor.nsColor).opacity(isHovered ? 0.6 : 0), radius: 8)
            Text(text)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                hoveredStep = hovering ? index : nil
            }
        }
    }
}

// MARK: - Clip Detail View
struct ClipDetailView: View {
    private static let detailSize = CGSize(width: 460, height: 380)
    let clip: Clip
    let colorName: String
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var copyHovered = false
    @State private var deleteHovered = false
    @State private var editedText: String
    @State private var originalText: String
    @State private var selectedImageIndex = 0

    init(clip: Clip, colorName: String, onDismiss: @escaping () -> Void) {
        self.clip = clip
        self.colorName = colorName
        self.onDismiss = onDismiss
        _editedText = State(initialValue: clip.text)
        _originalText = State(initialValue: clip.text)
    }

    private var trimmedEditedText: String {
        editedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedEditedText.isEmpty && editedText != originalText
    }

    private var currentImage: NSImage? {
        guard !clip.imagePaths.isEmpty, selectedImageIndex < clip.imagePaths.count else { return nil }
        let path = clip.imagePaths[selectedImageIndex]
        let url = appState.storageManager.imageURL(for: path, in: colorName)
        return NSImage(contentsOf: url)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.appName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.659, green: 0.855, blue: 0.863))

                    HStack(spacing: 8) {
                        Text(formatDate(clip.timestamp))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))

                        if let urlString = clip.url, let url = URL(string: urlString) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 10))
                                    Text(url.host?.replacingOccurrences(of: "www.", with: "") ?? "link")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .lineLimit(1)
                                }
                                .foregroundColor(Color(appState.activeColor.nsColor))
                            }
                            .buttonStyle(.plain)
                            .help(urlString)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    saveChangesIfNeeded()
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }

            // Content
            VStack(spacing: 8) {
                if let nsImage = currentImage {
                    VStack(spacing: 6) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: clip.imagePaths.count > 1 ? 100 : 130)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(appState.activeColor.nsColor).opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: Color(appState.activeColor.nsColor).opacity(0.25), radius: 6)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        if clip.imagePaths.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(0..<clip.imagePaths.count, id: \.self) { idx in
                                        let path = clip.imagePaths[idx]
                                        let url = appState.storageManager.imageURL(for: path, in: colorName)
                                        if let thumb = ThumbnailLoader.thumbnail(for: url, maxDimension: 64) {
                                            Button(action: { selectedImageIndex = idx }) {
                                                Image(nsImage: thumb)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 32, height: 32)
                                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 5)
                                                            .stroke(selectedImageIndex == idx ? Color(appState.activeColor.nsColor) : Color.white.opacity(0.3), lineWidth: selectedImageIndex == idx ? 2 : 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1)
                        )

                    TextEditor(text: $editedText)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.92))
                        .scrollContentBackground(.hidden)
                        .padding(14)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Footer with actions
            HStack(spacing: 12) {
                Button(action: {
                    saveChangesIfNeeded()
                    appState.copyToPasteboard(editedText)
                    onDismiss()
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(copyHovered ? 0.3 : 0.2))
                .cornerRadius(8)
                .scaleEffect(copyHovered ? 1.05 : 1.0)
                .help("Copy text to clipboard")
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        copyHovered = hovering
                    }
                }

                if let nsImage = currentImage {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([nsImage])
                        appState.play(.copy)
                        onDismiss()
                    }) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .help("Copy image to clipboard")
                }

                Button(action: {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.deleteClip(clip, from: colorName)
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(deleteHovered ? 0.25 : 0.15))
                .cornerRadius(8)
                .scaleEffect(deleteHovered ? 1.05 : 1.0)
                .help("Delete clip")
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        deleteHovered = hovering
                    }
                }

                if appState.hasAiSuperpowers {
                    Menu {
                        Button(action: {
                            saveChangesIfNeeded()
                            appState.aiAutoTagClip(clip, in: colorName)
                            onDismiss()
                        }) {
                            Label("Auto-Tag with AI", systemImage: "tag")
                        }

                        Button(action: {
                            Task {
                                do {
                                    let cleaned = try await NibAI.cleanOCR(text: editedText, apiKey: appState.geminiApiKey)
                                    await MainActor.run {
                                        editedText = cleaned
                                        appState.play(.celebrate)
                                    }
                                } catch { }
                            }
                        }) {
                            Label("Clean to Markdown", systemImage: "sparkles")
                        }

                        Button(action: {
                            Task {
                                do {
                                    let summary = try await NibAI.summarizeToBullets(text: editedText, apiKey: appState.geminiApiKey)
                                    await MainActor.run {
                                        editedText = editedText + "\n\n### ⚡ Summary\n" + summary
                                        appState.play(.celebrate)
                                    }
                                } catch { }
                            }
                        }) {
                            Label("Summarize to Bullets", systemImage: "list.bullet")
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(Color(appState.activeColor.nsColor))
                    }
                    .menuStyle(.borderlessButton)
                    .padding(8)
                    .background(Color(appState.activeColor.nsColor).opacity(0.15))
                    .cornerRadius(8)
                    .help("AI Superpowers")
                }

                Spacer()

                Text("\(editedText.count) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }
        }
        .frame(width: Self.detailSize.width, height: Self.detailSize.height)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1.5)
        )
        .onAppear {
            appState.play(.open)
        }
        .onDisappear {
            saveChangesIfNeeded()
        }
        .onExitCommand {
            // Allow Escape key to close
            saveChangesIfNeeded()
            onDismiss()
        }
    }

    func formatDate(_ date: Date) -> String {
        DateFormatters.full.string(from: date)
    }

    private func saveChangesIfNeeded() {
        guard canSave else { return }
        appState.updateClip(clip, newText: editedText, in: colorName)
        originalText = editedText
    }
}

// MARK: - About View
struct AboutLink: View {
    let label: String
    let url: String

    @State private var isHovered = false

    var body: some View {
        Link(label, destination: URL(string: url)!)
            .foregroundColor(isHovered ? Color(NibColor.pink.nsColor) : .secondary)
            .underline(isHovered)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
            }
    }
}

struct AboutView: View {
    @State private var hoveredShortcut: Int? = nil

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        return "Version \(version)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(Color(NibColor.pink.nsColor))
                        .shadow(color: Color(NibColor.pink.nsColor).opacity(0.3), radius: 8)

                    VStack(spacing: 6) {
                        Text("NibNab")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.primary)

                        Text(versionText)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Text("Capture the good bits, organized by color")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)

                Divider()

                // Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 0) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    VStack(spacing: 2) {
                        ShortcutRow(
                            icon: "highlighter",
                            description: "Toggle popover",
                            keys: ["⌃", "⌘", "N"],
                            color: NibColor.pink,
                            isHovered: hoveredShortcut == 0
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 0 : nil
                            }
                        }

                        ShortcutRow(
                            icon: "power",
                            description: "Toggle auto-capture",
                            keys: ["⌃", "⌘", "M"],
                            color: NibColor.pink,
                            isHovered: hoveredShortcut == 1
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 1 : nil
                            }
                        }

                        Divider()
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)

                        ShortcutRow(
                            icon: "circle.fill",
                            description: "Yellow highlighter",
                            keys: ["⌃", "⌘", "1"],
                            color: NibColor.yellow,
                            isHovered: hoveredShortcut == 2
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 2 : nil
                            }
                        }

                        ShortcutRow(
                            icon: "circle.fill",
                            description: "Orange highlighter",
                            keys: ["⌃", "⌘", "2"],
                            color: NibColor.orange,
                            isHovered: hoveredShortcut == 3
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 3 : nil
                            }
                        }

                        ShortcutRow(
                            icon: "circle.fill",
                            description: "Pink highlighter",
                            keys: ["⌃", "⌘", "3"],
                            color: NibColor.pink,
                            isHovered: hoveredShortcut == 4
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 4 : nil
                            }
                        }

                        ShortcutRow(
                            icon: "circle.fill",
                            description: "Purple highlighter",
                            keys: ["⌃", "⌘", "4"],
                            color: NibColor.purple,
                            isHovered: hoveredShortcut == 5
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 5 : nil
                            }
                        }

                        ShortcutRow(
                            icon: "circle.fill",
                            description: "Green highlighter",
                            keys: ["⌃", "⌘", "5"],
                            color: NibColor.green,
                            isHovered: hoveredShortcut == 6
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 6 : nil
                            }
                        }

                        Divider()
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)

                        ShortcutRow(
                            icon: "space",
                            description: "Preview / edit card & gallery",
                            keys: ["Space"],
                            color: NibColor.yellow,
                            isHovered: hoveredShortcut == 7
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 7 : nil
                            }
                        }

                        ShortcutRow(
                            icon: "return",
                            description: "Copy clip & dismiss",
                            keys: ["Return"],
                            color: NibColor.orange,
                            isHovered: hoveredShortcut == 8
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 8 : nil
                            }
                        }

                        ShortcutRow(
                            icon: "arrow.uturn.backward",
                            description: "Undo last action",
                            keys: ["⌘", "Z"],
                            color: NibColor.pink,
                            isHovered: hoveredShortcut == 9
                        )
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                hoveredShortcut = hovering ? 9 : nil
                            }
                        }
                    }
                }
                .padding(.bottom, 20)

                Divider()

                // Where things actually live — the promise worth stating plainly
                VStack(spacing: 8) {
                    Text("Every clip is a plain markdown file on your Mac.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("No account, no cloud, no sync. Nothing leaves your machine — open the files in any editor, or move on whenever you like.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 22)

                Divider()

                // Footer
                VStack(spacing: 10) {
                    Text("Made by Pablo in Melbourne, on love and coffee.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        AboutLink(label: "madebypablo.app", url: "https://madebypablo.app")
                        Text("·").foregroundColor(.secondary.opacity(0.5))
                        AboutLink(label: "☕ Coffee jar", url: "https://ko-fi.com/madebypablo")
                        Text("·").foregroundColor(.secondary.opacity(0.5))
                        AboutLink(label: "GitHub", url: "https://github.com/pibulus")
                    }
                    .font(.system(size: 12))

                    HStack(spacing: 8) {
                        ForEach(NibColor.all, id: \.name) { color in
                            Circle()
                                .fill(Color(color.nsColor))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(width: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ShortcutRow: View {
    let icon: String
    let description: String
    let keys: [String]
    let color: NibColor
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(color.nsColor))
                .frame(width: 24)

            Text(description)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
    }
}

// MARK: - Welcome Modal (In-Popover)
struct WelcomeModal: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var gotItHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(appState.activeColor.nsColor))

                    Text("Welcome to NibNab!")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    WelcomeFeatureRow(
                        icon: "camera.viewfinder",
                        color: NibColor.yellow,
                        title: "Screenshots & Offline OCR",
                        description: "Snap screenshots (⌘⇧4) — NibNab grabs them & runs local Apple Vision OCR"
                    )

                    WelcomeFeatureRow(
                        icon: "circle.grid.2x2",
                        color: NibColor.orange,
                        title: "5 Color Collections & Shortcuts",
                        description: "Switch colors with ⌃⌘1–5 or copy straight into any color with ⌃⌥⌘1–5"
                    )

                    WelcomeFeatureRow(
                        icon: "tag",
                        color: NibColor.pink,
                        title: "ZipList Tag Rack",
                        description: "Include #tags in your clips to filter them with one click on the tag shelf"
                    )

                    WelcomeFeatureRow(
                        icon: "arrow.triangle.merge",
                        color: NibColor.purple,
                        title: "Multi-Image Cards & Merge",
                        description: "Burst screenshots group automatically, or drag cards together to merge"
                    )

                    WelcomeFeatureRow(
                        icon: "square.and.arrow.down",
                        color: NibColor.green,
                        title: "Obsidian Ready & Yours To Keep",
                        description: "Every clip is a plain local markdown file. Export bundles anytime"
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(Color.black.opacity(0.65))

            // Footer
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("Got it!")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(NibColor.pink.nsColor).opacity(gotItHovered ? 1.0 : 0.9),
                                            Color(NibColor.purple.nsColor).opacity(gotItHovered ? 1.0 : 0.9)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .scaleEffect(gotItHovered ? 1.04 : 1.0)
                        .shadow(color: Color(NibColor.pink.nsColor).opacity(0.3), radius: 6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        gotItHovered = hovering
                    }
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color.nibSurface)
        }
        .frame(width: 460, height: 400)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1.5)
        )
        .onExitCommand {
            onDismiss()
        }
    }
}

struct WelcomeFeatureRow: View {
    let icon: String
    let color: NibColor
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(color.nsColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: NibColor
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color(color.nsColor))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Toast Notification
struct ToastView: View {
    let message: String
    let color: NibColor
    var onUndo: (() -> Void)? = nil

    @State private var undoHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(color.nsColor))
                .frame(width: 10, height: 10)
                .shadow(color: Color(color.nsColor).opacity(0.5), radius: 4)

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            if let onUndo {
                Button(action: onUndo) {
                    Text("Undo")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.black.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color(color.nsColor).opacity(undoHovered ? 1.0 : 0.85))
                        )
                }
                .buttonStyle(NibPressStyle(scale: 0.9))
                .help("Undo (⌘Z)")
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        undoHovered = hovering
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(color.nsColor).opacity(0.6),
                                    Color(color.nsColor).opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: Color(color.nsColor).opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

// MARK: - API Key Modal (Gemini Superpowers)
struct ApiKeyModal: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var keyInput: String = ""
    @State private var saveHovered = false
    @State private var cancelHovered = false
    @State private var isTesting = false
    @State private var testResult: String? = nil
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(appState.activeColor.nsColor))
                    Text("AI Superpowers (Gemini)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding()
            .background(Color.nibSurface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }

            // Content
            VStack(alignment: .leading, spacing: 14) {
                Text("Enter your Gemini API key to unlock auto-tagging, OCR cleanup, and instant bullet summarization. Core NibNab (offline OCR & local storage) stays 100% private.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                Text("🔒 Stored securely in your macOS Keychain. Requests are sent directly to Google's official endpoint with zero intermediate servers.")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("Paste API Key (AIzaSy...)", text: $keyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1)
                    )
                    .focused($inputFocused)

                Toggle("Auto-tag new screenshots with AI (default off)", isOn: $appState.autoTagScreenshotsEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))

                if let result = testResult {
                    Text(result)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(result.contains("verified") ? Color(appState.activeColor.nsColor) : Color.red.opacity(0.9))
                }

                HStack {
                    Link("Get free Gemini API key ↗", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(appState.activeColor.nsColor))

                    Spacer()

                    if !appState.geminiApiKey.isEmpty {
                        Button("Clear Key (Go Offline)") {
                            appState.geminiApiKey = ""
                            keyInput = ""
                            testResult = nil
                            appState.play(.toggleOff)
                            onDismiss()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .background(Color.black.opacity(0.7))

            // Footer
            HStack {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(cancelHovered ? 0.2 : 0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .scaleEffect(cancelHovered ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        cancelHovered = hovering
                    }
                }

                Spacer()

                if !keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {
                        isTesting = true
                        testResult = nil
                        Task {
                            let (_, msg) = await appState.testApiKey(keyInput)
                            await MainActor.run {
                                isTesting = false
                                testResult = msg
                            }
                        }
                    }) {
                        Text(isTesting ? "Testing..." : "Test Key")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
                }

                Button(action: {
                    appState.geminiApiKey = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    appState.play(.celebrate)
                    appState.showToast(appState.hasAiSuperpowers ? "AI Superpowers Active ✨" : "Key Cleared", color: appState.activeColor)
                    onDismiss()
                }) {
                    Text("Save Key")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(appState.activeColor.nsColor).opacity(saveHovered ? 1.0 : 0.8))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .scaleEffect(saveHovered ? 1.05 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        saveHovered = hovering
                    }
                }
            }
            .padding()
            .background(Color.nibSurface)
        }
        .frame(width: 450)
        .fixedSize(horizontal: false, vertical: true)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(appState.activeColor.nsColor).opacity(0.5), lineWidth: 1.5)
        )
        .onAppear {
            keyInput = appState.geminiApiKey
            inputFocused = true
            appState.play(.open)
        }
        .onExitCommand {
            onDismiss()
        }
    }
}
