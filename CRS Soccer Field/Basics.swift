//
//  Basics.swift
//  CRS Soccer Field
//
//  Small shared pieces: vector maths, match settings, colours and the
//  textures the game draws with (made in code, so there are no image files).
//

import Foundation
import SpriteKit
import UIKit

// MARK: - Vector maths

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }

    var length: CGFloat { hypot(x, y) }

    var normalized: CGPoint {
        let l = length
        return l > 0.0001 ? CGPoint(x: x / l, y: y / l) : .zero
    }

    func distance(to p: CGPoint) -> CGFloat { hypot(x - p.x, y - p.y) }

    func dot(_ p: CGPoint) -> CGFloat { x * p.x + y * p.y }
}

func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

/// Distance from point p to the segment a–b.
func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let ab = b - a
    let lengthSquared = ab.dot(ab)
    guard lengthSquared > 0 else { return p.distance(to: a) }
    let t = clamp((p - a).dot(ab) / lengthSquared, 0, 1)
    return p.distance(to: a + ab * t)
}

// MARK: - Match settings

enum Side: Int {
    case home = 0, away = 1
    var other: Side { self == .home ? .away : .home }
}

enum Role { case keeper, defender, midfielder, forward }

enum Level: String, CaseIterable, Identifiable {
    case rookie, pro, star

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rookie: "Rookie"
        case .pro: "Pro"
        case .star: "Star"
        }
    }

    /// How fast the other team runs.
    var aiSpeed: CGFloat {
        switch self {
        case .rookie: 160
        case .pro: 192
        case .star: 218
        }
    }

    /// Chance the other team wins the ball when it gets close.
    var tackleChance: CGFloat {
        switch self {
        case .rookie: 0.16
        case .pro: 0.28
        case .star: 0.4
        }
    }

    /// How far their shots can miss by.
    var shotError: CGFloat {
        switch self {
        case .rookie: 75
        case .pro: 42
        case .star: 22
        }
    }

    /// How close to goal they get before shooting.
    var shootRange: CGFloat {
        switch self {
        case .rookie: 250
        case .pro: 320
        case .star: 380
        }
    }

    /// How quickly their goalkeeper moves.
    var keeperSpeed: CGFloat {
        switch self {
        case .rookie: 0.7
        case .pro: 0.9
        case .star: 1.05
        }
    }
}

/// What kind of game the scene runs.
enum MatchMode: Equatable {
    case match
    case practice
    case drill(Drill)
}

enum Drill: String, CaseIterable, Codable, Identifiable {
    case shooting, dribbling, passing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shooting: "Shooting"
        case .dribbling: "Dribbling"
        case .passing: "Passing"
        }
    }

    var icon: String {
        switch self {
        case .shooting: "scope"
        case .dribbling: "figure.run"
        case .passing: "arrow.triangle.swap"
        }
    }

    var goalText: String {
        switch self {
        case .shooting: "Score as many goals as you can in 45 seconds"
        case .dribbling: "Dribble through all 6 gates as fast as you can"
        case .passing: "Pass to your friends in the circles: 8 passes in 45 seconds"
        }
    }

    var seconds: TimeInterval { self == .dribbling ? 60 : 45 }

    func stars(score: Int, time: TimeInterval) -> Int {
        switch self {
        case .shooting: score >= 5 ? 3 : score >= 3 ? 2 : score >= 1 ? 1 : 0
        case .passing: score >= 8 ? 3 : score >= 5 ? 2 : score >= 2 ? 1 : 0
        case .dribbling: score < 6 ? 0 : time < 25 ? 3 : time < 40 ? 2 : 1
        }
    }
}

/// Shirt colours the home team can wear (bought in the shop).
enum KitColor: String, CaseIterable, Codable, Identifiable {
    case blue, green, purple, black, pink, gold

