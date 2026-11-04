//
//  Moves.swift
//  CRS Soccer Field
//
//  The real-football parts of a match:
//  • Power meter: hold KICK or PASS and the meter fills yellow, orange, then
//    red (strongest). The player draws the kicking leg back while it charges
//    and swings it through on release. Strong shots and passes go in the air.
//  • Skills: roulette, step-over and rainbow flick with the ball, and a slide
//    tackle without it.
//  • Headers and bicycle kicks when the ball is in the air.
//  • Fouls, with a stern referee who shows yellow and red cards.
//  • Stamina: sprinting tires players out; tired players slow down and sweat.
//  • The other team plays harder when you're on top, so it stays a contest.
//  • Managers and mentors on the touchline, benches, and a mini-map.
//

import Foundation
import SpriteKit
import UIKit

extension GameScene {
    // MARK: Power meter

    func buildPowerMeter() {
        let back = SKShapeNode(rect: CGRect(x: -29, y: -7, width: 58, height: 14), cornerRadius: 5)
        back.fillColor = UIColor.black.withAlphaComponent(0.6)
        back.strokeColor = .white
        back.lineWidth = 2
        powerMeter.addChild(back)
        meterFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        meterFill.position = CGPoint(x: -26, y: 0)
        meterFill.zPosition = 1
        powerMeter.addChild(meterFill)
        let label = makeLabel("POWER", size: 10)
        label.position = CGPoint(x: 0, y: 15)
        powerMeter.addChild(label)
        powerMeter.zPosition = 40
        powerMeter.isHidden = true
        addChild(powerMeter)
    }

    var canCharge: Bool {
        (phase == .playing || phase == .restart) && controlled != nil && holder === controlled
    }

    /// 0 to 1, a full charge takes 1.1 seconds.
    var chargePower: CGFloat { CGFloat(min((now - chargeStart) / 1.1, 1)) }

    func beginCharge(_ kind: Charge, _ touch: UITouch) {
        charging = kind
        chargeStart = now
        if kind == .kick { kickTouch = touch } else { passTouch = touch }
        controlled?.windUp(true)
        powerMeter.isHidden = false
    }

