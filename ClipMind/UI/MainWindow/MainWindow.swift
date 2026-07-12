import SwiftUI

struct MainWindow: View {
    @State private var selectedClip: ClipItem?
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            HistoryListView(selectedClip: $selectedClip)
            DetailPanel(clip: selectedClip)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {}, label: {
                    Image(systemName: "magnifyingglass")
                })
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: openSettings, label: {
                    Image(systemName: "gearshape")
                })
                .accessibilityIdentifier("settingsButton")
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    private func openSettings() {
        // 将在 T2.6 实现
    }
}
