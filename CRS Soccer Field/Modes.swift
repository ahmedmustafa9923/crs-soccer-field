//
//  Modes.swift
//  CRS Soccer Field
//
//  The screens around the matches: Training (three drills with stars),
//  Tournament (a knockout cup), Season (a six-team league with a table),
//  Prizes (trophy cabinet and badges), the Shop (kits and balls, paid for
//  with CRS coins earned in the game) and the reward card after each game.
//

import Foundation
import SwiftUI
import UIKit
import SpriteKit

enum Screen: String, Identifiable {
    case training, tournament, season, prizes, shop, settings
    var id: String { rawValue }
}

/// Shared look for the mode screens.
struct ModeScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) { content() }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
            }
            .background(LinearGradient(colors: [Color(red: 0.07, green: 0.28, blue: 0.15), Color(red: 0.17, green: 0.55, blue: 0.31)],
                                       startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 10) { content() }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(.white)
    }
}

struct BigButton: View {
    let title: String
    let icon: String
    var color = Color(Palette.amber)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .frame(maxWidth: 320, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .foregroundStyle(.black)
        .buttonBorderShape(.roundedRectangle(radius: 16))
    }
}

struct CoinBadge: View {
    let coins: Int
    var body: some View {
        Label("\(coins)", systemImage: "circle.hexagongrid.circle.fill")
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(red: 1, green: 0.8, blue: 0.25), in: Capsule())
            .accessibilityLabel("\(coins) CRS coins")
    }
}

func starString(_ n: Int) -> String {
    String(repeating: "★", count: max(0, min(n, 3))) + String(repeating: "☆", count: 3 - max(0, min(n, 3)))
}

// MARK: - Training

struct TrainingView: View {
    let progress: GameProgress
    let onStart: (Drill) -> Void
    let onPractice: () -> Void