    var id: String { rawValue }
    var title: String { self == .blue ? "Sky blue" : rawValue.capitalized }
    var price: Int {
        switch self {
        case .blue: 0
        case .green, .purple: 30
        case .black, .pink: 40
        case .gold: 80
        }
    }

    var color: UIColor {
        switch self {
        case .blue: Palette.home
        case .green: UIColor(red: 0.13, green: 0.68, blue: 0.35, alpha: 1)
        case .purple: UIColor(red: 0.52, green: 0.3, blue: 0.9, alpha: 1)
        case .black: UIColor(white: 0.12, alpha: 1)
        case .pink: UIColor(red: 0.96, green: 0.38, blue: 0.68, alpha: 1)
        case .gold: UIColor(red: 0.9, green: 0.7, blue: 0.15, alpha: 1)
        }
    }
}

/// Ball designs (bought in the shop).
enum BallStyle: String, CaseIterable, Codable, Identifiable {
    case classic, star, gold, rainbow

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var price: Int {
        switch self {
        case .classic: 0
        case .star: 40
        case .gold: 50
        case .rainbow: 60
        }
    }
}

/// The other teams in tournaments and seasons. All made up.
struct Opponent: Hashable {
    let name: String
    let color: UIColor
    /// 0 to 1: how good they are, used for their level and simulated results.
    let strength: Double

    static let all: [Opponent] = [
        Opponent(name: "Portugal", color: Palette.away, strength: 0.6),
        Opponent(name: "Comets", color: UIColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 1), strength: 0.45),
        Opponent(name: "Tigers", color: UIColor(red: 0.98, green: 0.6, blue: 0.1, alpha: 1), strength: 0.55),
        Opponent(name: "Sharks", color: UIColor(red: 0.1, green: 0.6, blue: 0.75, alpha: 1), strength: 0.5),
        Opponent(name: "Dragons", color: UIColor(red: 0.8, green: 0.15, blue: 0.2, alpha: 1), strength: 0.7),
        Opponent(name: "Eagles", color: UIColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 1), strength: 0.6),
        Opponent(name: "Wolves", color: UIColor(white: 0.45, alpha: 1), strength: 0.65),
        Opponent(name: "Lions", color: UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1), strength: 0.8),
    ]

    static func named(_ name: String) -> Opponent {
        all.first { $0.name == name } ?? all[0]
    }

    /// The level their players play at, never below what the child picked.
    func level(atLeast chosen: Level) -> Level {
        let own: Level = strength < 0.5 ? .rookie : strength < 0.7 ? .pro : .star
        let order = Level.allCases
        let a = order.firstIndex(of: own) ?? 0
        let b = order.firstIndex(of: chosen) ?? 0
        return order[max(a, b)]
    }
}

struct MatchSettings {
    var homeName = "Argentina"
    var awayName = "Portugal"
    var minutesPerHalf: Double = 2
    var level: Level = .rookie
    var mode: MatchMode = .match
    var homeColor: UIColor = Palette.home
    var awayColor: UIColor = Palette.away
    var ball: BallStyle = .classic
    /// Shown in the ceremonies, e.g. "Semi-final" or "Matchday 3".
    var stage: String? = nil
    /// Names in squad order: keeper, two defenders, midfielder, forward. Kids can type their favourites.
    var homePlayers: [String] = Rosters.home.map(\.name)
    var awayPlayers: [String] = Rosters.away.map(\.name)

    /// Saved as one line, names separated by "|".
    static func joined(_ names: [String]) -> String { names.joined(separator: "|") }

    static func split(_ line: String, fallback: [String]) -> [String] {
        let names = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0) }
        guard names.count == fallback.count else { return fallback }
        return zip(names, fallback).map { $0.trimmingCharacters(in: .whitespaces).isEmpty ? $1 : $0 }
    }
}

