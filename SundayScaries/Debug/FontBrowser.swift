#if DEBUG
import SwiftUI

/// Flip through every typeface on the device, rendered as the app's own weekly view
/// actually sets it, and apply one live to see it in place.
///
/// A specimen sheet in isolation is not a decision. The two things that decide the
/// display face here are how it reads *over the sky* and whether its numerals hold a
/// column, so both are on every page rather than left to be imagined.
struct FontBrowser: View {
    @AppStorage(SWType.debugFaceKey) private var applied: String = ""
    @State private var kind: FontCatalog.Kind?
    @State private var index: Int = 0
    @State private var showingList = false
    @State private var corrected = true

    private var families: [FontCatalog.Family] {
        guard let kind else { return FontCatalog.all }
        return FontCatalog.all.filter { $0.kind == kind }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Judged in context: the display face's whole job is to sit on this sky.
                StaticSky(palette: Sky.palette(at: Date()))
                    .ignoresSafeArea()

                if families.isEmpty {
                    Text("No families in this group")
                        .font(SWType.body)
                        .foregroundStyle(SWColor.onSkySecondary)
                } else {
                    TabView(selection: $index) {
                        ForEach(Array(families.enumerated()), id: \.element.id) { position, family in
                            specimen(family)
                                .tag(position)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle(families.isEmpty ? "Fonts" : "\(index + 1) of \(families.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showingList) { familyList }
        }
        .tint(SWColor.accent)
        // Changing the filter can leave the index past the end of the shorter list.
        .onChange(of: kind) { _, _ in index = 0 }
    }

    // MARK: One specimen

    private func specimen(_ family: FontCatalog.Family) -> some View {
        let heroFace = FontCatalog.face(in: family.name, like: "X-Bold")
        let headerFace = FontCatalog.face(in: family.name, like: "X-SemiBold")
        let isApplied = applied == family.name

        return ScrollView {
            VStack(alignment: .leading, spacing: SWSpacing.xl) {
                VStack(alignment: .leading, spacing: SWSpacing.xs) {
                    Text(family.name)
                        .font(.custom(headerFace, size: 26))
                        .foregroundStyle(SWColor.onSky)
                    Text(family.isBundled
                        ? "\(family.kind.rawValue) · \(family.faces.count) faces · bundled"
                        : "\(family.kind.rawValue) · \(family.faces.count) faces")
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.onSkySecondary)
                }

                // The app's real copy, at the app's real sizes, in the app's real roles.
                VStack(alignment: .leading, spacing: SWSpacing.md) {
                    voice(Text("Every lineup is set"), heroFace, 46, .bold)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)

                    ForEach(["Riding on", "Up against", "The season so far"], id: \.self) { header in
                        voice(Text(header), headerFace, 23, .semibold)
                    }
                }

                coverage(heroFace)
                metrics(heroFace, size: 46)

                numerals(heroFace)
                faces(family)

                Button {
                    applied = isApplied ? "" : family.name
                } label: {
                    Text(isApplied ? "Applied — tap to clear"
                        : FontCatalog.hasLatin(heroFace) ? "Use on the weekly view"
                        : "Cannot be used — no Latin alphabet")
                        .font(SWType.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SWSpacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(isApplied ? SWColor.secondary : SWColor.accent)
                .disabled(!isApplied && !FontCatalog.hasLatin(heroFace))
            }
            .padding(SWSpacing.xl)
            .padding(.bottom, SWSpacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    /// Rendered exactly as the weekly view would, correction included — or raw, so the
    /// two can be compared.
    @ViewBuilder
    private func voice(_ text: Text, _ face: String, _ size: CGFloat, _ fallback: Font.Weight) -> some View {
        if corrected {
            text.swVoice(SWType.Face(name: face, size: size, fallback: fallback))
                .foregroundStyle(SWColor.onSky)
        } else {
            text.font(.custom(face, size: size)).foregroundStyle(SWColor.onSky)
        }
    }

    /// The first thing to know about a face, because everything below it is worthless
    /// if this is false: whether the specimen above is really this font.
    @ViewBuilder
    private func coverage(_ face: String) -> some View {
        if !FontCatalog.hasLatin(face) {
            Label(
                "No Latin alphabet — everything above is iOS's fallback face, not this font",
                systemImage: "exclamationmark.octagon.fill"
            )
            .font(SWType.caption)
            .foregroundStyle(SWColor.negative)
            .padding(SWSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: SWRadius.md).fill(SWColor.surface.opacity(0.55)))
        }
    }

    /// Why a face sits wrong, in numbers.
    ///
    /// A face cut for Latin puts its baseline about 78% down its line box and keeps that
    /// box a little over one em tall. A face carrying another script reserves room above
    /// and below for marks, which drags both figures away and makes Latin text float
    /// high in a box far taller than it needs.
    private func metrics(_ face: String, size: CGFloat) -> some View {
        Group {
            if let font = UIFont(name: face, size: size) {
                let fraction = font.ascender / font.lineHeight
                let ratio = font.lineHeight / size
                let native = abs(fraction - 0.78) < 0.02 && ratio < 1.35

                VStack(alignment: .leading, spacing: 2) {
                    Text(native
                        ? "Latin metrics — nothing to correct"
                        : "Non-Latin metrics — corrected above, toggle in the menu to compare")
                        .font(SWType.caption)
                        .foregroundStyle(native ? SWColor.accent : SWColor.onSkySecondary)
                    Text(String(format: "baseline %.0f%% of line box (Latin ≈ 78%%) · line box %.2f em (Latin ≈ 1.2)",
                                fraction * 100, ratio))
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.onSkySecondary)
                }
            }
        }
    }

    /// The objective test. Two scores of equal digit count, stacked: if the decimal
    /// points do not line up, the face has proportional figures and every score column
    /// in the app will shuffle as numbers update.
    private func numerals(_ face: String) -> some View {
        let tabular = FontCatalog.hasTabularFigures(face)
        return VStack(alignment: .leading, spacing: SWSpacing.sm) {
            Label(
                tabular ? "Tabular figures — columns hold" : "Proportional figures — columns will jitter",
                systemImage: tabular ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(SWType.caption)
            .foregroundStyle(tabular ? SWColor.accent : SWColor.negative)

            VStack(alignment: .leading, spacing: 0) {
                Text("188.06").font(.custom(face, size: 34).monospacedDigit())
                Text("127.48").font(.custom(face, size: 34).monospacedDigit())
                Text("110.11").font(.custom(face, size: 34).monospacedDigit())
            }
            .foregroundStyle(SWColor.onSky)
        }
        .padding(SWSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SWRadius.md)
                .fill(SWColor.surface.opacity(0.55))
        )
    }

    private func faces(_ family: FontCatalog.Family) -> some View {
        VStack(alignment: .leading, spacing: SWSpacing.sm) {
            ForEach(family.faces, id: \.self) { face in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gibbs starts against you")
                        .font(.custom(face, size: 19))
                        .foregroundStyle(SWColor.onSky)
                    Text(face)
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.onSkySecondary)
                }
            }
        }
    }

    // MARK: Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("List", systemImage: "list.bullet") { showingList = true }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Group", selection: $kind) {
                    Text("All").tag(FontCatalog.Kind?.none)
                    ForEach(FontCatalog.Kind.allCases) { Text($0.rawValue).tag(FontCatalog.Kind?.some($0)) }
                }
                Divider()
                Toggle("Correct vertical metrics", isOn: $corrected)
                if !applied.isEmpty {
                    Divider()
                    Button("Clear override (\(applied))", role: .destructive) { applied = "" }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease")
            }
        }
    }

    /// Eighty families is too many to swipe through looking for one. The list jumps.
    private var familyList: some View {
        NavigationStack {
            List(Array(families.enumerated()), id: \.element.id) { position, family in
                Button {
                    index = position
                    showingList = false
                } label: {
                    HStack {
                        Text(family.name)
                            .font(.custom(FontCatalog.face(in: family.name, like: "X-SemiBold"), size: 19))
                            .foregroundStyle(SWColor.primary)
                        Spacer()
                        if applied == family.name {
                            Image(systemName: "checkmark").foregroundStyle(SWColor.accent)
                        }
                    }
                }
            }
            .navigationTitle("Families")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview { FontBrowser() }
#endif
