import SwiftUI

@main
struct BeautifulDiaryApp: App {
    @StateObject private var store = BeautyDiaryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { url in
                    Task {
                        await store.handleSupabaseAuthCallback(url)
                    }
                }
        }
    }
}
