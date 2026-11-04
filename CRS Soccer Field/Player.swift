//
//  Player.swift
//  CRS Soccer Field
//
//  Players and the referee as little cartoon figures: head and hair, shirt,
//  shorts, socks and boots, with a four-step running animation, an idle pose
//  and arms-up celebrations. Everything is drawn in code, so there are no
//  image files to manage, and each team's kit colours come from the palette.
//

import Foundation
import SpriteKit
import UIKit

// MARK: - Drawing the figures

struct Kit {
    let shirt: UIColor
    let shorts: UIColor
    let socks: UIColor
    var gloves: UIColor? = nil
    /// Long trousers instead of shorts and socks (managers and mentors).
    var trousers: UIColor? = nil
}

/// Extra poses beyond running and standing.
enum FigurePose: String, CaseIterable {
    case windup, strike, slide, header, point, highfive, hold
}

struct Look {
    let skin: UIColor
    let hair: UIColor
    var longHair = false

    static let skins: [UIColor] = [
        UIColor(red: 0.98, green: 0.84, blue: 0.71, alpha: 1), UIColor(red: 0.89, green: 0.69, blue: 0.53, alpha: 1),
        UIColor(red: 0.73, green: 0.52, blue: 0.37, alpha: 1), UIColor(red: 0.56, green: 0.38, blue: 0.26, alpha: 1),
        UIColor(red: 0.38, green: 0.26, blue: 0.18, alpha: 1),
    ]
    static let hairs: [UIColor] = [
        UIColor(red: 0.16, green: 0.11, blue: 0.08, alpha: 1), UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1),
        UIColor(red: 0.88, green: 0.72, blue: 0.38, alpha: 1), UIColor(red: 0.62, green: 0.29, blue: 0.14, alpha: 1),
        UIColor(red: 0.36, green: 0.22, blue: 0.12, alpha: 1),
    ]
}

/// The textures for one figure.
struct FigureFrames {
    let run: [SKTexture]
    let idle: SKTexture
    let cheer: SKTexture
    let poses: [FigurePose: SKTexture]
}

enum FigureArt {
    /// Drawing canvas in points. The feet sit at y = 58 (UIKit, top-down).
    static let canvas = CGSize(width: 48, height: 64)
    static let feetFromTop: CGFloat = 58

    private enum Pose { case run(Int), idle, cheer, extra(FigurePose) }

    private static var cache: [String: FigureFrames] = [:]

    /// Draws a figure's frames once and reuses them (players, locker room, next match).
    static func frames(kit: Kit, look: Look) -> FigureFrames {
        let key = [kit.shirt, kit.shorts, kit.socks, kit.gloves ?? .clear, kit.trousers ?? .clear, look.skin, look.hair]
            .map { $0.description }.joined(separator: "|") + (look.longHair ? "L" : "S")
        if let hit = cache[key] { return hit }
        let made = drawFrames(kit: kit, look: look)
        cache[key] = made
        return made
    }

    private static func drawFrames(kit: Kit, look: Look) -> FigureFrames {
        let run = (0..<4).map { SKTexture(image: draw(.run($0), kit: kit, look: look)) }
        var poses: [FigurePose: SKTexture] = [:]
        for pose in FigurePose.allCases {
            poses[pose] = SKTexture(image: draw(.extra(pose), kit: kit, look: look))
        }
        return FigureFrames(run: run, idle: SKTexture(image: draw(.idle, kit: kit, look: look)),
                            cheer: SKTexture(image: draw(.cheer, kit: kit, look: look)), poses: poses)
    }

