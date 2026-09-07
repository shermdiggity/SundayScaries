import SwiftUI
import FantasyProviders

/// The way in by hand, for when ESPN's login does not cooperate.
///
/// Deliberately kept: this app reads ESPN through endpoints ESPN does not document or
/// support, and the login flow it depends on can change without warning. When it does,
/// this is the difference between a broken feature and an inconvenience — and it is the
/// same pair of values the web view captures, so nothing downstream knows the difference.
struct ESPNManualCredentialsView: View {
    var onCapture: (ESPNCredentials) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var swid = ""
    @State private var s2 = ""

    /// Pasted from a browser, so a trailing newline is the common case, and a newline
    /// inside a cookie header is a sign-in that fails for no visible reason.
    private var trimmedSWID: String { swid.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedS2: String { s2.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isComplete: Bool { !trimmedSWID.isEmpty && !trimmedS2.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("SWID", text: $swid, axis: .vertical)
                    TextField("espn_s2", text: $s2, axis: .vertical)
                } header: {
                    Text("Cookies")
                } footer: {
                    Text("Braces on the SWID are optional — they're added if missing.")
                }

                Section("Where to find them") {
                    VStack(alignment: .leading, spacing: SWSpacing.sm) {
                        step(1, "On a computer, sign in at fantasy.espn.com.")
                        step(2, "Open the browser's developer tools.")
                        step(3, "Find Application (or Storage) → Cookies → espn.com.")
                        step(4, "Copy the values of SWID and espn_s2.")
                    }
                    .padding(.vertical, SWSpacing.xs)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Paste cookies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onCapture(ESPNCredentials(swid: trimmedSWID, espnS2: trimmedS2))
                    }
                    .disabled(!isComplete)
                }
            }
        }
        .tint(SWColor.accent)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SWSpacing.sm) {
            Text("\(number).")
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .monospacedDigit()
            Text(text)
                .font(SWType.caption)
                .foregroundStyle(SWColor.secondary)
        }
    }
}
