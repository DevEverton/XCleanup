import SwiftUI
import XCleanupCore

extension CategoryID {
    var tint: Color {
        switch self {
        case .derivedData: .blue
        case .xcodeBuildMCP: .purple
        case .deviceSupport: .teal
        case .simulators: .orange
        case .spmBuild: .pink
        }
    }
}

/// Horizontal proportion bar of category sizes, tinted per category.
/// The visual anchor that teaches the palette the rows reuse.
struct StackedUsageBar: View {
    let states: [AppState.CategoryState]
    let total: Int64

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(states) { state in
                    let size = state.result?.totalSize ?? 0
                    if size > 0, total > 0 {
                        Rectangle()
                            .fill(state.id.tint.gradient)
                            .frame(width: max(2, geo.size.width * CGFloat(size) / CGFloat(total)))
                    }
                }
            }
        }
        .frame(height: 6)
        .background(.quaternary.opacity(0.5))
        .clipShape(Capsule())
        .animation(.snappy, value: total)
    }
}

struct StaleBadge: View {
    var body: some View {
        Text("unavailable")
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.orange.opacity(0.22), in: Capsule())
            .foregroundStyle(.orange)
    }
}