struct MatchResult {
    var homeName: String
    var awayName: String
    var home: Int
    var away: Int
    var starPlayer: String?
    var starGoals: Int
    var mode: MatchMode = .match
    /// Training: the drill score and stars. Practice: goals scored.
    var drillScore = 0
    var drillStars = 0
    var drillTime: TimeInterval = 0
}

// MARK: - Line-ups and officials

struct RosterEntry: Identifiable {
    let number: Int
    let name: String
    let position: String
    var id: Int { number }
}

enum Rosters {
    // Argentina (home) and Portugal (away). Real names are fine for play at home;
    // an App Store release would need licences for player names.
    static let home: [RosterEntry] = [
        RosterEntry(number: 23, name: "E. Martínez", position: "Goalkeeper"),
        RosterEntry(number: 13, name: "Romero", position: "Defender"),
        RosterEntry(number: 25, name: "L. Martínez", position: "Defender"),
        RosterEntry(number: 24, name: "Enzo", position: "Midfielder"),
        RosterEntry(number: 10, name: "Messi", position: "Forward"),
    ]
    static let away: [RosterEntry] = [
        RosterEntry(number: 1, name: "Diogo Costa", position: "Goalkeeper"),
        RosterEntry(number: 4, name: "Rúben Dias", position: "Defender"),
        RosterEntry(number: 19, name: "Nuno Mendes", position: "Defender"),
        RosterEntry(number: 8, name: "Bruno F.", position: "Midfielder"),
        RosterEntry(number: 7, name: "Ronaldo", position: "Forward"),
    ]

    static let homeStaff = (manager: "Scaloni", mentor: "Aimar")
    static let awayStaff = (manager: "Jorge Jesus", mentor: "João de Deus")

    static let officials: [(role: String, name: String)] = [
        ("Referee", "Rosa"),
        ("Assistant referee", "Omar"),
        ("Assistant referee", "Jin"),
        ("Fourth official", "Ellie"),
    ]
}

// MARK: - Colours

enum Palette {
    static let home = UIColor(red: 0.42, green: 0.71, blue: 0.93, alpha: 1)  // Argentina sky blue
    static let homeKeeper = UIColor(red: 0.10, green: 0.74, blue: 0.62, alpha: 1)
    static let away = UIColor(red: 0.80, green: 0.08, blue: 0.16, alpha: 1)  // Portugal red
    static let awayKeeper = UIColor(red: 0.62, green: 0.32, blue: 0.86, alpha: 1)
    static let grassLight = UIColor(red: 0.27, green: 0.66, blue: 0.33, alpha: 1)
    static let grassDark = UIColor(red: 0.23, green: 0.60, blue: 0.29, alpha: 1)
    static let stands = UIColor(red: 0.17, green: 0.19, blue: 0.24, alpha: 1)
    static let amber = UIColor(red: 0.96, green: 0.69, blue: 0.24, alpha: 1)
    static let party: [UIColor] = [
        UIColor(red: 1, green: 0.84, blue: 0.2, alpha: 1), UIColor(red: 0.3, green: 0.8, blue: 1, alpha: 1),
        UIColor(red: 1, green: 0.4, blue: 0.6, alpha: 1), UIColor(red: 0.5, green: 1, blue: 0.5, alpha: 1),
        UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1), UIColor(red: 0.75, green: 0.55, blue: 1, alpha: 1),
    ]
}

// MARK: - Textures

