import SwiftUI
import XCleanupCore

struct MenuPanelView: View {
    @Bindable var appState: AppState
    @State private var expanded: Set<CategoryID> = []
    @State private var pending: PendingAction?

    enum PendingAction: Identifiable {
        case cleanAll(CategoryID)
        case cleanItem(CategoryID, ScanItem)
        case eraseSimulator(ScanItem)
        case deleteUnavailable(items: [ScanItem])

        var id: String {
            switch self {
            case .cleanAll(let id): "all-\(id.rawValue)"
            case .cleanItem(_, let item): "item-\(item.id)"
            case .eraseSimulator(let item): "erase-\(item.id)"
            case .deleteUnavailable: "unavailable"
            }
        }

        var title: String {
            switch self {
            case .cleanAll(let id): "Delete everything in \(id.rawValue)?"
            case .cleanItem(_, let item): "Delete “\(item.name)”?"
            case .eraseSimulator(let item): "Erase all content of “\(item.name)”?"
            case .deleteUnavailable(let items): "Delete \(items.count) unavailable simulator(s)?"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.hasAccess {
                categoryList
            } else {
                onboarding
            }
            Divider()
            footer
        }
        .frame(width: 380)
        .onAppear {
            if appState.hasAccess { appState.refreshAll() }
        }
        .confirmationDialog(
            pending?.title ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { perform() }
            Button("Cancel", role: .cancel) { pending = nil }
        }
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Welcome to XCleanup", systemImage: "hammer.circle")
                .font(.headline)
            Text("macOS sandboxing means XCleanup can only see folders you grant it. Nothing is ever deleted without your confirmation.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Start with Xcode's caches — the dialog opens with the right folder already selected, so just press Grant Access.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Grant Access to Library/Developer…") {
                appState.bookmarks.promptForDeveloperAccess()
                if appState.hasAccess { appState.refreshAll() }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    private var categoryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(appState.states) { state in
                    categoryRow(state)
                    if state.id == .spmBuild, appState.bookmarks.projectRoots.isEmpty {
                        Text("Grant access to the folder where you keep your projects — everything under it is scanned automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                    if expanded.contains(state.id) {
                        itemRows(state)
                    }
                    if !state.failures.isEmpty {
                        failureRows(state)
                    }
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 460)
    }

    private func categoryRow(_ state: AppState.CategoryState) -> some View {
        HStack {
            Button {
                toggleExpanded(state.id)
            } label: {
                Image(systemName: expanded.contains(state.id) ? "chevron.down" : "chevron.right")
                    .frame(width: 12)
                Label(state.category.title, systemImage: state.category.systemImage)
                Spacer()
                if state.isBusy {
                    ProgressView().controlSize(.small)
                } else if let result = state.result, result.totalSize > 0 {
                    Text(result.totalSize, format: .byteCount(style: .file))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if state.id == .spmBuild, appState.bookmarks.projectRoots.isEmpty {
                Button("Add Folder…") {
                    appState.bookmarks.promptToAddProjectRoot()
                    appState.refresh(.spmBuild)
                }
                .controlSize(.small)
            } else if state.id == .simulators, let items = state.result?.items,
               items.contains(where: \.isStale) {
                Button("Delete Unavailable") {
                    pending = .deleteUnavailable(items: items.filter(\.isStale))
                }
                .controlSize(.small)
            } else {
                Button("Clean") {
                    pending = .cleanAll(state.id)
                }
                .controlSize(.small)
                .disabled(state.isBusy || (state.result?.items.isEmpty ?? true))
            }
        }
        .padding(.vertical, 3)
    }

    private func itemRows(_ state: AppState.CategoryState) -> some View {
        ForEach(state.result?.items ?? []) { item in
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(item.name).lineLimit(1)
                        if item.isStale {
                            Text("unavailable")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .background(.orange.opacity(0.25), in: Capsule())
                        }
                    }
                    if let detail = item.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(item.size, format: .byteCount(style: .file))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if state.id == .simulators {
                    Button("Erase") { pending = .eraseSimulator(item) }
                        .controlSize(.mini)
                }
                Button("Delete") { pending = .cleanItem(state.id, item) }
                    .controlSize(.mini)
            }
            .padding(.leading, 28)
            .padding(.vertical, 1)
        }
    }

    private func failureRows(_ state: AppState.CategoryState) -> some View {
        ForEach(state.failures, id: \.self) { failure in
            Label("\(failure.itemName): \(failure.message)", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.leading, 28)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                appState.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(!appState.hasAccess)
            if let last = appState.states.compactMap(\.result?.scannedAt).max() {
                Text("Scanned \(last, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
        }
        .buttonStyle(.borderless)
        .padding(8)
    }

    private func toggleExpanded(_ id: CategoryID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }

    private func perform() {
        guard let action = pending else { return }
        pending = nil
        switch action {
        case .cleanAll(let id):
            appState.clean(id, items: appState.state(for: id)?.result?.items ?? [])
        case .cleanItem(let id, let item):
            appState.clean(id, items: [item])
        case .eraseSimulator(let item):
            appState.eraseSimulator(item)
        case .deleteUnavailable(let items):
            appState.clean(.simulators, items: items)
        }
    }
}
