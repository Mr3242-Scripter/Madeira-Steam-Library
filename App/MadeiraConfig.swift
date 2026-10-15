/// Minimal compatibility surface for the imported sign-in model.
/// This app does not read Madeira's Documents/madeira.cfg.
enum MadeiraConfig {
    static func get(_ key: String) -> String? { nil }
}
