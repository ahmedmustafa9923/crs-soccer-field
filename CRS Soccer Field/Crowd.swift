//
//  Crowd.swift
//  CRS Soccer Field
//
//  A crowd that looks like a real one: tiered stands full of little people
//  in team shirts, scarves and hats, fans holding signs with the players'
//  names, printed banners and waving flags on the stand fronts, and
//  advertising boards round the pitch. When a team scores, its fans throw
//  their arms up and wave their signs.
//

import Foundation
import SpriteKit
import UIKit

/// One person in the stands.
struct Fan {
    let node: SKSpriteNode
    let side: Side
    let idle: SKTexture
    let cheer: SKTexture
    /// +1 for the stand above the pitch (home end), -1 for the one below.
    let stand: CGFloat
    /// Row 0 is nearest the pitch.
    let row: Int
    let column: Int
}

enum FanArt {
    static let canvas = CGSize(width: 16, height: 22)

    struct Outfit: Hashable {
        let shirt: Int
        let skin: Int
        let hair: Int
        let hat: Bool
        let scarf: Bool
    }

    private static var cache: [String: SKTexture] = [:]

    static func texture(_ outfit: Outfit, shirtColor: UIColor, trim: UIColor, cheering: Bool) -> SKTexture {
        let key = "\(outfit.shirt)-\(outfit.skin)-\(outfit.hair)-\(outfit.hat)-\(outfit.scarf)-\(cheering)-\(shirtColor.hashValue)"
        if let hit = cache[key] { return hit }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let skin = Look.skins[outfit.skin % Look.skins.count]
        let hair = Look.hairs[outfit.hair % Look.hairs.count]
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            paint(outfit, shirtColor: shirtColor, trim: trim, skin: skin, hair: hair, cheering: cheering, in: ctx.cgContext)
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    private static func paint(_ outfit: Outfit, shirtColor: UIColor, trim: UIColor, skin: UIColor, hair: UIColor,
                              cheering: Bool, in c: CGContext) {
        do {
            c.setLineCap(.round)
            if cheering {
                // Arms up
                c.setStrokeColor(shirtColor.cgColor)
                c.setLineWidth(3)
                c.move(to: CGPoint(x: 3.5, y: 13)); c.addLine(to: CGPoint(x: 1.8, y: 6))
                c.move(to: CGPoint(x: 12.5, y: 13)); c.addLine(to: CGPoint(x: 14.2, y: 6))
                c.strokePath()
                c.setFillColor(skin.cgColor)
                c.fillEllipse(in: CGRect(x: 0.2, y: 2.6, width: 3.4, height: 3.4))
                c.fillEllipse(in: CGRect(x: 12.4, y: 2.6, width: 3.4, height: 3.4))
            }
            // Shoulders and body
            c.setFillColor(shirtColor.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 2, y: 11, width: 12, height: 11), cornerRadius: 4).cgPath)
            c.fillPath()
            if outfit.scarf {
                c.setFillColor(trim.cgColor)
                c.fill(CGRect(x: 3, y: 10.5, width: 10, height: 2.4))
                c.fill(CGRect(x: 9.5, y: 12.5, width: 2.2, height: 5))
            }
            // Head
            c.setFillColor(skin.cgColor)
            c.fillEllipse(in: CGRect(x: 4.5, y: 3, width: 7, height: 8))
            if outfit.hat {
                c.setFillColor(shirtColor.cgColor)
                c.fillEllipse(in: CGRect(x: 4, y: 1.6, width: 8, height: 5.2))
                c.setFillColor(trim.cgColor)
                c.fill(CGRect(x: 4, y: 4.6, width: 8, height: 1.4))
                c.fillEllipse(in: CGRect(x: 6.8, y: 0.4, width: 2.4, height: 2.4))
            } else {
                c.setFillColor(hair.cgColor)
                c.fillEllipse(in: CGRect(x: 4.2, y: 2.2, width: 7.6, height: 4.6))
            }
            // Eyes
            c.setFillColor(UIColor(white: 0.1, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 6.1, y: 6.8, width: 1.2, height: 1.2))
            c.fillEllipse(in: CGRect(x: 8.7, y: 6.8, width: 1.2, height: 1.2))
            if cheering {
                c.setFillColor(UIColor(red: 0.5, green: 0.15, blue: 0.12, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: 7, y: 8.6, width: 2, height: 1.6))
            }
        }
    }
}

extension GameScene {
    /// Player names for each side, with blanks filled from the defaults.
    func squad(_ side: Side) -> [String] {
        let typed = side == .home ? settings.homePlayers : settings.awayPlayers
        let defaults = (side == .home ? Rosters.home : Rosters.away).map(\.name)
        return MatchSettings.split(MatchSettings.joined(typed), fallback: defaults)
    }

