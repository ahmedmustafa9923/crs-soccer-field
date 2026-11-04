//
//  SoccerApp.swift
//  CRS Soccer Field
//
//  App entry, the main menu (line-ups, cup, modes, coins) and the match
//  screen with pause. Works offline: no accounts, ads, chat, tracking or
//  real money. Coins are only earned by playing.
//

import Foundation
import SwiftUI
import SpriteKit
import UIKit

@main
struct CRSSoccerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

/// A game that's running: its settings and where it was started from.
struct RunningGame: Identifiable {
    let id = UUID()
    let settings: MatchSettings
    let context: PlayContext
}

struct RootView: View {
    @State private var settings = MatchSettings()
    @State private var progress = GameProgress()
    @State private var running: RunningGame?
    @State private var summary: RewardSummary?
    @State private var lastResult: MatchResult?
    @AppStorage("homeName2") private var savedHome = "Argentina"
    @AppStorage("awayName2") private var savedAway = "Portugal"
    @AppStorage("homePlayers2") private var savedHomePlayers = ""
    @AppStorage("awayPlayers2") private var savedAwayPlayers = ""

    var body: some View {
        Group {
            if let game = running {
                MatchView(settings: game.settings, onFinish: { finish($0, context: game.context) }, onQuit: { running = nil })
                    .id(game.id)
            } else {
                MenuView(settings: $settings, progress: progress, lastResult: lastResult, launch: launch)
                    .sheet(item: $summary) { RewardView(summary: $0) }
            }
        }
        .onAppear {
            settings.homeName = savedHome
            settings.awayName = savedAway
            settings.homePlayers = MatchSettings.split(savedHomePlayers, fallback: Rosters.home.map(\.name))
            settings.awayPlayers = MatchSettings.split(savedAwayPlayers, fallback: Rosters.away.map(\.name))
        }
    }

    /// Starts a game. `opponent` and `stage` come from the cup and the league.
    private func launch(_ context: PlayContext, _ opponent: Opponent?, _ stage: String?) {
        savedHome = settings.homeName
        savedAway = settings.awayName
        savedHomePlayers = MatchSettings.joined(settings.homePlayers)
        savedAwayPlayers = MatchSettings.joined(settings.awayPlayers)

        var game = settings
        game.homeColor = progress.kit.color
        game.ball = progress.ball
        game.stage = stage
        switch context {
        case .quick: game.mode = .match
        case .practice: game.mode = .practice
        case .training(let drill): game.mode = .drill(drill)
        case .tournament, .season: game.mode = .match
        }
        if let opponent {
            game.awayName = opponent.name
            game.awayColor = opponent.color
            game.level = opponent.level(atLeast: settings.level)
        }
        running = RunningGame(settings: game, context: context)
    }

    private func finish(_ result: MatchResult, context: PlayContext) {
        let reward = progress.record(result, context: context)
        if result.mode == .match { lastResult = result }
        running = nil
        summary = RewardSummary(result: result, reward: reward)
    }
}

// MARK: - Menu

struct MenuView: View {
    @Binding var settings: MatchSettings
    let progress: GameProgress
    let lastResult: MatchResult?
    let launch: (PlayContext, Opponent?, String?) -> Void
    @State private var screen: Screen?

    private let pitch = LinearGradient(colors: [Color(red: 0.07, green: 0.28, blue: 0.15), Color(red: 0.17, green: 0.55, blue: 0.31)],
                                       startPoint: .top, endPoint: .bottom)
    private let gold = Color(red: 1, green: 0.8, blue: 0.25)

