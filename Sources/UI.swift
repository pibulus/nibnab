import SwiftUI
import Cocoa

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
    let clipCount: Int
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
    }

    private var primaryControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "highlighter")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(appState.activeColor.nsColor))
                Text("NibNab")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Color(appState.activeColor.nsColor))
                    .fixedSize()
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
            .help(appState.isMonitoring ? "Capturing — click to pause" : "Paused — click to start capturing")
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
            }, help: "Add clip")

            HeaderMenuButton(
                systemName: "ellipsis",
                help: "Collection actions",
                isDisabled: clipCount == 0
            ) {
                Button("Export as Markdown") {
                    appState.exportClipsAsMarkdown(for: appState.activeColor.name)
                }
                Button("Export as Plain Text") {
                    appState.exportClipsAsPlainText(for: appState.activeColor.name)
                }

                Divider()

                Button("Merge All Into One Clip") {
                    appState.mergeAllClips(in: appState.activeColor.name)
                }
                .disabled(clipCount < 2)

                Divider()

                Button("Export & Clear\u{2026}") {
                    appState.exportAndClear(for: appState.activeColor.name)
                }
                Button("Clear All\u{2026}", role: .destructive) {
                    showClearConfirm = true
                }
            }

            HeaderIconButton(systemName: "questionmark", action: {
                showHelp = true
            }, help: "How NibNab works")
        }
    }
}

struct ContentFooterView: View {
    @EnvironmentObject var appState: AppState
    @Binding var editingLabel: Bool
    @Binding var labelText: String
    @Binding var labelHovered: Bool
    var labelFocused: FocusState<Bool>.Binding
    let horizontalPadding: CGFloat
    let viewedClipCount: Int
    let resultCount: Int?
    let handleColorDrop: ([Clip], NibColor) -> Void

    var body: some View {
        ZStack {
            HStack {
                footerLabel
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
        .padding(.top, 16)
        .padding(.bottom, 20)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(appState.activeColor.nsColor))
                .help("Searching every collection")
        } else if isFull {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("\(viewedClipCount) / \(AppState.maxClipsPerColor) full")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(Color(NibColor.orange.nsColor))
            .help("This collection is full — the next capture drops the oldest clip. Export, merge, or clear to keep them.")
        } else {
            Text("\(viewedClipCount) clips")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(appState.activeColor.nsColor))
        }
    }

    private var footerLabel: some View {
        HStack(spacing: 4) {
            Text("Active:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(appState.activeColor.nsColor))

            if editingLabel {
                HStack(spacing: 4) {
                    TextField("", text: $labelText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(appState.activeColor.nsColor))
                        .frame(width: 120)
                        .focused(labelFocused)
                        .onSubmit {
                            appState.setLabel(labelText, forColor: appState.activeColor.name)
                            editingLabel = false
                            labelFocused.wrappedValue = false
                        }
                        .onExitCommand {
                            // Cancel editing on Escape key
                            editingLabel = false
                            labelFocused.wrappedValue = false
                        }

                    Text("\(labelText.count)/12")
                        .font(.system(size: 9, design: .monospaced))
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
                    HStack(spacing: 3) {
                        Text(appState.labelForColor(appState.activeColor.name))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(appState.activeColor.nsColor))

                        Image(systemName: "pencil")
                            .font(.system(size: 8))
                            .foregroundColor(Color(appState.activeColor.nsColor).opacity(labelHovered ? 0.9 : 0.4))
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        labelHovered = hovering
                    }
                }
                .help("Click to rename")
            }
        }
        .onChange(of: appState.activeColor.name, perform: { _ in
            // Cancel editing when switching colors to prevent label bleeding
            if editingLabel {
                editingLabel = false
                labelFocused.wrappedValue = false
            }
        })
    }
}

