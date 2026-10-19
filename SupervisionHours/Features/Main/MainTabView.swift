import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            LogView()
                .tabItem { Label("Log", systemImage: "calendar") }
            ReportView()
                .tabItem { Label("Report", systemImage: "signature") }
        }
    }
}
