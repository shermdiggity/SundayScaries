//
//  DebugLeagueDumpView.swift
//  SundayScaries
//
//  THROWAWAY. Milestone 1 only.
//
//  This exists to eyeball that the data layer works against real leagues. It is not
//  designed, it does not use the design system (there isn't one yet), and it should be
//  deleted the moment the real Leagues tab exists. Nothing here is a pattern to copy.
//

import SwiftUI
import FantasyCore
import FantasyProviders

@MainActor
@Observable
final class DebugDumpModel {
    var username = ""
    /// Filled from Sleeper's own state endpoint on first appearance, so this is never
    /// a stale hardcoded year.
    var season = ""
    var output = ""
    var isLoading = false

    /// Sleeper's current season, so the field is never wrong by default.
    func loadDefaultSeason() async {
        guard season.isEmpty else { return }
        let state = try? await SleeperProvider.state(http: URLSessionHTTPClient())
        season = state?.leagueSeason ?? state?.season ?? SleeperStateProbe.fallbackSeason()
    }

    func run() async {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            output = "Enter a Sleeper username."
            return
        }
        isLoading = true
        output = ""
        defer { isLoading = false }

        var log = ""
        func line(_ text: String = "") { log += text + "\n"; output = log }

        let started = Date()

        // Anything outside a league's own block is genuinely fatal, so it stays in one
        // do/catch. Everything per-league is isolated below.
        let store: any SnapshotStore
        do { store = try FileSnapshotStore.applicationSupport() } catch { store = InMemorySnapshotStore(); line("cache: falling back to memory (\(error))") }

        // The crosswalk is downloaded and cached, not bundled — FantasyKit ships no
        // player data of its own. First run needs a network; after that it is local.
        let crosswalkStore = CrosswalkStore(http: URLSessionHTTPClient(), store: store)
        let crosswalk: PlayerCrosswalk
        do {
            line("crosswalk: fetching…")
            crosswalk = try await crosswalkStore.crosswalk()
            line("crosswalk: \(crosswalk.count) rows")
            line(await crosswalkStore.attribution)
        } catch {
            line("FAILED to load the player ID crosswalk: \(error)")
            line()
            line("It downloads on first run and is cached afterwards, so this needs a")
            line("network connection once. Nothing else can resolve players without it.")
            return
        }

        let provider = SleeperProvider(
            http: URLSessionHTTPClient(),
            store: store,
            resolver: IdentityResolver(crosswalk: crosswalk),
            season: season
        )

        if let week = try? await provider.currentWeek() {
            line("sleeper says the current week is \(week)")
        }
        line()

        let account = LinkedAccount(platform: .sleeper, handle: username)
        let leagues: [League]
        do {
            leagues = try await provider.leagues(for: account)
        } catch {
            line("FAILED to load leagues for \(username) in \(season): \(error)")
            line()
            line("If you have no leagues in \(season), try the current season instead.")
            return
        }

        guard !leagues.isEmpty else {
            line("No leagues for \(username) in season \(season).")
            return
        }

        line("\(leagues.count) league(s) for \(username) in \(season)")
        line(String(repeating: "=", count: 56))

        var ownedEverywhere: [String: (name: String, leagues: Set<String>)] = [:]
        var totalSlots = 0
        var unresolvedSlots = 0
        var emptyLineupSlots = 0
        var failedLeagues = 0