    func buildCrowd() {
        let width = 2 * (halfLength + 40)
        let rows = 7
        let rowGap: CGFloat = 16
        let spacing: CGFloat = 15
        let firstRow = halfWidth + 62

        // Tiered concrete steps behind the fans
        for sign in [CGFloat(1), CGFloat(-1)] {
            for r in 0..<rows {
                let step = SKSpriteNode(color: r % 2 == 0 ? UIColor(white: 0.24, alpha: 1) : UIColor(white: 0.2, alpha: 1),
                                        size: CGSize(width: width + 220, height: rowGap))
                step.position = CGPoint(x: 0, y: sign * (firstRow + CGFloat(r) * rowGap))
                step.zPosition = -6
                addChild(step)
            }
        }

        let palettes: [Side: (UIColor, UIColor)] = [.home: (settings.homeColor, .white), .away: (settings.awayColor, .white)]
        let neutral = [UIColor(white: 0.3, alpha: 1), UIColor(white: 0.85, alpha: 1), UIColor(red: 0.2, green: 0.25, blue: 0.3, alpha: 1)]

        for (sign, majority) in [(CGFloat(1), Side.home), (CGFloat(-1), Side.away)] {
            let names = squad(majority)
            let numbers = (majority == .home ? Rosters.home : Rosters.away).map(\.number)
            let perRow = Int(width / spacing)
            crowdColumns = perRow
            for r in 0..<rows {
                // Rows further back are higher up and slightly smaller.
                let y = sign * (firstRow + CGFloat(r) * rowGap) + 2
                let scale = 1 - CGFloat(r) * 0.03
                for c in 0..<perRow {
                    // Seats line up in columns (like a real stand), so card displays read clearly.
                    let jitter = CGFloat.random(in: -1...1)
                    let x = -width / 2 + spacing * (CGFloat(c) + 0.5) + jitter
                    let roll = Double.random(in: 0...1)
                    let side: Side = roll < 0.8 ? majority : majority.other
                    let (team, trim) = palettes[side] ?? (Palette.home, .white)
                    let shirtColor: UIColor
                    let shirtPick = Int.random(in: 0..<10)
                    if shirtPick < 7 { shirtColor = team } else if shirtPick < 9 { shirtColor = trim } else { shirtColor = neutral[c % neutral.count] }
                    // A pool of 12 looks per shirt colour keeps the crowd varied but quick to draw.
                    let look = Int.random(in: 0..<12)
                    let outfit = FanArt.Outfit(shirt: shirtPick < 7 ? 0 : (shirtPick < 9 ? 1 : 2), skin: look % 5, hair: (look / 2) % 4,
                                               hat: look % 6 == 0, scarf: look % 3 == 0)
                    let idle = FanArt.texture(outfit, shirtColor: shirtColor, trim: shirtColor == trim ? team : trim, cheering: false)
                    let cheer = FanArt.texture(outfit, shirtColor: shirtColor, trim: shirtColor == trim ? team : trim, cheering: true)
                    let node = SKSpriteNode(texture: idle, size: CGSize(width: 15 * scale, height: 20.6 * scale))
                    node.position = CGPoint(x: x, y: y)
                    node.zPosition = -5 + CGFloat(rows - r) * 0.01
                    addChild(node)
                    fans.append(Fan(node: node, side: side, idle: idle, cheer: cheer, stand: sign, row: r, column: c))

                    // About one fan in 22 holds up a sign for a player.
                    if side == majority && Int.random(in: 0..<22) == 0 {
                        let i = Int.random(in: 0..<names.count)
                        let words = ["GO \(names[i].uppercased())!", "\(names[i].uppercased()) \(numbers[i])", "WE ❤️ \(names[i].uppercased())", "\(names[i].uppercased())!!"]
                        let sign = makeSign(words[Int.random(in: 0..<words.count)], team: team)
                        sign.position = CGPoint(x: 0, y: 14)
                        sign.zRotation = CGFloat.random(in: -0.12...0.12)
                        node.addChild(sign)
                    }
                }
            }

            // Printed banners hung on the stand front, one per player
            let bannerY = sign * (halfWidth + 50)
            let (team, _) = palettes[majority] ?? (Palette.home, .white)
            let slots = names.count + 1
            for k in 0..<slots {
                let text = k == slots / 2
                    ? (majority == .home ? settings.homeName : settings.awayName).uppercased()
                    : "\(names[k < slots / 2 ? k : k - 1].uppercased())  \(numbers[k < slots / 2 ? k : k - 1])"
                let banner = makeBanner(text, team: team, highlight: k == slots / 2)
                let x = -width / 2 + width * (CGFloat(k) + 0.5) / CGFloat(slots)
                banner.position = CGPoint(x: x, y: bannerY)
                addChild(banner)
            }

            // Big flags on poles at the ends of each stand
            for fx in [-width / 2 + 30, width / 2 - 30] {
                let flag = makeFlag(team: team)
                flag.position = CGPoint(x: fx, y: sign * (firstRow + 40))
                addChild(flag)
            }
        }

        // Advertising boards along both touchlines
        let ads = ["CRS STUDIO", "CRS MEMORIES", "CRS MARKETS", "RELEASE TRACKER", "CRS WEALTH", "CRS SOCCER FIELD"]
        let boardWidth = width / CGFloat(ads.count)
        for sign in [CGFloat(1), CGFloat(-1)] {
            for (k, ad) in ads.enumerated() {
                let board = SKShapeNode(rect: CGRect(x: -boardWidth / 2 + 2, y: -8, width: boardWidth - 4, height: 16), cornerRadius: 2)
                board.fillColor = k % 2 == 0 ? UIColor(red: 0.08, green: 0.1, blue: 0.2, alpha: 1) : Palette.amber
                board.strokeColor = .clear
                board.position = CGPoint(x: -width / 2 + boardWidth * (CGFloat(k) + 0.5), y: sign * (halfWidth + 30))
                board.zPosition = -4
                let label = SKLabelNode(text: ad)
                label.fontName = "AvenirNext-Heavy"
                label.fontSize = 11
                label.fontColor = k % 2 == 0 ? .white : UIColor(red: 0.08, green: 0.1, blue: 0.2, alpha: 1)
                label.verticalAlignmentMode = .center
                board.addChild(label)
                addChild(board)
            }
        }
    }

