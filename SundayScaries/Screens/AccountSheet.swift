import SwiftUI
import FantasyCore

/// The only thing outside the weekly view and the league view: connecting accounts.
struct AccountSheet: View {
    @Bindable var model: WeeklyModel
    @Environment(\.dismiss) private var dismiss
    @State private var handle: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Sleeper username", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(save)
                } header: {
                    Text("Sleeper")
                } footer: {
                    Text("Sleeper is read-only and needs no password. Other platforms are coming.")
                }

                Section {
                    ForEach(Platform.allCases.filter { $0 != .sleeper }, id: \.self) { platform in
                        HStack {
                            Text(platform.displayName)
                                .foregroundStyle(SWColor.secondary)
                            Spacer()
                            Text("Not yet")
                                .foregroundStyle(SWColor.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                }
            }
            .onAppear { handle = model.handle }
        }
        .tint(SWColor.accent)
    }

    private func save() {
        let trimmed = handle.trimmingCharacters(in: .whitespaces)
        let changed = trimmed != model.handle
        model.handle = trimmed
        dismiss()
        if changed {
            Task { await model.load() }
        }
    }
}