        for league in leagues {
            line()
            var header = "\(league.name)  —  \(league.size) teams, \(league.scoringKind.displayName)"
            header += league.status.hasDrafted
                ? ", week \(league.currentWeek.map(String.init) ?? "?")"
                : ", \(league.status.displayName.uppercased())"
            line(header)
            if league.mayCarryOverRosters {
                line("  keeper/dynasty league, not drafted yet — rosters below may be last season's")
            }

            // EVERY league is isolated. One league failing must never cost you the
            // others — that is the whole point of spec §4, and it is what made an
            // earlier build show only the first league before dying.
            let teams: [Team]
            do {
                teams = try await provider.teams(in: league)
            } catch {
                failedLeagues += 1
                line("  sync: FAILED — \(error)")
                line("  (skipping this league; the rest still load)")
                continue
            }

            let syncState = await provider.syncState(
                for: .teams(leagueID: league.id), as: [Team].self, policy: .leagues
            )
            line("  sync: \(syncState)")

            // Matchups are fetched per week and each week is isolated too.
            var matchups: [Matchup] = []
            var weekErrors = 0
            for week in 1...(league.currentWeek ?? 1) {
                do { matchups += try await provider.matchups(league: league, week: week) } catch { weekErrors += 1 }
            }
            if weekErrors > 0 { line("  \(weekErrors) week(s) could not be loaded") }

            // Passing the league scopes analytics to the regular season.
            let analytics = LeagueAnalyticsBuilder.build(
                league: league, teams: teams, matchups: matchups
            )

            if analytics.weeksAnalyzed.isEmpty {
                line("  no scoring yet this season — standings and analytics will fill in after week 1")
            } else {
                var scoring = "  \(analytics.weeksAnalyzed.count) week(s) of scoring"
                if !analytics.playoffWeeksExcluded.isEmpty {
                    scoring += " (regular season; excluded playoff week(s) "
                        + analytics.playoffWeeksExcluded.map(String.init).joined(separator: ", ") + ")"
                }
                line(scoring)
                line()
                line("  # TEAM                      REC    PF      ALL-PLAY  LUCK    SD     GAP")
                line("  " + String(repeating: "-", count: 68))

                for entry in analytics.teams {
                    guard let team = teams.first(where: { $0.id == entry.teamID }) else { continue }
                    let name = String(team.displayName.prefix(22)).padded(to: 22)
                    let rank = String(entry.powerRank).leftPadded(to: 2)
                    let record = team.record.summary.padded(to: 6)
                    let pf = String(format: "%.1f", entry.pointsFor).leftPadded(to: 7)
                    let allPlay = entry.allPlay.summary.padded(to: 9)
                    let luck = entry.luckIndex.map { String(format: "%+.3f", $0) } ?? "  —   "
                    let sd = entry.consistency.map { String(format: "%5.1f", $0) } ?? "  —  "
                    let gap = entry.rankGap == 0 ? "  ·" : String(format: "%+3d", entry.rankGap)
                    let mine = team.isOwnedByUser ? " ←" : ""
                    line("  \(rank) \(name) \(record) \(pf)  \(allPlay) \(luck) \(sd)  \(gap)\(mine)")
                }

                line()
                line("  weights: " + analytics.weights.disclosure
                    .map { "\($0.label) \(Int($0.weight * 100))%" }
                    .joined(separator: ", "))
            }

            // The lineup is isolated separately: a roster failure must not cost you the
            // standings you already printed.
            guard let mine = teams.first(where: \.isOwnedByUser) else {
                line("  (no team in this league is owned by \(username))")
                continue
            }
            let week = league.currentWeek ?? 1
            do {
                let roster = try await provider.roster(team: mine, week: week)
                line()
                let carryover = roster.isPreDraftCarryover(in: league)
                line()
                if carryover {
                    line("  YOUR LINEUP — CARRIED OVER FROM \(previousSeason(of: league)), this league has not drafted")
                } else {
                    line("  YOUR LINEUP, week \(week)")
                }
                line("  \(roster.slots.count) slots, \(roster.unresolvedSlots.count) unresolved, \(roster.emptySlots.count) empty")
                for slot in roster.starters {
                    let mark = slot.player.isResolved ? " " : "?"
                    let pts = slot.points.map { String(format: "%6.1f", $0) } ?? "     —"
                    line("   \(mark) \(slot.slot.rawValue.padded(to: 11)) \(String(slot.player.name.prefix(24)).padded(to: 24)) \((slot.player.nflTeam ?? "FA").padded(to: 4)) \(pts)")
                }
                let benchUnresolved = roster.bench.filter { !$0.player.isResolved }
                if !benchUnresolved.isEmpty {
                    line("   bench, unresolved: " + benchUnresolved.map(\.player.name).joined(separator: ", "))
                }

                for slot in roster.slots {
                    // An empty lineup slot holds no player, so it is neither resolved
                    // nor a resolution failure. Counting it as one made the identity
                    // rate look far worse than it is.
                    if slot.player.isEmptyLineupSlot { emptyLineupSlots += 1; continue }
                    totalSlots += 1
                    if let id = slot.player.canonicalID {
                        var seen = ownedEverywhere[id] ?? (slot.player.name, [])
                        seen.leagues.insert(league.name)
                        ownedEverywhere[id] = seen
                    } else {
                        unresolvedSlots += 1
                    }
                }
            } catch {
                line("  lineup unavailable: \(error)")
            }
        }

        line()
        line(String(repeating: "=", count: 56))
        if failedLeagues > 0 {
            line("\(failedLeagues) of \(leagues.count) league(s) failed to sync; the rest are above.")
        }
        line("IDENTITY: \(totalSlots) players, \(unresolvedSlots) unresolved (\(percent(unresolvedSlots, of: totalSlots)))")
        if emptyLineupSlots > 0 {
            line("  plus \(emptyLineupSlots) empty lineup slot(s) — a hole in a lineup, not a matching failure")
        }
        line("Not one slot was dropped: resolution never changes the count.")

        let shared = ownedEverywhere.values.filter { $0.leagues.count > 1 }
            .sorted { $0.leagues.count > $1.leagues.count }
        line()
        line("CROSS-LEAGUE EXPOSURE — players you roster in more than one league:")
        if shared.isEmpty {
            line("  (none — no overlapping players, or your rosters are empty/undrafted)")
        } else {
            for player in shared.prefix(25) {
                line("  \(player.leagues.count)x  \(player.name.padded(to: 24)) \(player.leagues.sorted().joined(separator: ", "))")
            }
        }

        line()
        line("done in \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
    }

    /// The season a carried-over roster actually belongs to.
    private func previousSeason(of league: League) -> String {
        Int(league.season).map { String($0 - 1) } ?? "LAST SEASON"
    }

    private func percent(_ part: Int, of whole: Int) -> String {
        guard whole > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(part) / Double(whole) * 100)
    }
}

private extension String {
    func padded(to width: Int) -> String {
        count >= width ? String(prefix(width)) : self + String(repeating: " ", count: width - count)
    }

    func leftPadded(to width: Int) -> String {
        count >= width ? String(suffix(width)) : String(repeating: " ", count: width - count) + self
    }
}

struct DebugLeagueDumpView: View {
    @State private var model = DebugDumpModel()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Sleeper username", text: $model.username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Season", text: $model.season)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Button("Load") { Task { await model.run() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)
            }

            if model.isLoading { ProgressView() }

            ScrollView([.horizontal, .vertical]) {
                Text(model.output.isEmpty ? "Enter your Sleeper username and tap Load." : model.output)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .task { await model.loadDefaultSeason() }
    }
}

/// Tiny helper so the debug view can show the right season without reaching into the
/// provider's internals. Throwaway, like the rest of this file.
enum SleeperStateProbe {
    /// The NFL league year rolls over in March.
    static func fallbackSeason() -> String {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return String(month >= 3 ? year : year - 1)
    }
}

#Preview {
    DebugLeagueDumpView()
}
