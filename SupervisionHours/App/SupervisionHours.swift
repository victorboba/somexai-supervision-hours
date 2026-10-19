import SwiftUI
import SwiftData

@main
struct SupervisionHours: App {
    @State private var entitlements = EntitlementStore()
    private let container: ModelContainer

    init() {
        let schema = Schema([LicenseTrack.self, Supervisor.self, HoursEntry.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            let context = container.mainContext
            try? context.delete(model: HoursEntry.self)
            try? context.delete(model: Supervisor.self)
            try? context.delete(model: LicenseTrack.self)
            try? context.save()
            SessionTimer.clear()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
        }
        .modelContainer(container)
    }
}
