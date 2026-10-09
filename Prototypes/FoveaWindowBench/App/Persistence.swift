import Foundation
import FoveaCore

/// The bench's state through FoveaCore's `PersistentStore`, the repo's storage convention:
/// UserDefaults for a normal launch, memory for snapshots, a throwaway suite for the smoke run.
struct BenchStore {
    let load: () -> BenchState?
    let save: (BenchState) -> Void

    static let key = "windowbench.state.v1"

    static func standard() -> BenchStore { make(UserDefaultsStore<BenchState>(key: key)) }

    static func memory() -> BenchStore { make(InMemoryStore<BenchState>()) }

    /// A suite the smoke run owns and empties, so its re-init check never touches real choices.
    static func smoke() -> BenchStore {
        let suite = "windowbench.smoke"
        UserDefaults().removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        return make(UserDefaultsStore<BenchState>(defaults: defaults, key: key))
    }

    private static func make(_ store: some PersistentStore<BenchState>) -> BenchStore {
        BenchStore(load: { store.load() },
                   save: { state in Task { try? await store.save(state, changed: key) } })
    }
}
