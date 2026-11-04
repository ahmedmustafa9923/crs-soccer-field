//
//  Drills.swift
//  CRS Soccer Field
//
//  Practice (free shooting against a goalkeeper, no clock) and the three
//  training drills, scored with up to three stars:
//  • Shooting: score as many goals as you can in 45 seconds.
//  • Dribbling: run the ball through six gates as fast as you can.
//  • Passing: pass to the friends standing in the circles, eight in 45 seconds.
//

import Foundation
import SpriteKit
import UIKit

extension GameScene {
    var drill: Drill? {
        if case .drill(let d) = settings.mode { return d }
        return nil
    }

    var isPractice: Bool { settings.mode == .practice }

    /// Which players take part in each mode.
    func keepForMode(_ p: Player) -> Bool {
        switch settings.mode {
        case .match: return true
        case .practice: return p.side == .home || p.role == .keeper
        case .drill(.shooting): return (p.side == .home && p.role == .forward) || (p.side == .away && p.role == .keeper)
        case .drill(.dribbling): return p.side == .home && p.role == .forward
        case .drill(.passing): return p.side == .home && p.role != .keeper
        }
    }

    // MARK: Start

    func startDrill() {
        phase = .restart
        restartTimer = 1.8
        clock = 0
        drillScore = 0
        drillDone = false
        drillTime = 0
        referee.isHidden = true
        ball.isHidden = false
        Sound.shared.crowdLevel(0.15)

        guard let user = players.first(where: { $0.side == .home && $0.role == .forward }) ?? players.first else { return }
        drillPlayer = drill == nil ? nil : user
        for p in players {
            p.removeAllActions()
            p.velocity = .zero
            p.position = worldSpot(p, kickoff: false)
        }
        switch settings.mode {
        case .practice: user.position = CGPoint(x: -40, y: 0)
        case .drill(.shooting): user.position = CGPoint(x: 120, y: 0)
        case .drill(.dribbling):
            user.position = CGPoint(x: -halfLength + 90, y: 0)
            buildGates()
        case .drill(.passing):
            user.position = CGPoint(x: -120, y: 0)
            placePassingFriends(except: user)
        case .match: break
        }
        user.facing = CGPoint(x: 1, y: 0)
        user.updateNose()
        holder = user
        lastTouch = .home
        setControlled(user)
        protectTimer = 1
        focus = nil
        zoom = 1
        layoutHUD()

        let title = drill?.title ?? "Practice"
        let text = drill?.goalText ?? "Shoot past the goalkeeper. Tap pause, then End practice when you're done."
        showBanner(title: title, subtitle: text, hint: nil)
        after(2.4) { [weak self] in self?.removeBanner() }
        after(1.7) { [weak self] in self?.showMessage("Go!", size: 52) }
    }

