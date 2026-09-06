import Foundation
import FantasyCore

/// One line of stats, the way a box score would put it, for a position.
///
/// Stat keys are Sleeper's, because the season feed is Sleeper's public one. Only what
/// matters for the position is shown, in the order a reader scans it; zeros are dropped
/// so an empty game reads as empty rather than as a row of noughts.
enum StatLine {
    static func summary(_ stats: [String: Double], position: Position) -> String {
        func n(_ key: String) -> Double { stats[key] ?? 0 }
        func f(_ value: Double) -> String {
            value.rounded() == value ? String(Int(value)) : value.formatted(.number.precision(.fractionLength(1)))
        }
        var parts: [String] = []

        switch position {
        case .qb:
            if n("pass_att") > 0 { parts.append("\(f(n("pass_cmp")))/\(f(n("pass_att")))") }
            if n("pass_yd") != 0 { parts.append("\(f(n("pass_yd"))) yds") }
            if n("pass_td") > 0 { parts.append("\(f(n("pass_td"))) TD") }
            if n("pass_int") > 0 { parts.append("\(f(n("pass_int"))) INT") }
            if n("rush_yd") != 0 { parts.append("\(f(n("rush_yd"))) rush") }
            if n("rush_td") > 0 { parts.append("\(f(n("rush_td"))) rush TD") }
        case .rb:
            if n("rush_att") > 0 { parts.append("\(f(n("rush_att"))) car") }
            if n("rush_yd") != 0 { parts.append("\(f(n("rush_yd"))) yds") }
            if n("rush_td") > 0 { parts.append("\(f(n("rush_td"))) TD") }
            if n("rec") > 0 { parts.append("\(f(n("rec"))) rec · \(f(n("rec_yd"))) yds") }
            if n("rec_td") > 0 { parts.append("\(f(n("rec_td"))) rec TD") }
        case .wr, .te:
            if n("rec") > 0 || n("rec_tgt") > 0 {
                parts.append(n("rec_tgt") > 0 ? "\(f(n("rec")))/\(f(n("rec_tgt"))) rec" : "\(f(n("rec"))) rec")
            }
            if n("rec_yd") != 0 { parts.append("\(f(n("rec_yd"))) yds") }
            if n("rec_td") > 0 { parts.append("\(f(n("rec_td"))) TD") }
            if n("rush_yd") != 0 { parts.append("\(f(n("rush_yd"))) rush") }
        case .k:
            if n("fga") > 0 || n("fgm") > 0 { parts.append("\(f(n("fgm")))/\(f(n("fga"))) FG") }
            if n("xpa") > 0 || n("xpm") > 0 { parts.append("\(f(n("xpm")))/\(f(n("xpa"))) XP") }
        case .def:
            if n("pts_allow") != 0 || n("gp") > 0 { parts.append("\(f(n("pts_allow"))) pts allowed") }
            if n("sack") > 0 { parts.append("\(f(n("sack"))) sacks") }
            if n("int") > 0 { parts.append("\(f(n("int"))) INT") }
            if n("ff") > 0 { parts.append("\(f(n("ff"))) FF") }
            if n("def_td") > 0 || n("def_st_td") > 0 { parts.append("\(f(n("def_td") + n("def_st_td"))) TD") }
        case .other:
            break
        }
        if parts.isEmpty, n("fum_lost") > 0 { parts.append("\(f(n("fum_lost"))) fum lost") }
        return parts.joined(separator: " · ")
    }
}