enum Art {
    static func circle(diameter d: CGFloat) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: CGSize(width: d, height: d)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
        }
        return SKTexture(image: image)
    }

    static let dot: SKTexture = circle(diameter: 16)
    static let spark: SKTexture = circle(diameter: 10)

    static let confetti: SKTexture = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 5)).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 10, height: 5))
        }
        return SKTexture(image: image)
    }()

    static func ball(_ style: BallStyle) -> SKTexture {
        if style == .classic { return ball }
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            drawBall(style, in: ctx.cgContext, diameter: 64)
        }
        return SKTexture(image: image)
    }

    /// The shop balls: gold, rainbow stripes, or white with a blue star.
    private static func drawBall(_ style: BallStyle, in c: CGContext, diameter d: CGFloat) {
        let rect = CGRect(x: 2, y: 2, width: d - 4, height: d - 4)
        c.saveGState()
        c.addEllipse(in: rect)
        c.clip()
        if style == .gold {
            c.setFillColor(UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1).cgColor)
            c.fill(rect)
        } else if style == .rainbow {
            let colors: [UIColor] = Palette.party
            let band: CGFloat = rect.height / CGFloat(colors.count)
            for i in 0..<colors.count {
                c.setFillColor(colors[i].cgColor)
                let y: CGFloat = rect.minY + band * CGFloat(i)
                c.fill(CGRect(x: rect.minX, y: y, width: rect.width, height: band + 1))
            }
        } else {
            c.setFillColor(UIColor.white.cgColor)
            c.fill(rect)
        }
        c.restoreGState()

        let isStar = style == .star
        let mark: UIColor = isStar ? UIColor(red: 0.2, green: 0.4, blue: 0.95, alpha: 1) : UIColor(white: 0.12, alpha: 1)
        c.setFillColor(mark.cgColor)
        let centre = CGPoint(x: d / 2, y: d / 2)
        let points: Int = isStar ? 10 : 5
        let step: Double = 360.0 / Double(points)
        for i in 0..<points {
            let degrees: Double = -90.0 + step * Double(i)
            let angle: Double = degrees * Double.pi / 180.0
            let radius: CGFloat = isStar ? (i % 2 == 0 ? 16 : 7) : 11
            let x: CGFloat = centre.x + radius * CGFloat(cos(angle))
            let y: CGFloat = centre.y + radius * CGFloat(sin(angle))
            if i == 0 { c.move(to: CGPoint(x: x, y: y)) } else { c.addLine(to: CGPoint(x: x, y: y)) }
        }
        c.closePath()
        c.fillPath()

        c.setStrokeColor(UIColor(white: 0.12, alpha: 1).cgColor)
        c.setLineWidth(3)
        c.strokeEllipse(in: rect)
    }

    static let ball: SKTexture = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
            drawBall(.classic, in: ctx.cgContext, diameter: 64)
        }
        return SKTexture(image: image)
    }()
}

// MARK: - Rolling ball and grass

extension Art {
    /// Eight frames of the ball rolling to the right: the panels sit on a
    /// sphere and turn with it, with a highlight and shadow for a round look.
    private static var ballCache: [BallStyle: [SKTexture]] = [:]
    private static var grassCache: [String: SKTexture] = [:]

    static func ballFrames(_ style: BallStyle) -> [SKTexture] {
        if let hit = ballCache[style] { return hit }
        let made = drawBallFrames(style)
        ballCache[style] = made
        return made
    }

