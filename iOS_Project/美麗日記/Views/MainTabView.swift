import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabRoute = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Image(systemName: TabRoute.home.systemImage)
                Text(TabRoute.home.rawValue)
            }
            .tag(TabRoute.home)

            NavigationStack {
                BeautyRootView()
            }
            .tabItem {
                Image(systemName: TabRoute.beauty.systemImage)
                Text(TabRoute.beauty.rawValue)
            }
            .tag(TabRoute.beauty)

            NavigationStack {
                BodyRootView()
            }
            .tabItem {
                Image(systemName: TabRoute.body.systemImage)
                Text(TabRoute.body.rawValue)
            }
            .tag(TabRoute.body)

            NavigationStack {
                GrowthRootView()
            }
            .tabItem {
                Image(systemName: TabRoute.growth.systemImage)
                Text(TabRoute.growth.rawValue)
            }
            .tag(TabRoute.growth)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Image(systemName: TabRoute.profile.systemImage)
                Text(TabRoute.profile.rawValue)
            }
            .tag(TabRoute.profile)
        }
        .tint(AppTheme.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(BeautyDiaryStore.preview)
}
