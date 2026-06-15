import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        MainTabView()
            .background(AppTheme.background.ignoresSafeArea())
            .preferredColorScheme(.light)
            .environmentObject(store)
    }
}

#Preview {
    ContentView()
        .environmentObject(BeautyDiaryStore.preview)
}
