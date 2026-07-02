import SwiftUI
import XCleanupCore

struct MainWindowView: View {
    @Bindable var appState: AppState
    @State private var selection: SidebarItem? = .overview

    enum SidebarItem: Hashable {
        case overview
        case category(CategoryID)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Overview", systemImage: "gauge.with.dots.needle.50percent")
                    .tag(SidebarItem.overview)
                Section("Categories") {
                    ForEach(appState.states) { state in
                        HStack {
                            Label {
                                Text(state.category.title)
                            } icon: {
                                Image(systemName: state.category.systemImage)
                                    .foregroundStyle(state.id.tint)
                            }
                            Spacer()
                            if state.isBusy {
                                ProgressView().controlSize(.mini)
                            } else if let result = state.result, result.totalSize > 0 {
                                Text(result.totalSize, format: .byteCount(style: .file))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(SidebarItem.category(state.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            switch selection {
            case .category(let id):
                CategoryDetailView(appState: appState, categoryID: id)
            default:
                OverviewView(appState: appState, selection: $selection)
            }
        }
        .navigationTitle("XCleanup")
        .navigationSubtitle(
            Text(appState.totalCleanable, format: .byteCount(style: .file)) + Text(" cleanable")
        )
    }
}

// MARK: - Overview

struct OverviewView: View {
    @Bindable var appState: AppState
    @Binding var selection: MainWindowView.SidebarItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                categoryCards
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .toolbar {
            Button {
                appState.refreshAll()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .help("Rescan all categories")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(appState.totalCleanable, format: .byteCount(style: .file))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(appState.totalCleanable)))
                Text("cleanable")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.isScanning { ProgressView().controlSize(.small) }
            }
            StackedUsageBar(states: appState.states, total: appState.totalCleanable)
                .frame(height: 10)
            if let free = diskFreeBytes {
                Text("\(free, format: .byteCount(style: .file)) free on disk")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.snappy, value: appState.totalCleanable)
    }

    private var categoryCards: some View {
        VStack(spacing: 8) {
            ForEach(appState.states) { state in
                Button {
                    selection = .category(state.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: state.category.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 7).fill(state.id.tint.gradient))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(state.category.title).font(.body)
                            Text(subtitle(for: state))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if state.isBusy {
                            ProgressView().controlSize(.small)
                        } else if let result = state.result, result.totalSize > 0 {
                            Text(result.totalSize, format: .byteCount(style: .file))
                                .font(.body)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        } else if state.result != nil {
                            Label("Clean", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func subtitle(for state: AppState.CategoryState) -> String {
        guard let result = state.result else { return "Not scanned yet" }
        if result.items.isEmpty { return "Nothing to reclaim" }
        return "\(result.items.count) item\(result.items.count == 1 ? "" : "s")"
    }

    private var diskFreeBytes: Int64? {
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}

// MARK: - Category detail

struct CategoryDetailView: View {
    @Bindable var appState: AppState
    let categoryID: CategoryID
    @State private var tableSelection: Set<ScanItem.ID> = []
    @State private var pending: PendingAction?

    enum PendingAction: Identifiable {
        case delete([ScanItem])
        case erase(ScanItem)

        var id: String {
            switch self {
            case .delete(let items): "delete-\(items.count)-\(items.first?.id ?? "")"
            case .erase(let item): "erase-\(item.id)"
            }
        }

        var title: String {
            switch self {
            case .delete(let items):
                items.count == 1 ? "Delete “\(items[0].name)”?" : "Delete \(items.count) items?"
            case .erase(let item):
                "Erase all content of “\(item.name)”?"
            }
        }
    }

    private var state: AppState.CategoryState? { appState.state(for: categoryID) }
    private var items: [ScanItem] { state?.result?.items ?? [] }
    private var selectedItems: [ScanItem] { items.filter { tableSelection.contains($0.id) } }

    var body: some View {
        Table(items, selection: $tableSelection) {
            TableColumn("Name") { item in
                HStack(spacing: 6) {
                    Text(item.name)
                    if item.isStale { StaleBadge() }
                }
            }
            TableColumn("Location") { item in
                Text(item.detail ?? "—").foregroundStyle(.secondary)
            }
            TableColumn("Size") { item in
                Text(item.size, format: .byteCount(style: .file))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90, max: 120)
        }
        .contextMenu(forSelectionType: ScanItem.ID.self) { ids in
            let targets = items.filter { ids.contains($0.id) }
            if !targets.isEmpty {
                Button("Delete", role: .destructive) { pending = .delete(targets) }
                if categoryID == .simulators, targets.count == 1 {
                    Button("Erase Content") { pending = .erase(targets[0]) }
                }
            }
        }
        .overlay {
            if items.isEmpty, state?.isBusy != true {
                ContentUnavailableView(
                    "All Clean",
                    systemImage: "checkmark.seal",
                    description: Text("Nothing to reclaim here right now."))
            }
        }
        .navigationTitle(state?.category.title ?? "")
        .toolbar {
            if state?.isBusy == true {
                ProgressView().controlSize(.small)
            }
            Button {
                appState.refresh(categoryID)
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .help("Rescan this category")
            if categoryID == .simulators, items.contains(where: \.isStale) {
                Button("Delete Unavailable") {
                    pending = .delete(items.filter(\.isStale))
                }
            }
            Button("Delete Selected") {
                pending = .delete(selectedItems)
            }
            .disabled(selectedItems.isEmpty)
            Button("Clean All") {
                pending = .delete(items)
            }
            .disabled(items.isEmpty || state?.isBusy == true)
        }
        .safeAreaInset(edge: .bottom) { statusBar }
        .confirmationDialog(
            pending?.title ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { perform() }
            Button("Cancel", role: .cancel) { pending = nil }
        }
    }

    private var statusBar: some View {
        HStack {
            if !(state?.failures.isEmpty ?? true) {
                Label("\(state!.failures.count) failed", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(state!.failures.map { "\($0.itemName): \($0.message)" }.joined(separator: "\n"))
            }
            Spacer()
            Text(statusText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var statusText: String {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        let totalText = total.formatted(.byteCount(style: .file))
        var text = "\(items.count) item\(items.count == 1 ? "" : "s") · \(totalText)"
        if !selectedItems.isEmpty {
            let selectedSize = selectedItems.reduce(Int64(0)) { $0 + $1.size }
            text += " · \(selectedItems.count) selected (\(selectedSize.formatted(.byteCount(style: .file))))"
        }
        return text
    }

    private func perform() {
        guard let action = pending else { return }
        pending = nil
        switch action {
        case .delete(let targets):
            tableSelection.removeAll()
            appState.clean(categoryID, items: targets)
        case .erase(let item):
            appState.eraseSimulator(item)
        }
    }
}
