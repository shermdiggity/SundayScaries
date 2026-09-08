import Foundation
import FantasyCore

/// One line of stats, the way a box score would put it, for a position.
///
/// Stat keys are Sleeper's, because the season feed is Sleeper's public one. Only what
/// matters for the position is shown, in the order a reader scans it; zeros are dropped
/// so an empty game reads as empty rather than as a row of noughts.
enum StatLine {
    /// `compact` is the lineup row's form: half the width of the sheet's, so it drops
    /// the attempts, targets and carries and keeps what decided the points — yards,
    /// touchdowns, catches, turnovers.
    static func summary(_ stats: [String: Double], position: Position, compact: Bool = false) -> String {
        let line = Line(stats: stats, compact: compact)
        var parts: [String]
        switch position {
        case .qb:       parts = line.quarterback
        case .rb:       parts = line.runningBack
        case .wr, .te:  parts = line.receiver
        case .k:        parts = line.kicker
        case .def:      parts = line.defense
        case .other:    parts = []
        }
        if parts.isEmpty, line.n("fum_lost") > 0 { parts.append("\(line.f(line.n("fum_lost"))) fum lost") }
        return parts.joined(separator: " · ")
    }

    /// One position's reading of a stat line. Keys are Sleeper's; zeros are dropped.
    private struct Line {
        let stats: [String: Double]
        let compact: Bool

        func n(_ key: String) -> Double { stats[key] ?? 0 }
        func f(_ value: Double) -> String {
            value.rounded() == value ? String(Int(value)) : value.formatted(SWFormat.score)
        }

        var quarterback: [String] {
            var parts: [String] = []
            if !compact, n("pass_att") > 0 { parts.append("\(f(n("pass_cmp")))/\(f(n("pass_att")))") }
            if n("pass_yd") != 0 { parts.append("\(f(n("pass_yd"))) yds") }
            if n("pass_td") > 0 { parts.append("\(f(n("pass_td"))) TD") }
            if n("pass_int") > 0 { parts.append("\(f(n("pass_int"))) INT") }
            if n("rush_yd") != 0, !compact || n("rush_yd") >= 20 { parts.append("\(f(n("rush_yd"))) rush") }
            if n("rush_td") > 0 { parts.append("\(f(n("rush_td"))) rush TD") }
            return parts
        }

        var runningBack: [String] {
            var parts: [String] = []
            if !compact, n("rush_att") > 0 { parts.append("\(f(n("rush_att"))) car") }
            if n("rush_yd") != 0 { parts.append("\(f(n("rush_yd"))) yds") }
            if n("rush_td") > 0 { parts.append("\(f(n("rush_td"))) TD") }
            if n("rec") > 0 {
                parts.append(compact ? "\(f(n("rec"))) rec" : "\(f(n("rec"))) rec · \(f(n("rec_yd"))) yds")
            }
            if n("rec_td") > 0 { parts.append("\(f(n("rec_td"))) rec TD") }
            return parts
        }

        var receiver: [String] {
            var parts: [String] = []
            if n("rec") > 0 || n("rec_tgt") > 0 {
                let withTargets = !compact && n("rec_tgt") > 0
                parts.append(withTargets ? "\(f(n("rec")))/\(f(n("rec_tgt"))) rec" : "\(f(n("rec"))) rec")
            }
            if n("rec_yd") != 0 { parts.append("\(f(n("rec_yd"))) yds") }
            if n("rec_td") > 0 { parts.append("\(f(n("rec_td"))) TD") }
            if n("rush_yd") != 0, !compact || n("rush_yd") >= 20 { parts.append("\(f(n("rush_yd"))) rush") }
            return parts
        }

        var kicker: [String] {
            var parts: [String] = []
            if n("fga") > 0 || n("fgm") > 0 { parts.append("\(f(n("fgm")))/\(f(n("fga"))) FG") }
            if n("xpa") > 0 || n("xpm") > 0 { parts.append("\(f(n("xpm")))/\(f(n("xpa"))) XP") }
            return parts
        }

        var defense: [String] {
            var parts: [String] = []
            if n("pts_allow") != 0 || n("gp") > 0 {
                parts.append(compact ? "\(f(n("pts_allow"))) allowed" : "\(f(n("pts_allow"))) pts allowed")
            }
            if n("sack") > 0 { parts.append("\(f(n("sack"))) sacks") }
            if n("int") > 0 { parts.append("\(f(n("int"))) INT") }
            if n("ff") > 0 { parts.append("\(f(n("ff"))) FF") }
            if n("def_td") > 0 || n("def_st_td") > 0 { parts.append("\(f(n("def_td") + n("def_st_td"))) TD") }
            return parts
        }
    }
}

extension SlotKind {
    /// The platform key, as a label: "SUPER_FLEX" reads as "SUPER FLEX".
    var label: String { rawValue.replacingOccurrences(of: "_", with: " ") }
}
