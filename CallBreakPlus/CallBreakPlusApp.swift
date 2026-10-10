import SwiftUI
import SwiftData
import OSLog

private let persistenceLog = Logger(subsystem: "edu.amitsapkota.callbreakplus", category: "persistence")

@main
struct CallBreakPlusApp: App {
    let modelContainer: ModelContainer
    let statsUnavailable: Bool
    @State private var proStore = ProStore()

    init() {
        // Never delete, move, or overwrite the on-disk store here: a corrupt store today
        // may be recoverable by a future fix or a restore, and this fallback must not
        // foreclose that.
        do {
            modelContainer = try StatsMigrationPlan.container()
            statsUnavailable = false
        } catch {
            persistenceLog.error("Persistent store unavailable, falling back to in-memory: \(error)")
            do {
                modelContainer = try StatsMigrationPlan.container(ModelConfiguration(isStoredInMemoryOnly: true))
                statsUnavailable = true
            } catch {
                // No disk, no in-memory store either — not a real-world device state.
                fatalError("Failed to create ModelContainer, including an in-memory fallback: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelContainer: modelContainer, statsUnavailable: statsUnavailable, proStore: proStore)
                .task { await proStore.start() }
                .environment(proStore)
        }
        .modelContainer(modelContainer)
    }
}
