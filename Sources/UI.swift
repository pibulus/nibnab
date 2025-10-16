import SwiftUI
import Cocoa
import UniformTypeIdentifiers

struct NibToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ?
                    LinearGradient(
                        colors: [Color.white,
                                Color.white.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 40, height: 24)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .offset(x: configuration.isOn ? 8 : -8)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedClip: Clip?
    @State private var sortOrder: SortOrder = .newestFirst
    @State private var searchText = ""
    @State private var sortHovered = false
    @State private var exportHovered = false
    @State private var toggleHovered = false
    @State private var clearHovered = false
    @State private var showClearConfirm = false
    @State private var editingLabel = false
    @State private var labelText = ""
    @State private var labelHovered = false
    @State private var showAddClipModal = false
    @State private var addHovered = false
    @State private var showExportDialog = false
    @State private var editingClip: Clip?
    @FocusState private var searchFocused: Bool
    @FocusState private var labelFocused: Bool

    enum SortOrder {
        case newestFirst, oldestFirst, byAppName, byLength
    }

    var sortedClips: [Clip] {
        guard let clips = appState.clips[appState.viewedColor.name] else { return [] }

        let filteredClips = searchText.isEmpty ? clips : clips.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            $0.appName.localizedCaseInsensitiveContains(searchText)
        }

        switch sortOrder {
        case .newestFirst:
            return filteredClips.sorted { $0.timestamp > $1.timestamp }
        case .oldestFirst:
            return filteredClips.sorted { $0.timestamp < $1.timestamp }
        case .byAppName:
            return filteredClips.sorted { $0.appName < $1.appName }
        case .byLength:
            return filteredClips.sorted { $0.text.count > $1.text.count }
        }
    }

    var hasExportableClips: Bool {
        guard let clips = appState.clips[appState.viewedColor.name] else { return false }
        return !clips.isEmpty
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                contentArea
                footer
            }
            overlays
            toastOverlay
        }
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
                appState.clearAllClips(for: appState.viewedColor.name)
            }
        } message: {
            let shortName = appState.viewedColor.name.replacingOccurrences(of: "Highlighter ", with: "")
            let count = appState.clips[appState.viewedColor.name]?.count ?? 0
            Text("This will permanently delete all \(count) \(shortName) clips.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            primaryControls
            Spacer()
            searchControls
            Spacer()
            actionControls
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
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
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "highlighter")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(appState.activeColor.nsColor))
                Text("NibNab")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Color(appState.activeColor.nsColor))
                    .fixedSize()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(toggleHovered ? 0.2 : 0.0))
                    .frame(width: 52, height: 32)

                Toggle("", isOn: $appState.isMonitoring)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(toggleHovered ? 0.75 : 0.7)
                    .help(appState.isMonitoring ? "Active - capturing clips" : "Paused - click to activate")
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    toggleHovered = hovering
                }
            }
        }
    }

    private var searchControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .frame(width: 90)
                    .focused($searchFocused)
                    .onAppear {
                        searchFocused = false
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)

            Menu {
                Button("Newest First") { sortOrder = .newestFirst }
                Button("Oldest First") { sortOrder = .oldestFirst }
                Button("By App Name") { sortOrder = .byAppName }
                Button("By Length") { sortOrder = .byLength }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(sortHovered ? 1.0 : 0.7))
                    .scaleEffect(sortHovered ? 1.15 : 1.0)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Sort clips")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    sortHovered = hovering
                }
            }
        }
    }

    private var actionControls: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                showAddClipModal = true
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(addHovered ? 1.0 : 0.7))
                    .scaleEffect(addHovered ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .help("Add clip")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    addHovered = hovering
                }
            }

            Button(action: {
                guard hasExportableClips else { return }
                showExportDialog = true
            }) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(exportHovered ? 1.0 : 0.85))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(exportHovered ? 0.18 : 0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(exportHovered ? 0.35 : 0.2), lineWidth: 1)
                    )
                    .scaleEffect(exportHovered ? 1.08 : 1.0)
            }
            .buttonStyle(.plain)
            .help("Export clips")
            .disabled(!hasExportableClips)
            .opacity(hasExportableClips ? 1.0 : 0.35)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    exportHovered = hasExportableClips ? hovering : false
                }
            }
            .confirmationDialog(
                "Export Clips",
                isPresented: $showExportDialog,
                titleVisibility: .visible
            ) {
                Button("Export as Markdown") {
                    appState.exportClipsAsMarkdown(for: appState.viewedColor.name)
                    showExportDialog = false
                }
                Button("Export as Plain Text") {
                    appState.exportClipsAsPlainText(for: appState.viewedColor.name)
                    showExportDialog = false
                }
                Button("Cancel", role: .cancel) {
                    showExportDialog = false
                }
            } message: {
                Text("Choose how you want to export the \(appState.clips[appState.viewedColor.name]?.count ?? 0) clips in this collection.")
            }
            .onChange(of: hasExportableClips) { available in
                if !available {
                    exportHovered = false
                    showExportDialog = false
                }
            }

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            Button(action: {
                showClearConfirm = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(clearHovered ? 1.0 : 0.7))
                    .scaleEffect(clearHovered ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .help("Clear all clips")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    clearHovered = hovering
                }
            }
        }
    }

    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !sortedClips.isEmpty {
                    ForEach(Array(sortedClips.enumerated()), id: \.element.id) { index, clip in
                        ClipView(clip: clip)
                            .onTapGesture {
                                selectedClip = clip
                            }
                            .onDrop(of: [UTType.nibNabClip, .text], isTargeted: nil) { providers in
                                handleDrop(providers: providers, at: index)
                            }
                            .contextMenu {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(clip.text, forType: .string)
                                }) {
                                    Label("Copy", systemImage: "doc.on.clipboard")
                                }

                                Button(action: {
                                    editingClip = clip
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(action: {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        appState.deleteClip(clip, from: appState.viewedColor.name)
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
            .padding(12)
        }
        .frame(height: 280)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(Color.white.opacity(0.3))

            VStack(spacing: 8) {
                Text("Nothing nabbed yet")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.8))
                Text("Copy something good")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(.top, 40)
    }

    private var footer: some View {
        let viewedClipCount = appState.clips[appState.viewedColor.name]?.count ?? 0

        return ZStack {
            HStack {
                footerLabel
                Spacer()
                Text("\(viewedClipCount) clips")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(appState.activeColor.nsColor))
            }

            HStack(spacing: 8) {
                ForEach(NibColor.all, id: \.name) { color in
                    ColorDropTarget(
                        color: color,
                        isActive: appState.activeColor.name == color.name,
                        onTap: {
                            appState.viewedColor = color
                            appState.activeColor = color
                        },
                        onDrop: { providers in
                            handleColorDrop(providers: providers, to: color)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
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

    private var footerLabel: some View {
        HStack(spacing: 4) {
            Text("Active:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(appState.activeColor.nsColor))

            if editingLabel {
                TextField("", text: $labelText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(appState.activeColor.nsColor))
                    .frame(width: 80)
                    .focused($labelFocused)
                    .onSubmit {
                        appState.setLabel(labelText, forColor: appState.activeColor.name)
                        editingLabel = false
                    }
            } else {
                Button(action: {
                    labelText = appState.labelForColor(appState.activeColor.name)
                    editingLabel = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        labelFocused = true
                    }
                }) {
                    HStack(spacing: 3) {
                        Text(appState.labelForColor(appState.activeColor.name))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(appState.activeColor.nsColor))

                        if labelHovered {
                            Image(systemName: "pencil")
                                .font(.system(size: 8))
                                .foregroundColor(Color(appState.activeColor.nsColor).opacity(0.6))
                        }
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        labelHovered = hovering
                    }
                }
                .help("Click to rename")
            }
        }
    }

    @ViewBuilder
    private var overlays: some View {
        if let clip = selectedClip {
            overlayBackground {
                ClipDetailView(clip: clip) {
                    withAnimation {
                        selectedClip = nil
                    }
                }
                .environmentObject(appState)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }

        if showAddClipModal {
            overlayBackground {
                AddClipModal(onDismiss: {
                    withAnimation {
                        showAddClipModal = false
                    }
                }, onSave: { text in
                    appState.saveClip(text, to: appState.activeColor, from: "Manual Entry")
                    withAnimation {
                        showAddClipModal = false
                    }
                })
                .environmentObject(appState)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }

        if let clip = editingClip {
            overlayBackground {
                EditClipModal(
                    clip: clip,
                    onDismiss: {
                        withAnimation {
                            editingClip = nil
                        }
                    },
                    onSave: { newText in
                        appState.updateClip(clip, newText: newText, in: appState.viewedColor.name)
                        withAnimation {
                            editingClip = nil
                        }
                    }
                )
                .environmentObject(appState)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }

        if appState.showWelcome {
            overlayBackground {
                WelcomeView(onDismiss: {
                    withAnimation {
                        appState.showWelcome = false
                    }
                })
                .environmentObject(appState)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = appState.toastMessage, let color = appState.toastColor {
            VStack {
                Spacer()
                ToastView(message: message, color: color)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appState.toastMessage)
        }
    }

    private func overlayBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showAddClipModal = false
                        editingClip = nil
                        selectedClip = nil
                    }
                }

            content()
        }
    }

    private func handleDrop(providers: [NSItemProvider], at index: Int) -> Bool {
        loadClip(from: providers) { droppedClip in
            appState.reorderClip(droppedClip, in: appState.viewedColor.name, to: index)
        }
    }

    private func handleColorDrop(providers: [NSItemProvider], to targetColor: NibColor) -> Bool {
        loadClip(from: providers) { droppedClip in
            guard let (sourceColor, _) = appState.clips.first(where: { $0.value.contains(droppedClip) }) else {
                print("🔴 Drop failed: clip not found in current collections")
                return
            }

            appState.moveClip(droppedClip, from: sourceColor, to: targetColor.name)
            appState.viewedColor = targetColor
            appState.activeColor = targetColor
        }
    }

    @discardableResult
    private func loadClip(from providers: [NSItemProvider], completion: @escaping (Clip) -> Void) -> Bool {
        guard let provider = providers.first else {
            print("🔴 Drop failed: no item provider")
            return false
        }

        let decoder = JSONDecoder()

        let handleData: (Data) -> Void = { data in
            if let clip = try? decoder.decode(Clip.self, from: data) {
                DispatchQueue.main.async {
                    completion(clip)
                }
            } else {
                print("🔴 Drop failed: unable to decode clip payload")
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.nibNabClip.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.nibNabClip.identifier) { data, error in
                if let error = error {
                    print("🔴 Drop failed: custom type load error - \(error)")
                    return
                }
                guard let data = data else {
                    print("🔴 Drop failed: custom type returned nil data")
                    return
                }
                handleData(data)
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                if let error = error {
                    print("🔴 Drop failed: text load error - \(error)")
                    return
                }

                if let string = item as? String, let data = string.data(using: .utf8) {
                    handleData(data)
                } else if let data = item as? Data {
                    handleData(data)
                } else if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    handleData(data)
                } else {
                    print("🔴 Drop failed: unsupported item type \(String(describing: item))")
                }
            }
            return true
        }

        print("🔴 Drop failed: provider does not conform to supported types")
        return false
    }
}

// MARK: - Color Drop Target (Footer Color Circles)
struct ColorDropTarget: View {
    let color: NibColor
    let isActive: Bool
    let onTap: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isTargeted = false
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            // Larger invisible drop target area
            ZStack {
                // Invisible larger hit area for drops
                Circle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)

                // Visible color circle
                Circle()
                    .fill(Color(color.nsColor))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isActive ? 3 : 0)
                    )
                    .overlay(
                        // Visual feedback when being dragged over
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: isTargeted ? 2 : 0)
                            .scaleEffect(isTargeted ? 1.3 : 1.0)
                    )
                    .scaleEffect(isTargeted ? 1.12 : (isHovered ? 1.08 : 1.0))
            }
            .scaleEffect(isTargeted ? 1.12 : (isHovered ? 1.06 : 1.0))
        }
        .buttonStyle(.plain)
        .help("Switch to \(color.name)\nDrag clips here to change color")
        .onDrop(of: [UTType.nibNabClip, .text], isTargeted: $isTargeted) { providers in
            return onDrop(providers)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Color Tab Component
struct ColorTab: View {
    let color: NibColor
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color.nsColor))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 4 : (isHovered ? 2 : 0))
                )
                .overlay(
                    // Selected indicator - inner ring
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: isSelected ? 2 : 0)
                        .frame(width: 24, height: 24)
                )
                .scaleEffect(isHovered ? 1.15 : (isSelected ? 1.1 : 1.0))
                .shadow(color: isSelected ? Color.black.opacity(0.3) : (isHovered ? Color.black.opacity(0.1) : Color.clear), radius: isSelected ? 4 : 2, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clip View Component
struct ClipView: View {
    let clip: Clip
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(clip.appName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.659, green: 0.855, blue: 0.863))

                Spacer()

                // Timestamp with padding to avoid overlap with hover buttons
                Text(timeAgo(from: clip.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.trailing, isHovered ? 50 : 0) // Make room for buttons when hovered
            }

            Text(clip.text.prefix(150) + (clip.text.count > 150 ? "..." : ""))
                .font(.system(size: 12))
                .lineLimit(3)
                .foregroundColor(Color.white.opacity(0.9))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: isHovered ?
                            [Color.white.opacity(0.15), Color.white.opacity(0.1)] :
                            [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.71, blue: 0.655).opacity(0.2),
                                Color(red: 0.659, green: 0.855, blue: 0.863).opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            Group {
                if isHovered {
                    HStack(spacing: 6) {
                        // Copy button
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(clip.text, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)

                        // Delete button
                        Button(action: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                appState.deleteClip(clip, from: appState.viewedColor.name)
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(6)
                }
            },
            alignment: .topTrailing
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .onDrag {
            isDragging = true
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(clip),
                  let jsonString = String(data: data, encoding: .utf8) else {
                isDragging = false
                return NSItemProvider()
            }

            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: UTType.nibNabClip.identifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
            provider.registerObject(jsonString as NSString, visibility: .all)
            return provider
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onChange(of: isDragging) { newValue in
            if !newValue {
                // Reset drag state with delay to allow drop to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isDragging = false
                }
            }
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

                    Text("\(clip.appName) • \(formatDate(clip.timestamp))")
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
            }
            .padding()
            .background(Color.black.opacity(0.9))

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
                    withAnimation(.easeInOut(duration: 0.15)) {
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
                    withAnimation(.easeInOut(duration: 0.15)) {
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
        }
        .frame(width: 500, height: 400)
        .cornerRadius(12)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
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
            }
            .padding()
            .background(Color.black.opacity(0.9))

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
                    withAnimation(.easeInOut(duration: 0.15)) {
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
                    withAnimation(.easeInOut(duration: 0.15)) {
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
        }
        .frame(width: 500, height: 400)
        .cornerRadius(12)
    }
}

// MARK: - Clip Detail View
struct ClipDetailView: View {
    let clip: Clip
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var copyHovered = false
    @State private var deleteHovered = false

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

                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.9))

            // Content
            ScrollView {
                Text(clip.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.9))
                    .textSelection(.enabled)
                    .padding()
            }
            .background(Color.black.opacity(0.7))

            // Footer with actions
            HStack(spacing: 12) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(clip.text, forType: .string)
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
                    withAnimation(.easeInOut(duration: 0.15)) {
                        copyHovered = hovering
                    }
                }

                Button(action: {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.deleteClip(clip, from: appState.viewedColor.name)
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
                    withAnimation(.easeInOut(duration: 0.15)) {
                        deleteHovered = hovering
                    }
                }

                Spacer()

                Text("\(clip.text.count) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(Color.black.opacity(0.9))
        }
        .frame(width: 500, height: 400)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Color Picker View
struct ColorPickerView: View {
    let text: String
    let onColorSelected: (NibColor) -> Void
    @State private var hoveredColor: String? = nil

    var body: some View {
        HStack(spacing: 20) {
            ForEach(NibColor.all, id: \.name) { color in
                Button(action: { onColorSelected(color) }) {
                    Circle()
                        .fill(Color(color.nsColor))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .scaleEffect(hoveredColor == color.name ? 1.15 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        hoveredColor = hovering ? color.name : nil
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - About View
struct AboutView: View {
    @State private var hoveredShortcut: Int? = nil

    var body: some View {
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

                    Text("Version 1.0.0")
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
                        keys: ["⌘", "⇧", "N"],
                        color: NibColor.pink,
                        isHovered: hoveredShortcut == 0
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredShortcut = hovering ? 0 : nil
                        }
                    }

                    ShortcutRow(
                        icon: "power",
                        description: "Toggle auto-capture",
                        keys: ["⌘", "⇧", "M"],
                        color: NibColor.pink,
                        isHovered: hoveredShortcut == 1
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredShortcut = hovering ? 1 : nil
                        }
                    }

                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)

                    ShortcutRow(
                        icon: "circle.fill",
                        description: "Yellow highlighter",
                        keys: ["⌘", "⌃", "1"],
                        color: NibColor.yellow,
                        isHovered: hoveredShortcut == 2
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredShortcut = hovering ? 2 : nil
                        }
                    }

                    ShortcutRow(
                        icon: "circle.fill",
                        description: "Orange highlighter",
                        keys: ["⌘", "⌃", "2"],
                        color: NibColor.orange,
                        isHovered: hoveredShortcut == 3
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredShortcut = hovering ? 3 : nil
                        }
                    }

                    ShortcutRow(
                        icon: "circle.fill",
                        description: "Pink highlighter",
                        keys: ["⌘", "⌃", "3"],
                        color: NibColor.pink,
                        isHovered: hoveredShortcut == 4
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredShortcut = hovering ? 4 : nil
                        }
                    }

                    ShortcutRow(
                        icon: "circle.fill",
                        description: "Purple highlighter",
                        keys: ["⌘", "⌃", "4"],
                        color: NibColor.purple,
                        isHovered: hoveredShortcut == 5
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredShortcut = hovering ? 5 : nil
                        }
                    }

                    ShortcutRow(
                        icon: "circle.fill",
                        description: "Green highlighter",
                        keys: ["⌘", "⌃", "5"],
                        color: NibColor.green,
                        isHovered: hoveredShortcut == 6
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredShortcut = hovering ? 6 : nil
                        }
                    }
                }
            }
            .padding(.bottom, 20)

            Divider()

            // Footer
            VStack(spacing: 12) {
                Text("Made with care for the bits worth keeping")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(NibColor.all, id: \.name) { color in
                        Circle()
                            .fill(Color(color.nsColor))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .frame(width: 480, height: 560)
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
                    description: "Organize clips with 5 vibrant colors. Switch anytime with ⌘⌃1-5"
                )

                FeatureRow(
                    icon: "keyboard",
                    color: NibColor.green,
                    title: "Keyboard Shortcuts",
                    description: "Toggle with ⌘⇧N • Auto-capture ⌘⇧M • Check About for more"
                )

                FeatureRow(
                    icon: "square.and.arrow.down",
                    color: NibColor.orange,
                    title: "Export Anywhere",
                    description: "Save your clips as Markdown or plain text whenever you need"
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
                withAnimation(.easeInOut(duration: 0.15)) {
                    gotItHovered = hovering
                }
            }
        }
        .frame(width: 460, height: 480)
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

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(color.nsColor))
                .frame(width: 10, height: 10)
                .shadow(color: Color(color.nsColor).opacity(0.5), radius: 4)

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
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