    /// Feet (left, right) and hands (left, right) for each pose, for a figure facing right.
    private static func limbs(_ pose: Pose) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        switch pose {
        case .run(let i):
            switch i % 4 {
            case 0: return (CGPoint(x: 34, y: 56), CGPoint(x: 13, y: 55), CGPoint(x: 12, y: 33), CGPoint(x: 37, y: 28))
            case 1: return (CGPoint(x: 27, y: 58), CGPoint(x: 20, y: 52), CGPoint(x: 18, y: 35), CGPoint(x: 30, y: 33))
            case 2: return (CGPoint(x: 13, y: 55), CGPoint(x: 34, y: 56), CGPoint(x: 37, y: 28), CGPoint(x: 12, y: 33))
            default: return (CGPoint(x: 20, y: 52), CGPoint(x: 27, y: 58), CGPoint(x: 30, y: 33), CGPoint(x: 18, y: 35))
            }
        case .idle:
            return (CGPoint(x: 20, y: 58), CGPoint(x: 28, y: 58), CGPoint(x: 12, y: 34), CGPoint(x: 36, y: 34))
        case .cheer:
            return (CGPoint(x: 19, y: 58), CGPoint(x: 29, y: 58), CGPoint(x: 10, y: 5), CGPoint(x: 38, y: 5))
        case .extra(let pose):
            switch pose {
            // Kicking leg drawn back, arms out for balance
            case .windup: return (CGPoint(x: 24, y: 58), CGPoint(x: 9, y: 47), CGPoint(x: 8, y: 27), CGPoint(x: 40, y: 27))
            // Kicking leg swung through high
            case .strike: return (CGPoint(x: 22, y: 58), CGPoint(x: 42, y: 41), CGPoint(x: 12, y: 31), CGPoint(x: 37, y: 23))
            // Both legs out in front, arms back: a slide tackle
            case .slide: return (CGPoint(x: 43, y: 55), CGPoint(x: 35, y: 58), CGPoint(x: 9, y: 38), CGPoint(x: 17, y: 41))
            // Jumping, arms up and out, for headers
            case .header: return (CGPoint(x: 19, y: 53), CGPoint(x: 29, y: 51), CGPoint(x: 8, y: 24), CGPoint(x: 40, y: 24))
            // One arm straight up: the referee showing a card
            case .point: return (CGPoint(x: 20, y: 58), CGPoint(x: 28, y: 58), CGPoint(x: 12, y: 34), CGPoint(x: 33, y: 1))
            // One arm up and forward for a high five
            case .highfive: return (CGPoint(x: 20, y: 58), CGPoint(x: 28, y: 58), CGPoint(x: 12, y: 34), CGPoint(x: 40, y: 6))
            // Both hands in front, holding the ball
            case .hold: return (CGPoint(x: 20, y: 58), CGPoint(x: 28, y: 58), CGPoint(x: 31, y: 31), CGPoint(x: 35, y: 29))
            }
        }
    }

    private static func middle(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func stroke(_ c: CGContext, _ a: CGPoint, _ b: CGPoint, width: CGFloat, color: UIColor) {
        c.setStrokeColor(color.cgColor)
        c.setLineWidth(width)
        c.move(to: a)
        c.addLine(to: b)
        c.strokePath()
    }

    private static func draw(_ pose: Pose, kit: Kit, look: Look) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        return renderer.image { ctx in
            paint(pose, kit: kit, look: look, in: ctx.cgContext)
        }
    }

    private static func paint(_ pose: Pose, kit: Kit, look: Look, in c: CGContext) {
        let (footL, footR, handL, handR) = limbs(pose)
        do {
            c.setLineCap(.round)
            let boot = UIColor(white: 0.12, alpha: 1)

            // Legs, seen from the side so they swing from the hips without crossing:
            // skin to the knee, then socks, then boots.
            for (hip, foot) in [(CGPoint(x: 22, y: 40), footL), (CGPoint(x: 26, y: 40), footR)] {
                let knee = CGPoint(x: hip.x + (foot.x - hip.x) * 0.5, y: hip.y + (foot.y - hip.y) * 0.5)
                if let trousers = kit.trousers {
                    stroke(c, hip, foot, width: 7.5, color: trousers)
                } else {
                    stroke(c, hip, knee, width: 7, color: look.skin)
                    stroke(c, knee, foot, width: 7, color: kit.socks)
                }
                c.setFillColor(boot.cgColor)
                c.fillEllipse(in: CGRect(x: foot.x - 5, y: foot.y - 3, width: 12, height: 6))
            }

            // Shorts (or the top of the trousers)
            c.setFillColor((kit.trousers ?? kit.shorts).cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 14, y: 33, width: 20, height: 10), cornerRadius: 3).cgPath)
            c.fillPath()

            // Long hair falls behind the shoulders
            if look.longHair {
                c.setFillColor(look.hair.cgColor)
                c.addPath(UIBezierPath(roundedRect: CGRect(x: 14, y: 7, width: 20, height: 16), cornerRadius: 6).cgPath)
                c.fillPath()
            }

            // Arms: sleeve, then skin, then a glove for keepers. When running, the
            // arm swinging back is drawn behind the shirt and the other in front.
            let arms = [(CGPoint(x: 18, y: 22), handL), (CGPoint(x: 30, y: 22), handR)]
            let isRunning: Bool
            if case .run = pose { isRunning = true } else { isRunning = false }
            func drawArm(_ shoulder: CGPoint, _ hand: CGPoint) {
                let elbow = middle(shoulder, hand)
                stroke(c, shoulder, elbow, width: 6, color: kit.shirt)
                stroke(c, elbow, hand, width: 5, color: look.skin)
                if let gloves = kit.gloves {
                    c.setFillColor(gloves.cgColor)
                    c.fillEllipse(in: CGRect(x: hand.x - 4, y: hand.y - 4, width: 8, height: 8))
                }
            }
            if isRunning {
                for (_, hand) in arms where hand.x < 24 { drawArm(CGPoint(x: 23, y: 22), hand) }
            }

            // Shirt, with a white collar
            c.setFillColor(kit.shirt.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 13, y: 17, width: 22, height: 19), cornerRadius: 6).cgPath)
            c.fillPath()
            stroke(c, CGPoint(x: 20, y: 18.5), CGPoint(x: 28, y: 18.5), width: 2, color: .white)

            if isRunning {
                for (_, hand) in arms where hand.x >= 24 { drawArm(CGPoint(x: 25, y: 22), hand) }
            } else {
                for (shoulder, hand) in arms { drawArm(shoulder, hand) }
            }

            // Head: hair cap, then face, eyes and a smile looking to the right
            c.setFillColor(look.hair.cgColor)
            c.fillEllipse(in: CGRect(x: 15.5, y: 2, width: 17, height: 12))
            c.setFillColor(look.skin.cgColor)
            c.fillEllipse(in: CGRect(x: 17, y: 6, width: 15, height: 13))
            c.setFillColor(UIColor(white: 0.1, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 25, y: 10.5, width: 2.6, height: 2.6))
            c.fillEllipse(in: CGRect(x: 29, y: 10.5, width: 2.6, height: 2.6))
            c.setStrokeColor(UIColor(red: 0.55, green: 0.2, blue: 0.15, alpha: 1).cgColor)
            c.setLineWidth(1.2)
            c.addArc(center: CGPoint(x: 28.5, y: 14), radius: 2.2, startAngle: 0.2, endAngle: .pi - 0.2, clockwise: false)
            c.strokePath()
        }
    }
}