struct ContentOverlaysView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedClip: Clip?
    @Binding var showAddClipModal: Bool
    @Binding var editingClip: Clip?
    @Binding var showHelp: Bool
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

            // Welcome modal shown in separate window, not in popover
        }
    }

    private func overlayBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.play(.close)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        showAddClipModal = false
                        editingClip = nil
                        selectedClip = nil
                        showHelp = false
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
                    clipCount: appState.clips[appState.activeColor.name]?.count ?? 0,
                    horizontalPadding: Self.horizontalPadding - 10
                )
                .environmentObject(appState)

                Divider()
                contentArea
                ContentFooterView(
                    editingLabel: $editingLabel,
                    labelText: $labelText,
                    labelHovered: $labelHovered,
                    labelFocused: $labelFocused,
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
                modalColorName: modalColorName
            )
            .environmentObject(appState)
            toastOverlay
        }
        .frame(width: Self.popoverSize.width, height: Self.popoverSize.height)
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: appState.activeColor.name) { _ in focusedClipID = nil }
        .onChange(of: appState.popoverClosedCount) { _ in
            selectedClip = nil
            editingClip = nil
            showAddClipModal = false
            showHelp = false
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

                                Button(action: {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.deleteClip(clip, from: row.color.name)
                                    }
                                }) {
                                    Label("Delete", systemImage: "trash")
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
              !showAddClipModal, !showHelp, !editingLabel else { return event }
        if NSApp.keyWindow?.firstResponder is NSTextView { return event }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

                Spacer()

                // Timestamp with padding to avoid overlap with hover buttons
                Text(timeAgo(from: clip.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.trailing, isHovered ? 56 : 0)
            }

            Text(clip.text.prefix(150) + (clip.text.count > 150 ? "..." : ""))
                .font(.system(size: 12))
                .lineLimit(3)
                .foregroundColor(Color.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(color.nsColor).opacity(isDropTargeted || isKeyFocused ? 0.9 : (isHovered ? 0.55 : 0.2)), lineWidth: isDropTargeted || isKeyFocused ? 2 : 1.5)
        )
        .shadow(color: Color(color.nsColor).opacity(isKeyFocused ? 0.5 : 0), radius: 8)
        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
        // The merge zone used to be an invisible 24px band. Dropping there
        // destroys two clips to make one, so while a drag is over this card
        // the band names itself and the edges show where an insert would go.
        .overlay(
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
        )
        .overlay(
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
            },
            alignment: .topTrailing
        )
        .draggable(clip) {
            // Drag preview
            Text(clip.text.prefix(50))
                .font(.system(size: 12))
                .padding(8)
                .background(Color(color.nsColor).opacity(0.3))
                .cornerRadius(8)
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
            .background(Color.black.opacity(0.9))
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
            .background(Color.black.opacity(0.9))
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
            .background(Color.black.opacity(0.9))
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
            .background(Color.black.opacity(0.9))
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
        ("⌃⌘1–5", "Switch active color"),
        ("⌃⌘M", "Pause / resume capturing"),
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
            .background(Color.black.opacity(0.9))
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
                                .frame(width: 64, alignment: .leading)
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.appName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.659, green: 0.855, blue: 0.863))

                    Text(formatDate(clip.timestamp))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
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
            .background(Color.black.opacity(0.9))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(appState.activeColor.nsColor).opacity(0.4))
                    .frame(height: 1)
            }

            // Content
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
                    .padding(18)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                .help("Copy to clipboard")
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        copyHovered = hovering
                    }
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

                Spacer()

                Text("\(editedText.count) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(Color.black.opacity(0.9))
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

// MARK: - Welcome View
struct WelcomeView: View {
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var gotItHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "highlighter")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(NibColor.pink.nsColor))
                    .shadow(color: Color(NibColor.pink.nsColor).opacity(0.3), radius: 8)

                Text("Welcome to NibNab!")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Content
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "doc.on.clipboard",
                    color: NibColor.yellow,
                    title: "Automatic Capture",
                    description: "Copy anything and NibNab saves it to your active color"
                )

                FeatureRow(
                    icon: "paintpalette",
                    color: NibColor.pink,
                    title: "Color Collections",
                    description: "Organize clips with 5 vibrant colors. Switch anytime with ⌃⌘1-5"
                )

                FeatureRow(
                    icon: "keyboard",
                    color: NibColor.green,
                    title: "Keyboard Shortcuts",
                    description: "Toggle popover: ⌃⌘N • Auto-capture: ⌃⌘M • Right-click menubar icon for more"
                )

                FeatureRow(
                    icon: "magnifyingglass",
                    color: NibColor.purple,
                    title: "Find It Later",
                    description: "Search looks in every color at once, so you never have to remember where a clip went"
                )

                FeatureRow(
                    icon: "square.and.arrow.down",
                    color: NibColor.orange,
                    title: "Yours To Keep",
                    description: "Clips are plain markdown files on your Mac. Export any color as Markdown or text"
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)

            // Footer
            Button(action: onDismiss) {
                Text("Got it!")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
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
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .scaleEffect(gotItHovered ? 1.02 : 1.0)
                    .shadow(color: Color(NibColor.pink.nsColor).opacity(0.3), radius: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    gotItHovered = hovering
                }
            }
        }
        .frame(width: 460)
        .background(
            ZStack {
                Color.black.opacity(0.9)
                LinearGradient(
                    colors: [
                        Color(NibColor.pink.nsColor).opacity(0.1),
                        Color(NibColor.purple.nsColor).opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.5), radius: 20)
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
