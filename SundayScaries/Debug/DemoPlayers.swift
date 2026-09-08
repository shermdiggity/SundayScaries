#if DEBUG
import Foundation
import FantasyCore

/// The demo's players: real names, Sleeper's ids for their headshots, their 2026 teams
/// and injury flags as Sleeper's player list had them in September 2026.
extension DemoData {
    struct Player {
        let name: String
        let sleeperID: String
        let team: String
        let position: Position
        let projection: Double
        var injury: InjuryStatus = .healthy

        var ref: PlayerRef {
            PlayerRef(
                identity: .canonical(id: DemoData.slug(name), source: .gsis),
                name: name, nflTeam: team, position: position, injuryStatus: injury,
                headshotURL: URL(string: "https://sleepercdn.com/content/nfl/players/\(sleeperID).jpg")
            )
        }
    }

    private static func player(
        _ name: String, _ id: String, _ team: String, _ position: Position, _ projection: Double,
        _ injury: InjuryStatus = .healthy
    ) -> Player {
        Player(name: name, sleeperID: id, team: team, position: position, projection: projection, injury: injury)
    }

    static let pool: [String: Player] = Dictionary(uniqueKeysWithValues: [
        player("Josh Allen", "4984", "BUF", .qb, 23.4),
        player("Jayden Daniels", "11566", "WAS", .qb, 21.8),
        player("Joe Burrow", "6770", "CIN", .qb, 20.9),
        player("Jalen Hurts", "6904", "PHI", .qb, 21.2),
        player("Lamar Jackson", "4881", "BAL", .qb, 24.1),
        player("Patrick Mahomes", "4046", "KC", .qb, 19.6, .questionable),
        player("Jared Goff", "3163", "DET", .qb, 18.2),
        player("Bo Nix", "11563", "DEN", .qb, 18.9),
        player("Drake Maye", "11564", "NE", .qb, 18.4),
        player("Baker Mayfield", "4892", "TB", .qb, 19.1),
        player("Bijan Robinson", "9509", "ATL", .rb, 19.3),
        player("Jahmyr Gibbs", "9221", "DET", .rb, 18.6),
        player("Saquon Barkley", "4866", "PHI", .rb, 18.1),
        player("Derrick Henry", "3198", "BAL", .rb, 16.4),
        player("Ashton Jeanty", "12527", "LV", .rb, 15.2, .questionable),
        player("De'Von Achane", "9226", "MIA", .rb, 15.8),
        player("Christian McCaffrey", "4034", "SF", .rb, 17.7, .questionable),
        player("Josh Jacobs", "5850", "GB", .rb, 14.9),
        player("Bucky Irving", "11584", "TB", .rb, 14.6),
        player("Chase Brown", "9224", "CIN", .rb, 13.8),
        player("Kyren Williams", "8150", "LAR", .rb, 14.4),
        player("James Cook", "8138", "BUF", .rb, 14.7),
        player("Omarion Hampton", "12507", "LAC", .rb, 13.9),
        player("Breece Hall", "8155", "NYJ", .rb, 13.1, .questionable),
        player("Jonathan Taylor", "6813", "IND", .rb, 15.1),
        player("Chuba Hubbard", "7594", "CAR", .rb, 12.2, .questionable),
        player("TreVeyon Henderson", "12529", "NE", .rb, 11.8),
        player("Ja'Marr Chase", "7564", "CIN", .wr, 19.8, .questionable),
        player("Justin Jefferson", "6794", "MIN", .wr, 18.9),
        player("CeeDee Lamb", "6786", "DAL", .wr, 17.4),
        player("Puka Nacua", "9493", "LAR", .wr, 17.1),
        player("Amon-Ra St. Brown", "7547", "DET", .wr, 17.6),
        player("Malik Nabers", "11632", "NYG", .wr, 16.2, .questionable),
        player("Nico Collins", "7569", "HOU", .wr, 15.9),
        player("Brian Thomas Jr.", "11631", "JAX", .wr, 15.3),
        player("Drake London", "8112", "ATL", .wr, 15.0),
        player("A.J. Brown", "5859", "NE", .wr, 15.6),
        player("Tee Higgins", "6801", "CIN", .wr, 14.2),
        player("Ladd McConkey", "11635", "LAC", .wr, 14.8),
        player("Garrett Wilson", "8146", "NYJ", .wr, 14.1),
        player("Jaxon Smith-Njigba", "9488", "SEA", .wr, 16.7),
        player("Marvin Harrison Jr.", "11628", "ARI", .wr, 14.0),
        player("Davante Adams", "2133", "LAR", .wr, 13.6),
        player("DK Metcalf", "5846", "PIT", .wr, 13.3),
        player("Rome Odunze", "11620", "CHI", .wr, 12.9),
        player("Jaylen Waddle", "7526", "DEN", .wr, 13.4),
        player("Tetairoa McMillan", "12526", "CAR", .wr, 13.0),
        player("Terry McLaurin", "5927", "WAS", .wr, 13.7),
        player("Courtland Sutton", "5045", "DEN", .wr, 12.6),
        player("Zay Flowers", "9997", "BAL", .wr, 13.2),
        player("George Pickens", "8137", "DAL", .wr, 12.8),
        player("Jameson Williams", "8148", "DET", .wr, 12.4),
        player("Rashee Rice", "10229", "KC", .wr, 13.9),
        player("Brock Bowers", "11604", "LV", .te, 14.3),
        player("Trey McBride", "8130", "ARI", .te, 13.1),
        player("George Kittle", "4217", "SF", .te, 12.2, .questionable),
        player("Sam LaPorta", "10859", "DET", .te, 10.4),
        player("Travis Kelce", "1466", "KC", .te, 10.1),
        player("T.J. Hockenson", "5844", "MIN", .te, 9.8),
        player("Mark Andrews", "5012", "BAL", .te, 9.2),
        player("David Njoku", "4033", "LAC", .te, 8.9),
        player("Tucker Kraft", "9484", "GB", .te, 9.6),
        player("Jake Ferguson", "8110", "DAL", .te, 8.4),
        player("Jake Bates", "11539", "DET", .k, 8.9),
        player("Brandon Aubrey", "11533", "DAL", .k, 9.4),
        player("Cameron Dicker", "8259", "LAC", .k, 8.6),
        player("Chris Boswell", "1945", "PIT", .k, 8.7),
        player("Harrison Butker", "4227", "KC", .k, 8.2),
        player("Ka'imi Fairbairn", "3451", "HOU", .k, 8.4),
        player("Tyler Bass", "7042", "BUF", .k, 8.5),
    ].map { ($0.name, $0) })