// MARK: - A figure on the pitch

/// The drawn figure, placed with its feet on the node's position. Flips to face
/// the way it's running and picks its animation frame from how far it moved.
final class Figure: SKSpriteNode {
    private let frames: FigureFrames
    private var lastPosition: CGPoint?
    private var runClock: Double = 0
    var celebrating: TimeInterval = 0
    /// A pose shown for a short time (a kick, a header, a high five).
    private var timedPose: FigurePose?
    private var timedLeft: TimeInterval = 0
    /// A pose held until cleared (winding up a kick, holding the ball).
    var heldPose: FigurePose?
    /// How fast the figure is moving, in points per second (for sweat and dust).
    private(set) var pace: Double = 0

    init(frames: FigureFrames) {
        self.frames = frames
        let size = CGSize(width: 46, height: 61)
        super.init(texture: frames.idle, color: .clear, size: size)
        anchorPoint = CGPoint(x: 0.5, y: 1 - FigureArt.feetFromTop / FigureArt.canvas.height)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ pose: FigurePose, for seconds: TimeInterval) {
        timedPose = pose
        timedLeft = seconds
    }

    /// `at` is the owner's position this frame (the figure itself sits at 0,0).
    func animate(at point: CGPoint, facing: CGPoint, dt: TimeInterval) {
        let previous = lastPosition ?? point
        lastPosition = point
        let moved = point - previous
        pace = dt > 0 ? Double(moved.length) / dt : 0
        let busy = hasActions()

        if let pose = heldPose, let texture = frames.poses[pose] {
            self.texture = texture
            faceAlong(moved, facing)
            return
        }
        if timedLeft > 0, let pose = timedPose, let texture = frames.poses[pose] {
            timedLeft -= dt
            self.texture = texture
            return
        }
        if celebrating > 0 {
            celebrating -= dt
            texture = frames.cheer
            return
        }
        if pace > 25 {
            // Quicker strides the faster they go, leaning into the run with a bounce in each step.
            runClock += dt * pace / 30
            texture = frames.run[Int(runClock) % frames.run.count]
            faceAlong(moved, facing)
            if !busy {
                let lean = CGFloat(min(pace / 300, 1)) * 0.14
                zRotation = -xScale * lean
                position.y = abs(CGFloat(sin(runClock * .pi))) * 2.5
            }
        } else {
            texture = frames.idle
            if abs(facing.x) > 0.2 { xScale = facing.x < 0 ? -1 : 1 }
            if !busy {
                zRotation = 0
                position.y = 0
            }
        }
    }