    private func buildGates() {
        gates.forEach { $0.removeFromParent() }
        gates = []
        let xs: [CGFloat] = [-300, -160, -20, 120, 260, 400]
        for (i, x) in xs.enumerated() {
            let gate = SKNode()
            gate.position = CGPoint(x: x, y: i % 2 == 0 ? 140 : -140)
            gate.zPosition = 3
            gate.name = "drill"
            for dy in [CGFloat(-38), CGFloat(38)] {
                let cone = SKShapeNode(path: {
                    let path = CGMutablePath()
                    path.move(to: CGPoint(x: -9, y: -8))
                    path.addLine(to: CGPoint(x: 9, y: -8))
                    path.addLine(to: CGPoint(x: 0, y: 14))
                    path.closeSubpath()
                    return path
                }())
                cone.fillColor = UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1)
                cone.strokeColor = .white
                cone.lineWidth = 1.5
                cone.position = CGPoint(x: 0, y: dy)
                gate.addChild(cone)
            }
            let ring = SKShapeNode(circleOfRadius: 30)
            ring.strokeColor = Palette.amber
            ring.lineWidth = 3
            ring.fillColor = Palette.amber.withAlphaComponent(0.12)
            ring.name = "ring"
            ring.alpha = i == 0 ? 1 : 0.35
            gate.addChild(ring)
            let number = makeLabel("\(i + 1)", size: 18)
            gate.addChild(number)
            addChild(gate)
            gates.append(gate)
        }
        gateIndex = 0
        pulse(gates.first)
    }

    private func pulse(_ gate: SKNode?) {
        guard let ring = gate?.childNode(withName: "ring") else { return }
        ring.alpha = 1
        ring.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.4), .scale(to: 1, duration: 0.4)])), withKey: "pulse")
    }

    private func placePassingFriends(except user: Player) {
        let spots = [CGPoint(x: 150, y: 170), CGPoint(x: 280, y: -110), CGPoint(x: -10, y: -210)]
        let friends = players.filter { $0 !== user && $0.side == .home }
        friendSpots = [:]
        for (i, friend) in friends.enumerated() where i < spots.count {
            friend.position = spots[i]
            friendSpots[ObjectIdentifier(friend)] = spots[i]
            let circle = SKShapeNode(circleOfRadius: 40)
            circle.strokeColor = Palette.amber
            circle.lineWidth = 3
            circle.fillColor = Palette.amber.withAlphaComponent(0.12)
            circle.position = spots[i]
            circle.zPosition = 2
            circle.name = "drill"
            circle.run(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.5), .scale(to: 1, duration: 0.5)])))
            addChild(circle)
        }
    }

    // MARK: Each frame

    /// Returns true when the drill has just ended.
    func drillTick() -> Bool {
        guard let drill else { return false }
        if drill == .dribbling, let user = drillPlayer, gateIndex < gates.count,
           holder === user, user.position.distance(to: gates[gateIndex].position) < 42 {
            passGate()
        }
        if drillDone || clock >= drill.seconds {
            finishDrill()
            return true
        }
        return false
    }

    private func passGate() {
        let gate = gates[gateIndex]
        if let ring = gate.childNode(withName: "ring") as? SKShapeNode {
            ring.removeAction(forKey: "pulse")
            ring.setScale(1)
            ring.strokeColor = UIColor.green
            ring.fillColor = UIColor.green.withAlphaComponent(0.2)
            ring.alpha = 0.6
        }
        Sound.shared.play(.post, volume: 0.6)
        drillScore += 1
        gateIndex += 1
        if gateIndex >= gates.count {
            drillDone = true
            drillTime = clock
        } else {
            pulse(gates[gateIndex])
            showMessage("Gate \(gateIndex)!", size: 32, hold: 0.5)
        }
    }

    /// Friends in the passing drill stand in their circles and pass straight back.
    func drillVelocity(_ p: Player) -> CGPoint? {
        guard drill == .passing, p.side == .home, p !== drillPlayer, let spot = friendSpots[ObjectIdentifier(p)] else { return nil }
        if holder === p {
            if p.holdTime > 0.5, let user = drillPlayer { pass(p, to: user) }
            return .zero
        }
        return arrive(p, spot, 160)
    }

    func drillPickedUp(_ p: Player) {
        if drill == .passing, p.side == .home, p !== drillPlayer, lastKicker === drillPlayer {
            drillScore += 1
            Sound.shared.play(.post, volume: 0.5)
            showMessage("Pass \(drillScore)!", size: 34, hold: 0.5)
        }
        if (drill == .shooting || isPractice) && p.side == .away {
            showMessage("Saved!", size: 40)
            resetDrillBall(after: 0.9)
        }
    }

    /// Goals and balls that leave the pitch during practice and drills.
    func drillCheckOut(x: CGFloat, y: CGFloat) {
        if abs(x) > halfLength && abs(y) < goalHalf {
            if drill == .shooting || isPractice {
                drillScore += 1
                shakeNet(x > 0 ? 1 : -1)
                Sound.shared.play(.net)
                Sound.shared.play(.cheer, volume: 0.6)
                cheer(.home)
                Haptics.goal()
                showMessage("GOAL!", size: 54)
            }
            resetDrillBall(after: 1.2)
            return
        }
        if abs(x) > halfLength || abs(y) > halfWidth {
            resetDrillBall(after: 0.3)
        }
    }

    func resetDrillBall(after delay: TimeInterval) {
        phase = .restart
        restartTimer = delay + 0.4
        holder = nil
        ballVelocity = .zero
        ballHeight = 0
        ballLift = 0
        after(delay) { [weak self] in
            guard let self, self.phase == .restart else { return }
            guard let user = self.drillPlayer ?? self.controlled ?? self.players.first(where: { $0.side == .home }) else { return }
            if self.drill == .shooting {
                user.position = CGPoint(x: CGFloat.random(in: 60...220), y: CGFloat.random(in: -150...150))
            } else if self.isPractice {
                user.position = CGPoint(x: -40, y: CGFloat.random(in: -100...100))
            } else {
                user.position = CGPoint(x: clamp(user.position.x, -self.halfLength + 40, self.halfLength - 40),
                                        y: clamp(user.position.y, -self.halfWidth + 40, self.halfWidth - 40))
            }
            if let keeper = self.keeper(of: .away) {
                keeper.position = self.worldSpot(keeper, kickoff: false)
                keeper.velocity = .zero
            }
            user.facing = CGPoint(x: 1, y: 0)
            user.updateNose()
            user.velocity = .zero
            self.holder = user
            self.lastTouch = .home
            self.setControlled(user)
            self.protectTimer = 0.6
        }
    }

    // MARK: Finish

    var drillScoreText: String {
        switch drill {
        case .shooting: return "\(drillScore) goal\(drillScore == 1 ? "" : "s")"
        case .dribbling: return "\(drillScore) of 6 gates" + (drillDone ? " in \(Int(drillTime)) s" : "")
        case .passing: return "\(drillScore) pass\(drillScore == 1 ? "" : "es")"
        case nil: return "\(drillScore) goal\(drillScore == 1 ? "" : "s")"
        }
    }

    var drillStars: Int {
        drill?.stars(score: drillScore, time: drillDone ? drillTime : clock) ?? 0
    }

    func finishDrill() {
        guard phase != .closing && phase != .done else { return }
        phase = .closing
        flowReady = false
        holder = nil
        ballVelocity = .zero
        if !drillDone { drillTime = clock }
        controlled?.isControlled = false
        whistle(long: true)
        let stars = drillStars
        let starText = String(repeating: "★", count: stars) + String(repeating: "☆", count: 3 - stars)
        showBanner(title: "\(drill?.title ?? "Training") done!  \(starText)", subtitle: drillScoreText, hint: "Tap to finish")
        if stars >= 2 {
            confettiRain()
            Sound.shared.play(.cheer)
            for k in 0..<4 {
                after(0.3 + Double(k) * 0.5) { [weak self] in
                    self?.fireworks(at: CGPoint(x: CGFloat.random(in: -300...300), y: CGFloat.random(in: 120...220)))
                }
            }
        }
        after(1.2) { [weak self] in self?.flowReady = true }
    }

    /// Practice has no clock: it ends from the pause menu.
    func endPractice() {
        guard isPractice else { return }
        drillTime = clock
        finishMatch()
    }

    var drillStatus: (String, String) {
        if isPractice { return ("Practice  ·  \(drillScoreText)", "Pause to finish") }
        let left = max(0, Int(((drill?.seconds ?? 0) - clock).rounded(.up)))
        return ("\(drill?.title ?? "Training")  ·  \(drillScoreText)", "\(left) s left")
    }
}
