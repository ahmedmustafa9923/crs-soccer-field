//
//  Progress.swift
//  CRS Soccer Field
//
//  Everything the game remembers between plays, saved on the device: CRS
//  coins, trophies, badges, training stars, shop items, and the current
//  tournament and season. Coins are only earned by playing. There is no
//  real money anywhere in the game.
//

import Foundation
import Observation

// MARK: - Saved data

nonisolated struct TrophyRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    let kind: String      // "cup", "league", "silver", "bronze", "training"
    let title: String
    let date: Date
}

nonisolated struct TournamentState: Codable {
    /// Opponents for the quarter-final, semi-final and final.
    var opponents: [String]
    /// 0 = quarter-final … 3 = won.
    var round = 0
    var knockedOut = false
    var log: [String] = []

    static let roundNames = ["Quarter-final", "Semi-final", "Final"]
    var finished: Bool { knockedOut || round >= 3 }
    var roundName: String { round < 3 ? Self.roundNames[round] : "Champions" }
}

nonisolated struct TableRow: Codable, Identifiable {
    var name: String
    var played = 0, won = 0, drawn = 0, lost = 0, scored = 0, conceded = 0
    var id: String { name }
    var points: Int { won * 3 + drawn }
    var goalDifference: Int { scored - conceded }

    mutating func add(scored s: Int, conceded c: Int) {
        played += 1
        scored += s
        conceded += c
        if s > c { won += 1 } else if s == c { drawn += 1 } else { lost += 1 }
    }
}

nonisolated struct Pairing: Codable {
    let a: Int
    let b: Int
}

nonisolated struct SeasonState: Codable {
    /// Index 0 is the player's team.
    var teams: [String]
    var table: [TableRow]
    var fixtures: [[Pairing]]
    var matchday = 0
    var lastResults: [String] = []

    var finished: Bool { matchday >= fixtures.count }

    var sortedTable: [TableRow] {
        table.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            return $0.scored > $1.scored
        }
    }

    /// The opponent the player meets this matchday.
    var nextOpponent: String? {
        guard !finished else { return nil }
        guard let pair = fixtures[matchday].first(where: { $0.a == 0 || $0.b == 0 }) else { return nil }
        return teams[pair.a == 0 ? pair.b : pair.a]
    }
}

nonisolated struct SaveData: Codable {
    var coins = 0
    var wins = 0
    var draws = 0
    var losses = 0
    var goals = 0
    var trophies: [TrophyRecord] = []
    var badges: [String] = []
    var drillStars: [String: Int] = [:]
    var ownedKits: [String] = ["blue"]
    var kit = "blue"
    var ownedBalls: [String] = ["classic"]
    var ball = "classic"
    var tournament: TournamentState?
    var season: SeasonState?
}

// MARK: - Badges

struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String

    static let all: [Badge] = [
        Badge(id: "first-goal", title: "First goal", detail: "Score a goal in a match", icon: "soccerball"),
        Badge(id: "first-win", title: "First win", detail: "Win a match", icon: "hand.thumbsup.fill"),
        Badge(id: "hat-trick", title: "Hat-trick", detail: "Score 3 goals in one match", icon: "3.circle.fill"),
        Badge(id: "clean-sheet", title: "Clean sheet", detail: "Win without letting in a goal", icon: "shield.fill"),
        Badge(id: "big-win", title: "Big win", detail: "Win by 3 goals or more", icon: "flame.fill"),
        Badge(id: "ten-wins", title: "Ten wins", detail: "Win 10 matches", icon: "10.circle.fill"),
        Badge(id: "training-star", title: "Training star", detail: "Get 3 stars in every drill", icon: "star.fill"),
        Badge(id: "cup-winner", title: "Cup winner", detail: "Win a tournament", icon: "trophy.fill"),
        Badge(id: "champions", title: "Champions", detail: "Win a season", icon: "crown.fill"),
        Badge(id: "shopper", title: "New look", detail: "Buy something in the shop", icon: "bag.fill"),
    ]
}

/// Where a finished game came from, so the right things get updated.
enum PlayContext: Equatable {
    case quick, practice, training(Drill), tournament, season
}

/// What a finished game earned, for the result screen.
struct Reward {
    var coins = 0
    var lines: [String] = []
    var newBadges: [Badge] = []
    var trophy: TrophyRecord?
}

// MARK: - GameProgress