    private func faceAlong(_ moved: CGPoint, _ facing: CGPoint) {
        if abs(moved.x) > 0.3 { xScale = moved.x < 0 ? -1 : 1 }
        else if abs(facing.x) > 0.2 { xScale = facing.x < 0 ? -1 : 1 }
    }
}

final class Player: SKNode {
    static let radius: CGFloat = 18

    let side: Side
    let role: Role
    let number: Int
    let playerName: String
    /// Place in the formation, as fractions of the half-field, for a team attacking to the right.
    let spot: CGPoint

    var velocity = CGPoint.zero
    var facing = CGPoint(x: 1, y: 0)
    var kickCooldown: TimeInterval = 0
    var tackleCooldown: TimeInterval = 0
    var thinkTimer: TimeInterval = 0
    var holdTime: TimeInterval = 0
    var dashTime: TimeInterval = 0
    var goals = 0
    /// 1 = fresh, falls when sprinting, comes back when jogging or standing.
    var stamina: CGFloat = 1
    var yellowCards = 0
    var sentOff = false

    let figure: Figure
    private let ring: SKShapeNode
    private let tag: SKLabelNode
    private let barFill = SKSpriteNode(color: .green, size: CGSize(width: 30, height: 4))
    private var sweatClock: TimeInterval = 0
    private var dustClock: TimeInterval = 0

    let kit: Kit
    let look: Look

