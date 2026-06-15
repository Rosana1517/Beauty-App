import SwiftUI

@main
struct BeautifulDiaryApp: App {
    @StateObject private var store = BeautyDiaryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