    var body: some View {
        ModeScreen(title: "Training") {
            Card {
                Text("Earn up to 3 stars in each drill. Every star is worth 3 coins.")
                    .font(.system(.headline, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            ForEach(Drill.allCases) { drill in
                Card {
                    HStack(spacing: 14) {
                        Image(systemName: drill.icon).font(.system(size: 30, weight: .bold)).frame(width: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(drill.title).font(.system(size: 22, weight: .heavy, design: .rounded))
                            Text(drill.goalText).font(.system(.subheadline, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                            Text("Best: \(starString(progress.stars(drill)))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.3))
                        }
                        Spacer()
                        Button("Go") { onStart(drill) }
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .buttonStyle(.borderedProminent)
                            .tint(Color(Palette.amber))
                            .foregroundStyle(.black)
                    }
                }
            }
            Card {
                Text("Practice").font(.system(size: 22, weight: .heavy, design: .rounded))
                Text("Free shooting against a goalkeeper, with no clock. 1 coin a goal, up to 10.")
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                BigButton(title: "Practice", icon: "figure.soccer", action: onPractice)
            }
        }
    }
}

// MARK: - Tournament

struct TournamentView: View {
    let progress: GameProgress
    let onPlay: (Opponent, String) -> Void

    var body: some View {
        ModeScreen(title: "CRS Cup") {
            if let t = progress.data.tournament {
                Card {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color(red: 1, green: 0.8, blue: 0.25))
                    Text(t.finished ? (t.knockedOut ? "Knocked out" : "Cup winners!") : "Next: \(t.roundName)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    HStack(spacing: 10) {
                        ForEach(Array(t.opponents.enumerated()), id: \.offset) { i, name in
                            VStack(spacing: 4) {
                                Text(TournamentState.roundNames[i]).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.75))
                                Text(name).font(.system(size: 17, weight: .heavy, design: .rounded))
                                Image(systemName: icon(round: i, state: t))
                                    .foregroundStyle(stateColor(round: i, state: t))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Color(Opponent.named(name).color).opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if !t.finished {
                        BigButton(title: "Play the \(t.roundName.lowercased())", icon: "play.fill") {
                            onPlay(Opponent.named(t.opponents[t.round]), t.roundName)
                        }
                    } else {
                        BigButton(title: "New tournament", icon: "arrow.clockwise") { progress.startTournament() }
                    }
                }
                if !t.log.isEmpty {
                    Card {
                        Text("Results").font(.system(.headline, design: .rounded))
                        ForEach(Array(t.log.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(.subheadline, design: .rounded))
                        }
                    }
                }
            } else {
                Card {
                    Image(systemName: "trophy.fill").font(.system(size: 60)).foregroundStyle(Color(red: 1, green: 0.8, blue: 0.25))
                    Text("The CRS Cup").font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("Win three knockout games: quarter-final, semi-final and final. A draw goes to penalties. Win the cup for 50 coins and a trophy.")
                        .font(.system(.body, design: .rounded))
                        .multilineTextAlignment(.center)
                    BigButton(title: "Start the cup", icon: "flag.checkered") { progress.startTournament() }
                }
            }
        }
    }

    private func stateColor(round i: Int, state t: TournamentState) -> Color {
        if i < t.round { return Color.green }
        if t.knockedOut && i == t.round { return Color.red }
        return Color.white.opacity(0.6)
    }

    private func icon(round i: Int, state t: TournamentState) -> String {
        if i < t.round { return "checkmark.circle.fill" }
        if t.knockedOut && i == t.round { return "xmark.circle.fill" }
        return "circle"
    }
}

// MARK: - Season

struct SeasonView: View {
    let progress: GameProgress
    let teamName: String
    let onPlay: (Opponent, String) -> Void

    var body: some View {
        ModeScreen(title: "CRS League") {
            if let s = progress.data.season {
                Card {
                    if let next = s.nextOpponent {
                        Text("Matchday \(s.matchday + 1) of \(s.fixtures.count)")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                        Text("\(s.teams[0])  vs  \(next)").font(.system(.title3, design: .rounded).weight(.bold))
                        BigButton(title: "Play", icon: "play.fill") {
                            onPlay(Opponent.named(next), "Matchday \(s.matchday + 1)")
                        }
                    } else {
                        let place = (s.sortedTable.firstIndex { $0.name == s.teams[0] } ?? 5) + 1
                        Text(place == 1 ? "Champions!" : "Season over: you finished \(ordinal(place))")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                        BigButton(title: "New season", icon: "arrow.clockwise") { progress.startSeason(teamName: teamName) }
                    }
                }
                Card { table(s) }
                if !s.lastResults.isEmpty {
                    Card {
                        Text("Last matchday").font(.system(.headline, design: .rounded))
                        ForEach(Array(s.lastResults.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(.subheadline, design: .rounded))
                        }
                    }
                }
            } else {
                Card {
                    Image(systemName: "list.number").font(.system(size: 54))
                    Text("The CRS League").font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("Six teams, five matchdays. Win 3 points, draw 1. Top of the table wins the league for 60 coins and a trophy; 2nd and 3rd win medals.")
                        .font(.system(.body, design: .rounded))
                        .multilineTextAlignment(.center)
                    BigButton(title: "Start the season", icon: "flag.checkered") { progress.startSeason(teamName: teamName) }
                }
            }
        }
    }

    private func table(_ s: SeasonState) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("#").frame(width: 24)
                Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(["P", "W", "D", "L", "GD", "Pts"], id: \.self) { Text($0).frame(width: 34) }
            }
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .foregroundStyle(.white.opacity(0.75))
            ForEach(Array(s.sortedTable.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text("\(index + 1)").frame(width: 24)
                    Text(row.name).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                    Text("\(row.played)").frame(width: 34)
                    Text("\(row.won)").frame(width: 34)
                    Text("\(row.drawn)").frame(width: 34)
                    Text("\(row.lost)").frame(width: 34)
                    Text("\(row.goalDifference)").frame(width: 34)
                    Text("\(row.points)").frame(width: 34).fontWeight(.heavy)
                }
                .font(.system(.body, design: .rounded).weight(row.name == s.teams[0] ? .heavy : .medium))
                .padding(.vertical, 4)
                .background(row.name == s.teams[0] ? Color.white.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(n)th"
        }
    }
}

// MARK: - Prizes

struct PrizesView: View {
    let progress: GameProgress

    var body: some View {
        ModeScreen(title: "Prizes") {
            Card {
                HStack(spacing: 18) {
                    stat("Wins", progress.data.wins)
                    stat("Draws", progress.data.draws)
                    stat("Losses", progress.data.losses)
                    stat("Goals", progress.data.goals)
                }
                CoinBadge(coins: progress.coins)
            }
            Card {
                Text("Trophy cabinet").font(.system(size: 22, weight: .heavy, design: .rounded))
                if progress.data.trophies.isEmpty {
                    Text("No trophies yet. Win the CRS Cup, the CRS League, or 3 stars in every drill.")
                        .font(.system(.subheadline, design: .rounded))
                        .multilineTextAlignment(.center)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                        ForEach(progress.data.trophies.reversed()) { trophy in
                            VStack(spacing: 4) {
                                Image(systemName: trophyIcon(trophy.kind))
                                    .font(.system(size: 40))
                                    .foregroundStyle(trophyColor(trophy.kind))
                                Text(trophy.title).font(.system(.subheadline, design: .rounded).weight(.bold)).multilineTextAlignment(.center)
                                Text(trophy.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            Card {
                Text("Badges").font(.system(size: 22, weight: .heavy, design: .rounded))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(Badge.all) { badge in
                        let earned = progress.hasBadge(badge.id)
                        VStack(spacing: 4) {
                            Image(systemName: badge.icon)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(earned ? Color(red: 1, green: 0.8, blue: 0.25) : .white.opacity(0.3))
                            Text(badge.title).font(.system(.subheadline, design: .rounded).weight(.heavy))
                            Text(badge.detail).font(.caption).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
                        }
                        .opacity(earned ? 1 : 0.6)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(earned ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack {
            Text("\(value)").font(.system(size: 28, weight: .heavy, design: .rounded))
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.75))
        }
    }

    private func trophyIcon(_ kind: String) -> String {
        switch kind {
        case "cup", "league": "trophy.fill"
        case "training": "star.circle.fill"
        default: "medal.fill"
        }
    }

    private func trophyColor(_ kind: String) -> Color {
        switch kind {
        case "silver": Color(white: 0.8)
        case "bronze": Color(red: 0.8, green: 0.5, blue: 0.25)
        default: Color(red: 1, green: 0.8, blue: 0.25)
        }
    }
}

// MARK: - Shop

struct ShopView: View {
    let progress: GameProgress
    @State private var message: String?

    var body: some View {
        ModeScreen(title: "Shop") {
            Card {
                CoinBadge(coins: progress.coins)
                Text("Earn coins by playing matches, training and winning trophies.")
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                if let message { Text(message).font(.system(.headline, design: .rounded)).foregroundStyle(.yellow) }
            }
            Card {
                Text("Team kits").font(.system(size: 22, weight: .heavy, design: .rounded))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(KitColor.allCases) { kit in
                        item(title: kit.title, owned: progress.owns(kit), selected: progress.kit == kit, price: kit.price) {
                            Image(systemName: "tshirt.fill").font(.system(size: 40)).foregroundStyle(Color(kit.color))
                        } action: {
                            message = progress.buyOrWear(kit) ? "Now wearing \(kit.title)!" : "You need \(kit.price - progress.coins) more coins"
                        }
                    }
                }
            }
            Card {
                Text("Balls").font(.system(size: 22, weight: .heavy, design: .rounded))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(BallStyle.allCases) { style in
                        item(title: style.title, owned: progress.owns(style), selected: progress.ball == style, price: style.price) {
                            Image(uiImage: UIImage(cgImage: Art.ball(style).cgImage()))
                                .resizable()
                                .frame(width: 44, height: 44)
                        } action: {
                            message = progress.buyOrUse(style) ? "Now using the \(style.title.lowercased()) ball!" : "You need \(style.price - progress.coins) more coins"
                        }
                    }
                }
            }
        }
    }

    private func item<Picture: View>(title: String, owned: Bool, selected: Bool, price: Int,
                                     @ViewBuilder picture: () -> Picture, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                picture()
                Text(title).font(.system(.subheadline, design: .rounded).weight(.heavy))
                Text(selected ? "Using" : owned ? "Use" : "\(price) coins")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(selected ? .green : .white.opacity(0.8))
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(selected ? 0.18 : 0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.green : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

// MARK: - After a game

struct RewardSummary: Identifiable {
    let id = UUID()
    let result: MatchResult
    let reward: Reward
}

struct RewardView: View {
    let summary: RewardSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ModeScreen(title: "Well played!") {
            Card {
                if summary.result.mode == .match {
                    Text("\(summary.result.homeName) \(summary.result.home) – \(summary.result.away) \(summary.result.awayName)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                    if let star = summary.result.starPlayer { Text("⭐️ Star player: \(star)").font(.system(.headline, design: .rounded)) }
                } else if case .drill = summary.result.mode {
                    Text(starString(summary.result.drillStars)).font(.system(size: 44)).foregroundStyle(Color(red: 1, green: 0.82, blue: 0.3))
                }
                ForEach(Array(summary.reward.lines.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(.title3, design: .rounded).weight(.semibold))
                }
                Text("+\(summary.reward.coins) coins").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.yellow)
            }
            if let trophy = summary.reward.trophy {
                Card {
                    Image(systemName: "trophy.fill").font(.system(size: 54)).foregroundStyle(Color(red: 1, green: 0.8, blue: 0.25))
                    Text("New trophy: \(trophy.title)").font(.system(size: 22, weight: .heavy, design: .rounded))
                }
            }
            if !summary.reward.newBadges.isEmpty {
                Card {
                    Text("New badges").font(.system(.headline, design: .rounded))
                    ForEach(summary.reward.newBadges) { badge in
                        Label(badge.title, systemImage: badge.icon).font(.system(.title3, design: .rounded).weight(.bold))
                    }
                }
            }
            BigButton(title: "OK", icon: "checkmark") { dismiss() }
        }
    }
}