    private static func drawBallFrames(_ style: BallStyle) -> [SKTexture] {
        (0..<8).map { (frame: Int) -> SKTexture in
            let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
                drawRollingBall(style, phase: Double(frame) / 8.0 * 2.0 * Double.pi * 0.4, in: ctx.cgContext)
            }
            return SKTexture(image: image)
        }
    }

    /// Panel centres on the ball: (latitude, longitude) in degrees, like a real football.
    private static let panels: [(Double, Double)] = [
        (0, 0), (0, 72), (0, 144), (0, 216), (0, 288),
        (55, 36), (55, 108), (55, 180), (55, 252), (55, 324),
        (-55, 36), (-55, 108), (-55, 180), (-55, 252), (-55, 324),
        (90, 0), (-90, 0),
    ]

    private static func drawRollingBall(_ style: BallStyle, phase: Double, in c: CGContext) {
        let rect = CGRect(x: 2, y: 2, width: 60, height: 60)
        let centre = CGPoint(x: 32, y: 32)
        let radius: CGFloat = 30
        c.saveGState()
        c.addEllipse(in: rect)
        c.clip()

        // Base colour
        switch style {
        case .gold:
            c.setFillColor(UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1).cgColor)
            c.fill(rect)
        case .rainbow:
            let colors: [UIColor] = Palette.party
            let band: CGFloat = rect.height / CGFloat(colors.count)
            for i in 0..<colors.count {
                c.setFillColor(colors[i].cgColor)
                c.fill(CGRect(x: rect.minX, y: rect.minY + band * CGFloat(i), width: rect.width, height: band + 1))
            }
        case .classic, .star:
            c.setFillColor(UIColor.white.cgColor)
            c.fill(rect)
        }

        // Panels that face the viewer, squashed as they turn away
        let panelColor: UIColor
        switch style {
        case .classic: panelColor = UIColor(white: 0.12, alpha: 1)
        case .star: panelColor = UIColor(red: 0.2, green: 0.4, blue: 0.95, alpha: 1)
        case .gold: panelColor = UIColor(red: 0.55, green: 0.38, blue: 0.05, alpha: 1)
        case .rainbow: panelColor = UIColor.white
        }
        c.setFillColor(panelColor.cgColor)
        for (latDegrees, lonDegrees) in panels {
            let lat: Double = latDegrees * Double.pi / 180.0
            let lon: Double = lonDegrees * Double.pi / 180.0 + phase
            let depth: Double = cos(lat) * cos(lon)
            if depth <= 0.05 { continue }
            let x: Double = cos(lat) * sin(lon)
            let y: Double = sin(lat)
            let size: CGFloat = CGFloat(7.5 * (0.45 + 0.55 * depth))
            let squash: CGFloat = CGFloat(max(0.35, cos(lon)))
            let px: CGFloat = centre.x + radius * CGFloat(x)
            let py: CGFloat = centre.y - radius * CGFloat(y)
            c.fillEllipse(in: CGRect(x: px - size * squash, y: py - size, width: 2 * size * squash, height: 2 * size))
        }

        // Shading: a soft highlight top-left and a shadow bottom-right
        let space = CGColorSpaceCreateDeviceRGB()
        let shine: [CGColor] = [UIColor.white.withAlphaComponent(0.55).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        if let gradient = CGGradient(colorsSpace: space, colors: shine as CFArray, locations: [0, 1]) {
            c.drawRadialGradient(gradient, startCenter: CGPoint(x: 22, y: 20), startRadius: 0,
                                 endCenter: CGPoint(x: 22, y: 20), endRadius: 22, options: [])
        }
        let shade: [CGColor] = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.35).cgColor]
        if let gradient = CGGradient(colorsSpace: space, colors: shade as CFArray, locations: [0.55, 1]) {
            c.drawRadialGradient(gradient, startCenter: CGPoint(x: 26, y: 26), startRadius: 0,
                                 endCenter: CGPoint(x: 26, y: 26), endRadius: 40, options: [])
        }
        c.restoreGState()
        c.setStrokeColor(UIColor(white: 0.15, alpha: 0.8).cgColor)
        c.setLineWidth(1.5)
        c.strokeEllipse(in: rect)
    }

    /// The whole pitch as one image: mowing stripes, thousands of grass
    /// blades in different greens, and worn patches where play is busiest.
    static func grass(size: CGSize, stripes: Int) -> SKTexture {
        let key = "\(Int(size.width))x\(Int(size.height))-\(stripes)"
        if let hit = grassCache[key] { return hit }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            paintGrass(ctx.cgContext, size: size, stripes: stripes)
        }
        let texture = SKTexture(image: image)
        grassCache[key] = texture
        return texture
    }

    private static func paintGrass(_ c: CGContext, size: CGSize, stripes: Int) {
        let stripeWidth: CGFloat = size.width / CGFloat(stripes)
        for i in 0..<stripes {
            let color: UIColor = i % 2 == 0 ? Palette.grassLight : Palette.grassDark
            c.setFillColor(color.cgColor)
            c.fill(CGRect(x: CGFloat(i) * stripeWidth, y: 0, width: stripeWidth + 1, height: size.height))
        }
        // Worn patches: goalmouths and the centre circle
        c.setFillColor(UIColor(red: 0.55, green: 0.5, blue: 0.3, alpha: 0.16).cgColor)
        for spot in [CGPoint(x: 70, y: size.height / 2), CGPoint(x: size.width - 70, y: size.height / 2), CGPoint(x: size.width / 2, y: size.height / 2)] {
            c.fillEllipse(in: CGRect(x: spot.x - 60, y: spot.y - 70, width: 120, height: 140))
            c.fillEllipse(in: CGRect(x: spot.x - 32, y: spot.y - 40, width: 64, height: 80))
        }
        // Grass blades
        c.setLineCap(.round)
        c.setLineWidth(1)
        for _ in 0..<14_000 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let length = CGFloat.random(in: 1.5...4)
            let lean = CGFloat.random(in: -1.2...1.2)
            let light = Bool.random()
            let green: CGFloat = light ? CGFloat.random(in: 0.66...0.78) : CGFloat.random(in: 0.48...0.58)
            let red: CGFloat = light ? 0.32 : 0.18
            c.setStrokeColor(UIColor(red: red, green: green, blue: red * 0.9, alpha: 0.55).cgColor)
            c.move(to: CGPoint(x: x, y: y))
            c.addLine(to: CGPoint(x: x + lean, y: y - length))
            c.strokePath()
        }
        // A few darker clumps for depth
        for _ in 0..<500 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let r = CGFloat.random(in: 2...5)
            c.setFillColor(UIColor(red: 0.1, green: 0.35, blue: 0.12, alpha: 0.12).cgColor)
            c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 1.4 * r))
        }
    }
}