@Observable
final class GameProgress {
    private(set) var data: SaveData
    private let key = "crs-soccer-save-v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = saved
        } else {
            data = SaveData()
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) { UserDefaults.standard.set(raw, forKey: key) }
    }

    var coins: Int { data.coins }
    var kit: KitColor { KitColor(rawValue: data.kit) ?? .blue }
    var ball: BallStyle { BallStyle(rawValue: data.ball) ?? .classic }

    func hasBadge(_ id: String) -> Bool { data.badges.contains(id) }
    func stars(_ drill: Drill) -> Int { data.drillStars[drill.rawValue] ?? 0 }

    // MARK: Shop

    func owns(_ kit: KitColor) -> Bool { data.ownedKits.contains(kit.rawValue) }
    func owns(_ ball: BallStyle) -> Bool { data.ownedBalls.contains(ball.rawValue) }

    /// Buys if there are enough coins, then wears it. Returns false if not enough coins.
    @discardableResult
    func buyOrWear(_ kit: KitColor) -> Bool {
        if !owns(kit) {
            guard data.coins >= kit.price else { return false }
            data.coins -= kit.price
            data.ownedKits.append(kit.rawValue)
            awardQuietly("shopper")
        }
        data.kit = kit.rawValue
        save()
        return true
    }

    @discardableResult
    func buyOrUse(_ ball: BallStyle) -> Bool {
        if !owns(ball) {
            guard data.coins >= ball.price else { return false }
            data.coins -= ball.price
            data.ownedBalls.append(ball.rawValue)
            awardQuietly("shopper")
        }
        data.ball = ball.rawValue
        save()
        return true
    }

    // MARK: Tournament

    func startTournament() {
        let picks = Array(Opponent.all.shuffled().prefix(3)).sorted { $0.strength < $1.strength }
        data.tournament = TournamentState(opponents: picks.map(\.name))
        save()
    }

    func clearTournament() {
        data.tournament = nil
        save()
    }

    // MARK: Season

    func startSeason(teamName: String) {
        let rivals = Array(Opponent.all.shuffled().prefix(5)).map(\.name)
        let teams = [teamName] + rivals
        data.season = SeasonState(teams: teams, table: teams.map { TableRow(name: $0) }, fixtures: Self.roundRobin(teams.count))
        save()
    }

    func clearSeason() {
        data.season = nil
        save()
    }

    /// Every team plays every other once (the circle method).
    static func roundRobin(_ n: Int) -> [[Pairing]] {
        var ids = Array(0..<n)
        var rounds: [[Pairing]] = []
        for _ in 0..<(n - 1) {
            var round: [Pairing] = []
            for i in 0..<(n / 2) { round.append(Pairing(a: ids[i], b: ids[n - 1 - i])) }
            rounds.append(round)
            let last = ids.removeLast()
            ids.insert(last, at: 1)
        }
        return rounds
    }

    /// A simple, believable score between two made-up teams.
    static func simulate(_ a: String, _ b: String) -> (Int, Int) {
        let sa = Opponent.named(a).strength, sb = Opponent.named(b).strength
        func goals(_ s: Double) -> Int {
            var g = 0
            for _ in 0..<5 where Double.random(in: 0...1) < 0.12 + s * 0.3 { g += 1 }
            return g
        }
        return (goals(sa), goals(sb))
    }

    // MARK: Recording results

    func record(_ result: MatchResult, context: PlayContext) -> Reward {
        var reward = Reward()
        switch context {
        case .practice:
            let earned = min(result.drillScore, 10)
            reward.coins += earned
            reward.lines.append("\(result.drillScore) practice goal\(result.drillScore == 1 ? "" : "s")")
        case .training(let drill):
            let best = stars(drill)
            reward.coins += result.drillStars * 3
            reward.lines.append("\(drill.title): \(String(repeating: "★", count: result.drillStars))\(String(repeating: "☆", count: 3 - result.drillStars))")
            if result.drillStars > best {
                data.drillStars[drill.rawValue] = result.drillStars
                if best < 3 && result.drillStars == 3 { reward.lines.append("New best: 3 stars!") }
            }
            if Drill.allCases.allSatisfy({ stars($0) == 3 }) {
                if award("training-star", into: &reward) {
                    reward.trophy = addTrophy("training", "Training Star")
                }
            }
        case .quick, .tournament, .season:
            recordMatch(result, into: &reward)
            if context == .tournament { recordTournament(result, into: &reward) }
            if context == .season { recordSeason(result, into: &reward) }
        }
        data.coins += reward.coins
        save()
        return reward
    }

    private func recordMatch(_ r: MatchResult, into reward: inout Reward) {
        data.goals += r.home
        if r.home > r.away {
            data.wins += 1
            reward.coins += 10
            reward.lines.append("Win: +10 coins")
        } else if r.home == r.away {
            data.draws += 1
            reward.coins += 5
            reward.lines.append("Draw: +5 coins")
        } else {
            data.losses += 1
            reward.coins += 2
            reward.lines.append("Good try: +2 coins")
        }
        if r.home > 0 {
            reward.coins += r.home
            reward.lines.append("\(r.home) goal\(r.home == 1 ? "" : "s"): +\(r.home) coins")
            award("first-goal", into: &reward)
        }
        if r.home > r.away { award("first-win", into: &reward) }
        if r.home >= 3 { award("hat-trick", into: &reward) }
        if r.home > r.away && r.away == 0 { award("clean-sheet", into: &reward) }
        if r.home - r.away >= 3 { award("big-win", into: &reward) }
        if data.wins >= 10 { award("ten-wins", into: &reward) }
    }

    private func recordTournament(_ r: MatchResult, into reward: inout Reward) {
        guard var t = data.tournament, !t.finished else { return }
        let roundName = t.roundName
        var won = r.home > r.away
        if r.home == r.away {
            // Knockout games can't end level: a quick penalty shoot-out.
            won = Double.random(in: 0...1) < 0.6
            let mine = Int.random(in: 3...5)
            let theirs = won ? max(mine - Int.random(in: 1...2), 1) : mine + 1
            t.log.append("\(roundName): \(r.home) – \(r.away), \(won ? "won" : "lost") \(mine)–\(theirs) on penalties")
            reward.lines.append(won ? "Won on penalties \(mine)–\(theirs)!" : "Lost on penalties \(mine)–\(theirs)")
        } else {
            t.log.append("\(roundName): \(r.home) – \(r.away) against \(r.awayName)")
        }
        if won {
            t.round += 1
            if t.round >= 3 {
                reward.coins += 50
                reward.lines.append("Cup winners! +50 coins")
                reward.trophy = addTrophy("cup", "CRS Cup")
                award("cup-winner", into: &reward)
            } else {
                reward.lines.append("Through to the \(TournamentState.roundNames[t.round].lowercased())!")
            }
        } else {
            t.knockedOut = true
            if roundName == "Final" {
                reward.coins += 20
                reward.lines.append("Runners-up: +20 coins")
                reward.trophy = addTrophy("silver", "CRS Cup runners-up")
            } else {
                reward.lines.append("Knocked out in the \(roundName.lowercased())")
            }
        }
        data.tournament = t
    }

    private func recordSeason(_ r: MatchResult, into reward: inout Reward) {
        guard var s = data.season, !s.finished else { return }
        var results: [String] = []
        for pair in s.fixtures[s.matchday] {
            var ga = 0, gb = 0
            if pair.a == 0 {
                ga = r.home; gb = r.away
            } else if pair.b == 0 {
                ga = r.away; gb = r.home
            } else {
                let sim = Self.simulate(s.teams[pair.a], s.teams[pair.b])
                ga = sim.0; gb = sim.1
            }
            s.table[pair.a].add(scored: ga, conceded: gb)
            s.table[pair.b].add(scored: gb, conceded: ga)
            results.append("\(s.teams[pair.a]) \(ga) – \(gb) \(s.teams[pair.b])")
        }
        s.lastResults = results
        s.matchday += 1
        reward.lines.append("Matchday \(s.matchday) of \(s.fixtures.count) played")
        if s.finished {
            let place = (s.sortedTable.firstIndex { $0.name == s.teams[0] } ?? 5) + 1
            switch place {
            case 1:
                reward.coins += 60
                reward.lines.append("League champions! +60 coins")
                reward.trophy = addTrophy("league", "CRS League champions")
                award("champions", into: &reward)
            case 2:
                reward.coins += 25
                reward.lines.append("2nd place: +25 coins")
                reward.trophy = addTrophy("silver", "CRS League 2nd place")
            case 3:
                reward.coins += 15
                reward.lines.append("3rd place: +15 coins")
                reward.trophy = addTrophy("bronze", "CRS League 3rd place")
            default:
                reward.lines.append("Finished \(place)th. Next season!")
            }
        }
        data.season = s
    }

    private func addTrophy(_ kind: String, _ title: String) -> TrophyRecord {
        let trophy = TrophyRecord(kind: kind, title: title, date: .now)
        data.trophies.append(trophy)
        return trophy
    }

    /// Gives a badge once. Returns true the first time.
    @discardableResult
    private func award(_ id: String, into reward: inout Reward) -> Bool {
        guard !data.badges.contains(id), let badge = Badge.all.first(where: { $0.id == id }) else { return false }
        data.badges.append(id)
        reward.newBadges.append(badge)
        return true
    }

    private func awardQuietly(_ id: String) {
        var ignored = Reward()
        award(id, into: &ignored)
    }
}