    private static let teamNames: [String: String] = [
        "PIT": "Pittsburgh Steelers", "DEN": "Denver Broncos", "PHI": "Philadelphia Eagles",
        "BAL": "Baltimore Ravens", "SF": "San Francisco 49ers", "DET": "Detroit Lions",
        "MIN": "Minnesota Vikings", "BUF": "Buffalo Bills", "HOU": "Houston Texans",
        "KC": "Kansas City Chiefs", "SEA": "Seattle Seahawks", "GB": "Green Bay Packers",
    ]

    static func defense(_ team: String) -> PlayerRef {
        PlayerRef(
            identity: .canonical(id: "DEF-\(team)", source: .teamDefense),
            name: teamNames[team] ?? team, nflTeam: team, position: .def,
            headshotURL: URL(string: "https://sleepercdn.com/images/team_logos/nfl/\(team.lowercased()).png")
        )
    }

    /// A player by name, or a defense by "DEF-XXX".
    static func ref(_ key: String) -> PlayerRef {
        if key.hasPrefix("DEF-") { return defense(String(key.dropFirst(4))) }
        guard let player = pool[key] else { preconditionFailure("demo: no player named \(key)") }
        return player.ref
    }

    static func projection(_ player: PlayerRef) -> Double {
        if player.position == .def { return 8.0 }
        return pool[player.name]?.projection ?? 10
    }

    /// Everyone not in the two featured lineups, so the rest of a league has faces.
    static func fillerPool(excluding used: Set<String>) -> [PlayerRef] {
        pool.values
            .filter { !used.contains($0.name) }
            .sorted { $0.name < $1.name }
            .map(\.ref)
    }
}
#endif