// MARK: - Card display font

/// A 5×7 dot font, so a whole stand can hold up coloured cards that spell a word.
enum PixelFont {
    static let glyphs: [Character: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
        " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
    ]

    /// Lit cells for `text`, as (column, row) with row 0 at the top. Unknown letters become spaces.
    static func cells(_ text: String) -> (cells: Set<Int>, width: Int) {
        var lit = Set<Int>()
        var column = 0
        for ch in text.folding(options: .diacriticInsensitive, locale: nil).uppercased() {
            let glyph = glyphs[ch] ?? glyphs[" "] ?? []
            for (row, line) in glyph.enumerated() {
                for (dx, mark) in line.enumerated() where mark == "#" {
                    lit.insert(row * 10_000 + column + dx)
                }
            }
            column += 6
        }
        return (lit, max(0, column - 1))
    }
}

// MARK: - Labels

/// A bold, friendly label with a soft shadow so it reads on grass and on the stands.
func makeLabel(_ text: String, size: CGFloat, color: UIColor = .white) -> SKLabelNode {
    let label = SKLabelNode(text: text)
    label.fontName = "AvenirNext-Heavy"
    label.fontSize = size
    label.fontColor = color
    label.verticalAlignmentMode = .center
    label.horizontalAlignmentMode = .center
    let shadow = SKLabelNode(text: text)
    shadow.fontName = label.fontName
    shadow.fontSize = size
    shadow.fontColor = UIColor.black.withAlphaComponent(0.35)
    shadow.verticalAlignmentMode = .center
    shadow.horizontalAlignmentMode = .center
    shadow.position = CGPoint(x: 2, y: -3)
    shadow.zPosition = -1
    shadow.name = "shadow"
    label.addChild(shadow)
    return label
}

func setLabel(_ label: SKLabelNode, _ text: String) {
    label.text = text
    (label.childNode(withName: "shadow") as? SKLabelNode)?.text = text
}

/// Short buzz for kicks and goals.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func goal() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
