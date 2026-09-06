import Foundation

/// Platforms that are built but not offered. Yahoo needs an approved API application
/// before a sign-in can work; until then the code stays and the UI does not show it.
enum FeatureFlags {
    static let yahooEnabled = false
}