    /// Keeps the meter over the player's head and colours it as it fills.
    func updateCharge() {
        guard charging != nil else { return }
        guard let c = controlled, canCharge else {
            cancelCharge()
            return
        }
        let power = chargePower
        powerMeter.position = c.position + CGPoint(x: 0, y: 100)
        meterFill.size.width = 52 * max(0.04, power)
        if power < 0.45 {
            meterFill.color = UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 1)
        } else if power < 0.8 {
            meterFill.color = UIColor(red: 1, green: 0.58, blue: 0.1, alpha: 1)
        } else {
            meterFill.color = UIColor(red: 0.95, green: 0.18, blue: 0.15, alpha: 1)
        }
        powerMeter.setScale(power >= 1 ? 1 + 0.06 * CGFloat(sin(now * 30)) : 1)
    }

    func cancelCharge() {
        charging = nil
        kickTouch = nil
        passTouch = nil
        powerMeter.isHidden = true
        controlled?.windUp(false)
    }

    func releaseCharge(_ touches: Set<UITouch>) {
        guard let kind = charging else { return }
        let mine = kind == .kick ? kickTouch : passTouch
        guard let mine, touches.contains(mine) else { return }
        // A quick tap is a medium kick.
        let power = now - chargeStart < 0.1 ? 0.5 : chargePower
        let c = controlled
        cancelCharge()
        guard let c, holder === c, phase == .playing || phase == .restart else { return }
        phase = .playing
        if kind == .kick { releaseKick(c, power) } else { releasePass(c, power) }
    }

    private func releaseKick(_ c: Player, _ power: CGFloat) {
        let goalX = dir(.home) * halfLength
        if abs(goalX - c.position.x) < 430 {
            // Red-zone shots fly and can go wide or over.
            let loft: CGFloat = power > 0.85 ? 190 : (power > 0.6 ? 90 : 0)
            let error: CGFloat = power > 0.9 ? 50 : 18
            shoot(c, aimY: stick.y * goalHalf * 0.8, power: 520 + 720 * power, error: error, loft: loft)
            if power > 0.85 { showMessage("Power shot!", size: 34, hold: 0.6) }
        } else {
            let direction = CGPoint(x: dir(.home), y: stick.y * 0.6).normalized
            kick(c, direction: direction, speed: 420 + 520 * power, loft: 160 + 220 * power)
        }
    }

    private func releasePass(_ c: Player, _ power: CGFloat) {
        let prefer: CGPoint? = stick.length > 0.3 ? stick.normalized : nil
        if let mate = bestPassTarget(for: c, prefer: prefer) {
            pass(c, to: mate, strength: power)
        } else {
            kick(c, direction: c.facing, speed: 300 + 400 * power, loft: power > 0.8 ? 240 : 0)
        }
    }

    // MARK: Skills

    func skillPressed() {
        guard phase == .playing || phase == .restart, let c = controlled else { return }
        if holder === c {
            phase = .playing
            let side = CGPoint(x: -c.facing.y, y: c.facing.x) * (Bool.random() ? 1 : -1)
            switch Int.random(in: 0..<3) {
            case 0:
                c.roulette()
                c.velocity = c.velocity + side * 220
                protectTimer = 0.6
                showMessage("Roulette!", size: 34, hold: 0.5)
            case 1:
                c.stepOver()
                c.velocity = c.velocity + side * 260
                protectTimer = 0.5
                showMessage("Step-over!", size: 34, hold: 0.5)
            default:
                // Rainbow flick: the ball pops up over the defender and lands ahead.
                kick(c, direction: c.facing, speed: 260, loft: 330)
                c.kickCooldown = 0.2
                c.dashTime = 0.3
                showMessage("Rainbow flick!", size: 34, hold: 0.6)
            }
            Sound.shared.play(.kick, volume: 0.4)
        } else {
            // Slide tackle: a quick lunge with both legs out. Wins the ball more often, but fouls more too.
            c.slide()
            c.dashTime = 0.35
            slideUntil = now + 0.45
            let toBall = (ball.position - c.position).normalized
            c.velocity = c.velocity + toBall * 260
        }
    }

    // MARK: Headers and bicycle kicks

    func checkAerial() {
        for p in players where p.kickCooldown <= 0 && p.role != .keeper {
            guard p.position.distance(to: ball.position) < 30 else { continue }
            let goal = CGPoint(x: dir(p.side) * halfLength, y: 0)
            let toGoal = goal - p.position
            let nearGoal = toGoal.length < 300
            let wantsBicycle = p === controlled ? wantBicycleUntil > now : Double.random(in: 0...1) < 0.25
            p.kickCooldown = 0.45
            lastKicker = p
            Sound.shared.play(.thud, volume: 0.8)
            if nearGoal && ballHeight > 36 && wantsBicycle {
                p.bicycleKick()
                let aim = CGPoint(x: goal.x, y: CGFloat.random(in: -goalHalf * 0.7...goalHalf * 0.7))
                kick(p, direction: (aim - p.position).normalized, speed: 1000, loft: 60, animate: false)
                shots[p.side.rawValue] += 1
                showMessage("Bicycle kick!", size: 40)
                Sound.shared.play(.cheer, volume: 0.5)
            } else {
                p.header()
                let aim = nearGoal ? CGPoint(x: goal.x, y: CGFloat.random(in: -goalHalf * 0.8...goalHalf * 0.8)) : goal
                let speed: CGFloat = nearGoal ? 760 : 520
                kick(p, direction: (aim - p.position).normalized, speed: speed, loft: 80, animate: false)
                if nearGoal {
                    shots[p.side.rawValue] += 1
                    showMessage("Header!", size: 36, hold: 0.6)
                }
            }
            wantBicycleUntil = 0
            return
        }
    }

    // MARK: Fouls and cards

    enum Card { case yellow, red }

    func foul(by p: Player, on h: Player, fromBehind: Bool, sliding: Bool) {
        wobble(h)
        h.figure.show(.slide, for: 0.6)
        Sound.shared.play(.thud)
        var card: Card?
        if fromBehind && sliding && Double.random(in: 0...1) < 0.55 { card = .yellow }
        if Double.random(in: 0...1) < 0.02 { card = .red }
        if card == .yellow {
            p.yellowCards += 1
            if p.yellowCards >= 2 { card = .red }
        }
        let spot = CGPoint(x: clamp(h.position.x, -halfLength + 40, halfLength - 40), y: clamp(h.position.y, -halfWidth + 30, halfWidth - 30))
        setPiece(for: h.side, at: spot, message: "Foul! Free kick")
        if let card {
            restartTimer = 2.6
            protectTimer = 2.8
            showCard(card, to: p)
        }
    }

    /// The referee runs over, blows hard, and holds the card up high.
    private func showCard(_ card: Card, to p: Player) {
        guard let figure = refereeFigure else { return }
        referee.removeAllActions()
        let beside = p.position + CGPoint(x: p.position.x > referee.position.x ? -44 : 44, y: 0)
        referee.run(.move(to: beside, duration: 0.45))
        after(0.5) { [weak self, weak p] in
            guard let self, let p else { return }
            self.whistle(long: true)
            figure.show(.point, for: 1.8)
            figure.xScale = p.position.x >= self.referee.position.x ? 1 : -1
            let cardNode = SKShapeNode(rect: CGRect(x: -6, y: -8, width: 12, height: 16), cornerRadius: 1.5)
            cardNode.fillColor = card == .yellow ? UIColor(red: 1, green: 0.85, blue: 0.1, alpha: 1) : UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
            cardNode.strokeColor = .white
            cardNode.lineWidth = 1.5
            cardNode.position = CGPoint(x: figure.xScale * 9, y: 66)
            cardNode.zPosition = 6
            cardNode.setScale(0.2)
            self.referee.addChild(cardNode)
            cardNode.run(.sequence([.scale(to: 1.3, duration: 0.15), .scale(to: 1, duration: 0.1), .wait(forDuration: 1.5),
                                    .fadeOut(withDuration: 0.2), .removeFromParent()]))
            // A stern shake and a red "!" over the referee
            let stern = makeLabel("!", size: 26, color: UIColor(red: 1, green: 0.25, blue: 0.2, alpha: 1))
            stern.position = CGPoint(x: -figure.xScale * 12, y: 82)
            stern.zPosition = 6
            self.referee.addChild(stern)
            stern.run(.sequence([.repeat(.sequence([.moveBy(x: 2, y: 0, duration: 0.05), .moveBy(x: -2, y: 0, duration: 0.05)]), count: 6),
                                 .fadeOut(withDuration: 0.3), .removeFromParent()]))
            if card == .yellow {
                self.showMessage("Yellow card: \(p.playerName)", size: 36, hold: 1.4)
            } else {
                self.showMessage("Red card! \(p.playerName) is off", size: 36, hold: 1.6)
                self.sendOff(p)
            }
        }
    }

    private func sendOff(_ p: Player) {
        p.sentOff = true
        if p === controlled {
            p.isControlled = false
            controlled = nil
        }
        players.removeAll { $0 === p }
        mapMarkers[ObjectIdentifier(p)]?.removeFromParent()
        mapMarkers[ObjectIdentifier(p)] = nil
        let exit = CGPoint(x: p.position.x, y: -halfWidth - 70)
        p.run(.sequence([.move(to: exit, duration: 1.6), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: Stamina and a fair contest

    func drainStamina(_ p: Player, _ dt: TimeInterval) {
        let pace = p.velocity.length
        let step = CGFloat(dt)
        if p.dashTime > 0 { p.stamina -= step * 0.22 }
        else if pace > 200 { p.stamina -= step * 0.045 }
        else if pace < 110 { p.stamina += step * 0.06 }
        else { p.stamina += step * 0.02 }
        p.stamina = clamp(p.stamina, 0.15, 1)
    }

    /// When you lead or keep the ball, the other team lifts its game, so they
    /// are always at least as good as you. It eases back if they get ahead.
    func updateAIBoost(_ dt: TimeInterval) {
        guard settings.mode == .match else { return }
        let lead = CGFloat(score[0] - score[1])
        let total = max(ballTime[0] + ballTime[1], 1)
        let share = CGFloat(ballTime[0] / total)
        let target = clamp(lead * 0.08 + max(0, share - 0.55) * 0.5, 0, 0.35)
        aiBoost += (target - aiBoost) * CGFloat(min(1, dt * 0.5))
    }

    var awaySpeed: CGFloat {
        let boosted = settings.level.aiSpeed * (1 + aiBoost)
        // Once you're ahead, they run at least as fast as your players.
        return score[0] > score[1] ? max(boosted, 235) : boosted
    }

    // MARK: Benches, managers and mentors

    func buildBenchesAndStaff() {
        let benchY = -halfWidth - 22
        for side in [Side.home, Side.away] {
            let sign: CGFloat = side == .home ? -1 : 1
            let color = side == .home ? settings.homeColor : settings.awayColor
            // Dugout: a bench under a clear roof
            let dugout = SKShapeNode(rect: CGRect(x: -90, y: -11, width: 180, height: 22), cornerRadius: 4)
            dugout.fillColor = UIColor(white: 0.15, alpha: 0.9)
            dugout.strokeColor = color
            dugout.lineWidth = 2
            dugout.position = CGPoint(x: sign * 300, y: benchY)
            dugout.zPosition = -3.8
            addChild(dugout)
            let roof = SKShapeNode(rect: CGRect(x: -94, y: -4, width: 188, height: 14), cornerRadius: 6)
            roof.fillColor = UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 0.25)
            roof.strokeColor = UIColor.white.withAlphaComponent(0.5)
            roof.position = CGPoint(x: 0, y: -8)
            roof.zPosition = 0.5
            dugout.addChild(roof)
            // Technical area, marked in dashes
            let area = SKShapeNode(rect: CGRect(x: -45, y: -14, width: 90, height: 26))
            area.strokeColor = UIColor.white.withAlphaComponent(0.6)
            area.lineWidth = 1.5
            area.fillColor = .clear
            area.position = CGPoint(x: sign * 160, y: benchY + 4)
            area.zPosition = -3.9
            addChild(area)

            let names = side == .home ? Rosters.homeStaff : Rosters.awayStaff
            let suit = Kit(shirt: UIColor(white: 0.2, alpha: 1), shorts: UIColor(white: 0.15, alpha: 1), socks: UIColor(white: 0.15, alpha: 1),
                           gloves: nil, trousers: UIColor(white: 0.15, alpha: 1))
            let tracksuit = Kit(shirt: color, shorts: UIColor(white: 0.15, alpha: 1), socks: UIColor(white: 0.15, alpha: 1),
                                gloves: nil, trousers: UIColor(white: 0.18, alpha: 1))
            for (k, (title, name, kit)) in [("Manager", names.manager, suit), ("Mentor", names.mentor, tracksuit)].enumerated() {
                let node = SKNode()
                node.position = CGPoint(x: sign * (k == 0 ? 160 : 410), y: benchY + 2)
                node.zPosition = 4
                let look = Look(skin: Look.skins[(k * 2 + (side == .home ? 1 : 3)) % Look.skins.count], hair: Look.hairs[k % Look.hairs.count])
                let figure = Figure(frames: FigureArt.frames(kit: kit, look: look))
                figure.xScale = -sign
                node.addChild(figure)
                let label = makeLabel("\(title) \(name)", size: 11)
                label.position = CGPoint(x: 0, y: 66)
                node.addChild(label)
                addChild(node)
                staffNodes.append(node)
                if k == 0 { managers[side] = figure }
            }
        }
    }

    /// Managers wave instructions now and then.
    func animateStaff(_ dt: TimeInterval) {
        guard !managers.isEmpty else { return }
        for node in staffNodes {
            if let figure = node.children.compactMap({ $0 as? Figure }).first {
                figure.animate(at: node.position, facing: CGPoint(x: figure.xScale, y: 0), dt: dt)
            }
        }
        guard phase == .playing else { return }
        staffTimer += dt
        if staffTimer > 5 {
            staffTimer = 0
            let side: Side = Bool.random() ? .home : .away
            managers[side]?.show(Bool.random() ? .point : .highfive, for: 1.2)
        }
    }

    /// Bench seats, for the players before the walk-out.
    func benchSeat(_ p: Player, index: Int) -> CGPoint {
        let sign: CGFloat = p.side == .home ? -1 : 1
        return CGPoint(x: sign * (370 - CGFloat(index) * 34), y: -halfWidth - 24)
    }

    // MARK: Mini-map

    func updateMiniMap() {
        let mapWidth: CGFloat = 164
        let mapHeight: CGFloat = mapWidth * halfWidth / halfLength
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: clamp(point.x / (2 * halfLength), -0.5, 0.5) * mapWidth,
                    y: clamp(point.y / (2 * halfWidth), -0.5, 0.5) * mapHeight)
        }
        for p in players {
            let key = ObjectIdentifier(p)
            let marker: SKShapeNode
            if let existing = mapMarkers[key] {
                marker = existing
            } else {
                if p.side == .home {
                    marker = SKShapeNode(circleOfRadius: 4.5)
                    marker.fillColor = settings.homeColor
                } else {
                    let tri = CGMutablePath()
                    tri.move(to: CGPoint(x: 0, y: 5.5))
                    tri.addLine(to: CGPoint(x: 5, y: -3.5))
                    tri.addLine(to: CGPoint(x: -5, y: -3.5))
                    tri.closeSubpath()
                    marker = SKShapeNode(path: tri)
                    marker.fillColor = settings.awayColor
                }
                marker.strokeColor = .white
                marker.lineWidth = 1
                marker.zPosition = 2
                miniMap.addChild(marker)
                mapMarkers[key] = marker
            }
            marker.position = place(p.position)
            marker.strokeColor = p === controlled ? UIColor(red: 1, green: 0.86, blue: 0.2, alpha: 1) : .white
            marker.lineWidth = p === controlled ? 2.5 : 1
        }
        mapBall.position = place(ball.position)
        mapBall.isHidden = ball.isHidden
    }
}
