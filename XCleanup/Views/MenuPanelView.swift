import SwiftUI
import XCleanupCore

struct MenuPanelView: View {
    @Bindable var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var expanded: Set<CategoryID> = []
    @State private var pending: PendingAction?
    @State private var hoveredRow: String?

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
        VStack(spacing: 0) {
            header
            Divider()
            categoryList
            Divider()
            footer
        }
        // Fixed size: on macOS 14/15 the MenuBarExtra window gives a
        // ScrollView zero ideal height, collapsing the list entirely.
        .frame(width: 400, height: 500)
        .onAppear { appState.refreshAll() }
        .confirmationDialog(
            pending?.title ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { perform() }
            Button("Cancel", role: .cancel) { pending = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("XCLEANUP")
                    .font(.caption2.weight(.semibold))
                    .kerning(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                if appState.isScanning {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text("scanning…").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(appState.totalCleanable, format: .byteCount(style: .file))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(appState.totalCleanable)))
                Text("cleanable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            StackedUsageBar(states: appState.states, total: appState.totalCleanable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .animation(.snappy, value: appState.totalCleanable)
    }

    // MARK: - Categories

    private var categoryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(appState.states) { state in
                    categoryRow(state)
                    if expanded.contains(state.id) {
                        itemRows(state)
                    }
                    if !state.failures.isEmpty {
                        failureRows(state)
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func categoryRow(_ state: AppState.CategoryState) -> some View {
        let isExpanded = expanded.contains(state.id)
        let isHovered = hoveredRow == state.id.rawValue
        return HStack(spacing: 10) {
            Image(systemName: state.category.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(state.id.tint.gradient))

            VStack(alignment: .leading, spacing: 0) {
                Text(state.category.title)
                if let result = state.result, !result.items.isEmpty {
                    Text("\(result.items.count) item\(result.items.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isHovered, !state.isBusy, let items = state.result?.items, !items.isEmpty {
                if state.id == .simulators, items.contains(where: \.isStale) {
                    Button("Delete Unavailable") {
                        pending = .deleteUnavailable(items: items.filter(\.isStale))
                    }
                    .controlSize(.small)
                } else {
                    Button("Clean") { pending = .cleanAll(state.id) }
                        .controlSize(.small)
                }
            }

            if state.isBusy {
                ProgressView().controlSize(.small)
            } else if let result = state.result, result.totalSize > 0 {
                Text(result.totalSize, format: .byteCount(style: .file))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else if state.result != nil {
                Label("Clean", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Text("—").foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) {
                if isExpanded { expanded.remove(state.id) } else { expanded.insert(state.id) }
            }
        }
        .onHover { inside in
            hoveredRow = inside ? state.id.rawValue : (hoveredRow == state.id.rawValue ? nil : hoveredRow)
        }
        .contextMenu {
            Button("Rescan") { appState.refresh(state.id) }
            Button("Delete All…") { pending = .cleanAll(state.id) }
                .disabled(state.result?.items.isEmpty ?? true)
        }
        .animation(.snappy, value: hoveredRow)
    }

    private func itemRows(_ state: AppState.CategoryState) -> some View {
        ForEach(state.result?.items ?? []) { item in
            let isHovered = hoveredRow == item.id
            HStack(spacing: 6) {
                Circle()
                    .fill(state.id.tint.opacity(0.6))
                    .frame(width: 5, height: 5)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(item.name).font(.callout).lineLimit(1)
                        if item.isStale { StaleBadge() }
                    }
                    if let detail = item.detail {
                        Text(detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
                Spacer()
                if isHovered {
                    if state.id == .simulators {
                        Button("Erase") { pending = .eraseSimulator(item) }
                            .controlSize(.mini)
                            .help("Factory reset: keeps the simulator but wipes its apps, data, and settings")
                    }
                    Button("Delete") { pending = .cleanItem(state.id, item) }
                        .controlSize(.mini)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .help(state.id == .simulators
                            ? "Removes the simulator entirely from your Mac"
                            : "Deletes this item from disk")
                }
                Text(item.size, format: .byteCount(style: .file))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 40)
            .padding(.trailing, 10)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? AnyShapeStyle(.quaternary.opacity(0.4)) : AnyShapeStyle(.clear))
            )
            .onHover { inside in
                hoveredRow = inside ? item.id : (hoveredRow == item.id ? nil : hoveredRow)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func failureRows(_ state: AppState.CategoryState) -> some View {
        ForEach(state.failures, id: \.self) { failure in
            Label("\(failure.itemName): \(failure.message)", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.leading, 40)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 4) {
            Button {
                appState.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Rescan all categories")
            if let last = appState.states.compactMap(\.result?.scannedAt).max() {
                Text("Scanned \(last, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "macwindow")
            }
            .help("Open XCleanup window")
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit XCleanup")
        }
        .buttonStyle(.borderless)
        .padding(8)
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