    private func makeSign(_ text: String, team: UIColor) -> SKNode {
        let node = SKNode()
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 8
        label.verticalAlignmentMode = .center
        let filled = Bool.random()
        label.fontColor = filled ? .white : team
        let w = max(label.frame.width + 8, 30)
        let card = SKShapeNode(rect: CGRect(x: -w / 2, y: -7, width: w, height: 14), cornerRadius: 2)
        card.fillColor = filled ? team : .white
        card.strokeColor = filled ? .white : team
        card.lineWidth = 1.2
        node.addChild(card)
        node.addChild(label)
        node.zPosition = 1
        node.name = "sign"
        return node
    }

    private func makeBanner(_ text: String, team: UIColor, highlight: Bool) -> SKNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 13
        label.fontColor = highlight ? team : .white
        label.verticalAlignmentMode = .center
        let w = label.frame.width + 28
        let cloth = SKShapeNode(rect: CGRect(x: -w / 2, y: -10, width: w, height: 20), cornerRadius: 3)
        cloth.fillColor = highlight ? .white : team
        cloth.strokeColor = highlight ? team : .white
        cloth.lineWidth = 2
        cloth.zPosition = -3.5
        cloth.addChild(label)
        // A gentle ripple, like cloth in the wind
        cloth.run(.repeatForever(.sequence([.scaleY(to: 0.9, duration: Double.random(in: 0.8...1.3)), .scaleY(to: 1, duration: 1.0)])))
        return cloth
    }

    private func makeFlag(team: UIColor) -> SKNode {
        let pole = SKNode()
        pole.zPosition = -3
        let stick = SKShapeNode(rect: CGRect(x: -1, y: -18, width: 2, height: 40))
        stick.fillColor = UIColor(white: 0.85, alpha: 1)
        stick.strokeColor = .clear
        pole.addChild(stick)
        let cloth = SKNode()
        cloth.position = CGPoint(x: 1, y: 22)
        let body = SKShapeNode(rect: CGRect(x: 0, y: -16, width: 34, height: 16))
        body.fillColor = team
        body.strokeColor = .clear
        cloth.addChild(body)
        let stripe = SKShapeNode(rect: CGRect(x: 0, y: -10, width: 34, height: 4))
        stripe.fillColor = .white
        stripe.strokeColor = .clear
        cloth.addChild(stripe)
        pole.addChild(cloth)
        cloth.run(.repeatForever(.sequence([.scaleX(to: 0.75, duration: 0.35), .scaleX(to: 1, duration: 0.35)])))
        return pole
    }

    /// The stand that belongs to a side: home fans fill the top stand, away fans the bottom.
    func stand(of side: Side) -> CGFloat { side == .home ? 1 : -1 }

    /// A Mexican wave: fans stand with arms up, holding their signs high, one
    /// after another all the way along both stands.
    func mexicanWave() {
        let width = 2 * (halfLength + 40)
        for fan in fans {
            let node = fan.node
            guard node.action(forKey: "cheer") == nil else { continue }
            // Top stand runs left to right, bottom stand right to left, so the wave goes round the ground.
            let along = fan.stand > 0 ? node.position.x + width / 2 : width * 1.5 - node.position.x
            let delay = Double(along / 650) + Double(fan.row) * 0.02
            node.run(.sequence([
                .wait(forDuration: delay),
                .setTexture(fan.cheer),
                .moveBy(x: 0, y: 6, duration: 0.18),
                .wait(forDuration: 0.25),
                .moveBy(x: 0, y: -6, duration: 0.18),
                .setTexture(fan.idle),
            ]), withKey: "wave")
            if let sign = node.childNode(withName: "sign") {
                sign.run(.sequence([.wait(forDuration: delay), .moveBy(x: 0, y: 10, duration: 0.18),
                                    .wait(forDuration: 0.25), .moveBy(x: 0, y: -10, duration: 0.18)]), withKey: "wave")
            }
        }
    }

    /// A card display: every fan in the stand holds a coloured card over
    /// their head, and together the cards spell `text` in white on the team
    /// colour. The cards go up in a ripple from the middle, like an orchestra
    /// coming in, hold, then come down.
    func cardDisplay(for side: Side, text: String) {
        let sign = stand(of: side)
        let team = side == .home ? settings.homeColor : settings.awayColor
        var word = text.uppercased()
        // Seven rows of fans fit one line of up to about 13 letters.
        let maxLetters = max(1, (crowdColumns + 1) / 6)
        if word.count > maxLetters { word = String(word.prefix(maxLetters)) }
        let (lit, wordWidth) = PixelFont.cells(word)
        let left = max(0, (crowdColumns - wordWidth) / 2)
        let centre = Double(crowdColumns) / 2
        for fan in fans where fan.stand == sign {
            fan.node.childNode(withName: "card")?.removeFromParent()
            // Glyph row 0 is the top of the letters: the back row of the top stand,
            // the front row of the bottom stand, so the word reads upright on screen.
            let glyphRow = sign > 0 ? 6 - fan.row : fan.row
            let glyphColumn = fan.column - left
            let isLetter = glyphColumn >= 0 && glyphColumn < wordWidth && lit.contains(glyphRow * 10_000 + glyphColumn)
            let card = SKSpriteNode(color: isLetter ? .white : team, size: CGSize(width: 15, height: 13))
            card.name = "card"
            card.position = CGPoint(x: 0, y: 12)
            card.zPosition = 2
            card.alpha = 0
            fan.node.addChild(card)
            let delay = abs(Double(fan.column) - centre) * 0.012 + Double(fan.row) * 0.03
            card.run(.sequence([
                .wait(forDuration: delay),
                .group([.fadeIn(withDuration: 0.12), .moveBy(x: 0, y: 4, duration: 0.12)]),
                .wait(forDuration: 4.5),
                .fadeOut(withDuration: 0.3),
                .removeFromParent(),
            ]))
            fan.node.run(.sequence([.wait(forDuration: delay), .setTexture(fan.cheer), .wait(forDuration: 4.6), .setTexture(fan.idle)]))
        }
    }

    /// The scoring team's fans jump with arms up and wave their signs.
    func cheer(_ side: Side) {
        for fan in fans where fan.side == side {
            let node = fan.node
            let delay = Double.random(in: 0...0.35)
            node.removeAction(forKey: "wave")
            let jump = SKAction.sequence([.moveBy(x: 0, y: 5, duration: 0.13), .moveBy(x: 0, y: -5, duration: 0.13)])
            node.run(.sequence([
                .wait(forDuration: delay),
                .setTexture(fan.cheer),
                .repeat(jump, count: 7),
                .setTexture(fan.idle),
            ]), withKey: "cheer")
            if let sign = node.childNode(withName: "sign") {
                sign.run(.sequence([.wait(forDuration: delay), .moveBy(x: 0, y: 6, duration: 0.15),
                                    .repeat(.sequence([.rotate(toAngle: 0.25, duration: 0.15), .rotate(toAngle: -0.25, duration: 0.15)]), count: 6),
                                    .rotate(toAngle: 0, duration: 0.1), .moveBy(x: 0, y: -6, duration: 0.15)]))
            }
        }
    }
}