    init(side: Side, role: Role, number: Int, name: String, spot: CGPoint, kit: Kit, look: Look) {
        self.kit = kit
        self.look = look
        self.side = side
        self.role = role
        self.number = number
        self.playerName = name
        self.spot = spot
        figure = Figure(frames: FigureArt.frames(kit: kit, look: look))
        ring = SKShapeNode(ellipseOf: CGSize(width: 54, height: 24))
        tag = makeLabel(name, size: 14)
        super.init()

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 36, height: 13))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.25)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -1)
        shadow.zPosition = -1
        addChild(shadow)

        ring.strokeColor = UIColor(red: 1, green: 0.86, blue: 0.2, alpha: 1)
        ring.fillColor = UIColor(red: 1, green: 0.86, blue: 0.2, alpha: 0.18)
        ring.lineWidth = 3.5
        ring.glowWidth = 2
        ring.isHidden = true
        ring.zPosition = -0.5
        ring.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.45), .scale(to: 1, duration: 0.45)])))
        addChild(ring)

        addChild(figure)

        // The number sits on the shirt but isn't part of the drawing, so it never shows mirrored.
        let numberLabel = makeLabel("\(number)", size: 11)
        numberLabel.position = CGPoint(x: 0, y: 30)
        numberLabel.zPosition = 1
        addChild(numberLabel)

        // Stamina bar over the head
        let barBack = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.55), size: CGSize(width: 32, height: 6))
        barBack.position = CGPoint(x: 0, y: 63)
        barBack.zPosition = 3
        addChild(barBack)
        barFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        barFill.position = CGPoint(x: -15, y: 0)
        barFill.zPosition = 0.1
        barBack.addChild(barFill)

        tag.position = CGPoint(x: 0, y: 78)
        tag.isHidden = true
        tag.zPosition = 3
        addChild(tag)

        zPosition = 5
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var isControlled = false {
        didSet {
            ring.isHidden = !isControlled
            tag.isHidden = !isControlled
        }
    }

    /// Slower when tired: full speed at full stamina, three-quarters when worn out.
    var staminaFactor: CGFloat { 0.75 + 0.25 * stamina }

    /// Kept for the scene's calls: the figure shows direction by turning left or right.
    func updateNose() {
        if abs(facing.x) > 0.2 { figure.xScale = facing.x < 0 ? -1 : 1 }
    }

    /// Animation frame, stamina bar, sweat and dust, and drawing order.
    func animate(_ dt: TimeInterval) {
        figure.animate(at: position, facing: facing, dt: dt)
        zPosition = 5 - position.y / 1000

        barFill.size.width = 30 * max(0, min(stamina, 1))
        barFill.color = stamina > 0.6 ? UIColor(red: 0.3, green: 0.9, blue: 0.35, alpha: 1)
            : stamina > 0.3 ? UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1) : UIColor(red: 1, green: 0.3, blue: 0.25, alpha: 1)

        // Sweat when tired or sprinting
        let pace = figure.pace
        if stamina < 0.7 || pace > 240 {
            sweatClock += dt
            let every: TimeInterval = stamina < 0.4 ? 0.3 : 0.7
            if sweatClock > every {
                sweatClock = 0
                sweat()
            }
        }
        // Dust from the boots when sprinting
        if pace > 250 {
            dustClock += dt
            if dustClock > 0.12 {
                dustClock = 0
                dust()
            }
        }
    }

    private func sweat() {
        let drop = SKShapeNode(ellipseOf: CGSize(width: 3.4, height: 4.6))
        drop.fillColor = UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 0.95)
        drop.strokeColor = UIColor.white.withAlphaComponent(0.8)
        drop.lineWidth = 0.6
        let side: CGFloat = Bool.random() ? 1 : -1
        drop.position = CGPoint(x: side * CGFloat.random(in: 5...9), y: 50)
        drop.zPosition = 2
        addChild(drop)
        drop.run(.sequence([
            .group([.moveBy(x: side * 6, y: -14, duration: 0.5), .fadeOut(withDuration: 0.5)]),
            .removeFromParent(),
        ]))
    }

    private func dust() {
        guard let scene = scene else { return }
        let puff = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...5))
        puff.fillColor = UIColor(white: 0.9, alpha: 0.35)
        puff.strokeColor = .clear
        puff.position = position + CGPoint(x: -figure.xScale * 8, y: 1)
        puff.zPosition = zPosition - 0.01
        scene.addChild(puff)
        puff.run(.sequence([.group([.scale(to: 2.2, duration: 0.45), .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
    }

    // MARK: Moves

    /// Arms up and a little hop.
    func celebrate() {
        figure.celebrating = 1.6
        let hop = SKAction.sequence([.moveBy(x: 0, y: 10, duration: 0.15), .moveBy(x: 0, y: -10, duration: 0.15)])
        figure.run(.repeat(hop, count: 4))
    }

    /// Leg drawn back while a kick is being charged.
    func windUp(_ on: Bool) {
        figure.heldPose = on ? .windup : nil
    }

    /// The kicking leg swings through.
    func strike() {
        figure.heldPose = nil
        figure.show(.strike, for: 0.28)
    }

    /// Sliding in with both legs out.
    func slide() {
        figure.show(.slide, for: 0.45)
        figure.run(.sequence([.rotate(toAngle: figure.xScale * 0.35, duration: 0.08), .wait(forDuration: 0.3), .rotate(toAngle: 0, duration: 0.1)]))
    }

    /// Jumping to head the ball.
    func header() {
        figure.show(.header, for: 0.5)
        figure.run(.sequence([.moveBy(x: 0, y: 16, duration: 0.2), .moveBy(x: 0, y: -16, duration: 0.25)]))
    }

    /// An overhead (bicycle) kick: jump, flip back, strike, land.
    func bicycleKick() {
        figure.show(.strike, for: 0.7)
        let flip = SKAction.group([
            .sequence([.moveBy(x: 0, y: 30, duration: 0.25), .moveBy(x: 0, y: -30, duration: 0.35)]),
            .sequence([.rotate(byAngle: -figure.xScale * .pi * 1.1, duration: 0.3), .rotate(toAngle: 0, duration: 0.3)]),
        ])
        figure.run(flip)
    }

    func highFive() {
        figure.show(.highfive, for: 0.9)
        let star = makeLabel("✋", size: 20)
        star.position = CGPoint(x: figure.xScale * 16, y: 70)
        star.zPosition = 4
        addChild(star)
        star.run(.sequence([.group([.scale(to: 1.5, duration: 0.3), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
    }

    /// A 360° spin with the ball (a roulette).
    func roulette() {
        figure.run(.rotate(byAngle: -figure.xScale * .pi * 2, duration: 0.45))
    }

    /// Feet flicking over the ball (a step-over).
    func stepOver() {
        figure.show(.windup, for: 0.15)
        figure.run(.sequence([.scaleX(to: -figure.xScale, duration: 0.08), .wait(forDuration: 0.12),
                              .scaleX(to: figure.xScale, duration: 0.08)]))
    }
}