    var body: some View {
        ZStack {
            pitch.ignoresSafeArea()
            HStack(alignment: .center, spacing: 18) {
                LineupCard(team: settings.homeName, color: Color(progress.kit.color), players: Rosters.home, names: settings.homePlayers)
                centre.frame(maxWidth: .infinity)
                LineupCard(team: settings.awayName, color: Color(Palette.away), players: Rosters.away, names: settings.awayPlayers)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .sheet(item: $screen) { which in
            switch which {
            case .settings: SettingsSheet(settings: $settings)
            case .training:
                TrainingView(progress: progress,
                             onStart: { drill in screen = nil; launch(.training(drill), nil, nil) },
                             onPractice: { screen = nil; launch(.practice, nil, nil) })
            case .tournament:
                TournamentView(progress: progress) { opponent, stage in screen = nil; launch(.tournament, opponent, stage) }
            case .season:
                SeasonView(progress: progress, teamName: settings.homeName) { opponent, stage in screen = nil; launch(.season, opponent, stage) }
            case .prizes: PrizesView(progress: progress)
            case .shop: ShopView(progress: progress)
            }
        }
    }

    private var centre: some View {
        VStack(spacing: 8) {
            Text("CRS Soccer Field")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 12) {
                CoinBadge(coins: progress.coins)
                Text("W \(progress.data.wins) · D \(progress.data.draws) · L \(progress.data.losses)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Button { screen = .settings } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                }
                .accessibilityLabel("Teams and settings")
            }

            HStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [gold, Color(red: 0.85, green: 0.55, blue: 0.1)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: gold.opacity(0.6), radius: 12)
                Button { launch(.quick, nil, nil) } label: {
                    Label("Play!", systemImage: "soccerball")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .frame(width: 200, height: 54)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(Palette.amber))
                .foregroundStyle(.black)
                .buttonBorderShape(.roundedRectangle(radius: 18))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                modeButton("Practice", "figure.soccer") { launch(.practice, nil, nil) }
                modeButton("Training", "figure.run") { screen = .training }
                modeButton("Tournament", "trophy") { screen = .tournament }
                modeButton("Season", "list.number") { screen = .season }
                modeButton("Prizes", "medal.fill") { screen = .prizes }
                modeButton("Shop", "bag.fill") { screen = .shop }
            }
            .frame(maxWidth: 460)

            Text("Officials: referee \(Rosters.officials[0].name), assistants \(Rosters.officials[1].name) and \(Rosters.officials[2].name), fourth official \(Rosters.officials[3].name)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let r = lastResult {
                Text("Last match: \(r.homeName) \(r.home) – \(r.away) \(r.awayName)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func modeButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(.white)
                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }
}

/// One team's line-up: name, kit colour and the five players.
struct LineupCard: View {
    let team: String
    let color: Color
    let players: [RosterEntry]
    let names: [String]

    var body: some View {
        VStack(spacing: 8) {
            Text(team)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
            ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                VStack(spacing: 0) {
                    Text("\(player.number)  \(index < names.count ? names[index] : player.name)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(player.position)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .multilineTextAlignment(.center)
        .padding(12)
        .frame(width: 190)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Team names, match length and level.
struct SettingsSheet: View {
    @Binding var settings: MatchSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    nameField("Your team", text: $settings.homeName)
                    nameField("Other team", text: $settings.awayName)
                }
                Section {
                    playerFields(Rosters.home, names: $settings.homePlayers)
                } header: {
                    Text("\(settings.homeName) players")
                } footer: {
                    Text("Type your favourite players. Names are saved on this device.")
                }
                Section("\(settings.awayName) players") {
                    playerFields(Rosters.away, names: $settings.awayPlayers)
                }
                Section("Each half") {
                    Picker("Each half", selection: $settings.minutesPerHalf) {
                        Text("2 min").tag(2.0)
                        Text("3 min").tag(3.0)
                        Text("5 min").tag(5.0)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Level") {
                    Picker("Level", selection: $settings.level) {
                        ForEach(Level.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("How to play") {
                    Text("Drag your left thumb to run. Tap KICK to shoot, or PASS to pass to a friend. Without the ball, DASH runs fast to win it back, and SWITCH picks another player.")
                        .font(.callout)
                }
            }
            .navigationTitle("Teams and settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func playerFields(_ roster: [RosterEntry], names: Binding<[String]>) -> some View {
        ForEach(Array(roster.enumerated()), id: \.offset) { index, entry in
            HStack(spacing: 12) {
                Text("\(entry.number)")
                    .font(.system(.body, design: .rounded).weight(.heavy))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 0) {
                    TextField(entry.position, text: Binding(
                        get: { index < names.wrappedValue.count ? names.wrappedValue[index] : "" },
                        set: { newValue in
                            guard index < names.wrappedValue.count else { return }
                            names.wrappedValue[index] = String(newValue.prefix(16))
                        }))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Text(entry.position).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func nameField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(14)) }))
            .font(.system(.body, design: .rounded).weight(.semibold))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
    }
}

// MARK: - Match

struct MatchView: View {
    let onFinish: (MatchResult) -> Void
    let onQuit: () -> Void
    @State private var scene: GameScene
    @State private var paused = false
    @State private var ready = false
    private let isPractice: Bool

    init(settings: MatchSettings, onFinish: @escaping (MatchResult) -> Void, onQuit: @escaping () -> Void) {
        self.onFinish = onFinish
        self.onQuit = onQuit
        self.isPractice = settings.mode == .practice
        _scene = State(initialValue: GameScene(settings: settings))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if ready {
                SpriteView(scene: scene, isPaused: paused, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
            } else {
                LoadingView()
            }

            Button {
                paused = true
                scene.isPaused = true
            } label: {
                Image(systemName: "pause.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .padding(.top, 14)
            .padding(.trailing, 24)
            .accessibilityLabel("Pause")

            if paused {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("Paused").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Button {
                            paused = false
                            scene.isPaused = false
                        } label: {
                            Label("Keep playing", systemImage: "play.fill")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .frame(width: 260, height: 54)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(Palette.amber))
                        .foregroundStyle(.black)
                        if isPractice {
                            Button("End practice") {
                                paused = false
                                scene.isPaused = false
                                scene.endPractice()
                            }
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                        }
                        Button("Back to menu", role: .destructive) { onQuit() }
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .onAppear {
            scene.onFinish = { result in onFinish(result) }
        }
        .task {
            // Let the loading screen draw first, then build the stadium.
            try? await Task.sleep(for: .milliseconds(120))
            ready = true
        }
    }
}

/// Shown for the moment it takes to set up the stadium.
struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.28, blue: 0.15), Color(red: 0.17, green: 0.55, blue: 0.31)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "soccerball")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.rotate, options: .repeating)
                Text("Getting the stadium ready…")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                ProgressView().tint(.white)
            }
        }
    }
}
