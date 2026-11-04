//
//  Ceremonies.swift
//  CRS Soccer Field
//
//  The parts around the football: the opening ceremony (teams walk out,
//  fireworks, fans cheering), the half-time show (a marching band and the
//  stats), and the closing ceremony (line-up, trophy, confetti).
//

import Foundation
import SpriteKit
import UIKit

extension GameScene {
    // MARK: Opening ceremony

    /// Before kick-off: the locker room team talk, the players on the benches,
    /// the walk-out with the referee carrying the ball, high fives along the
    /// line, fireworks and card displays, then the referee spins the ball on
    /// one finger and places it on the centre spot. Tap at any time to skip.
    func startOpening() {
        phase = .opening
        flowReady = false
        ball.isHidden = true
        focus = CGPoint(x: 0, y: -halfWidth * 0.55)
        zoom = 1.1
        referee.position = CGPoint(x: 0, y: -halfWidth - 70)
        refereeHasBall = true
        refereeSpinning = false

        // On the benches first
        for side in [Side.home, Side.away] {
            for (i, p) in players(of: side).enumerated() {
                p.position = benchSeat(p, index: i)
                p.facing = CGPoint(x: 0, y: 1)
                p.updateNose()
                p.figure.yScale = 0.84
            }
        }
        showLockerRoom()
        Sound.shared.crowdLevel(0.3)

        after(4.8) { [weak self] in
            guard let self else { return }
            self.hideLockerRoom()
            let stage = self.settings.stage.map { "\($0)  ·  " } ?? ""
            self.showBanner(title: "Opening Ceremony", subtitle: "\(stage)\(self.settings.homeName)  vs  \(self.settings.awayName)", hint: "Tap to skip")
            self.showMessage("On the bench", size: 30, hold: 1.4)
        }
        after(7.0) { [weak self] in self?.walkOut() }
        after(10.0) { [weak self] in self?.lineUpHighFives() }
        after(12.2) { [weak self] in
            guard let self else { return }
            self.refereeSpinning = true
            self.showMessage("Ready?", size: 40, hold: 1.0)
        }
        after(13.8) { [weak self] in self?.finishOpening() }
    }

    private func walkOut() {
        guard phase == .opening else { return }
        removeBanner()
        focus = CGPoint(x: 0, y: -halfWidth * 0.2)
        zoom = 1.25
        for side in [Side.home, Side.away] {
            let sign: CGFloat = side == .home ? -1 : 1
            for (i, p) in players(of: side).enumerated() {
                p.figure.yScale = 1
                let lineup = CGPoint(x: sign * (60 + CGFloat(i) * 46), y: -30)
                p.run(.sequence([.wait(forDuration: Double(i) * 0.15), .move(to: lineup, duration: 2.2)]))
            }
        }
        // The referee leads them out, carrying the ball.
        referee.run(.move(to: CGPoint(x: 0, y: -30), duration: 2.0))
        Sound.shared.play(.cheer)
        Sound.shared.crowdLevel(0.42)
        cheer(.home)
        cheer(.away)
        after(0.6) { [weak self] in
            guard let self else { return }
            self.cardDisplay(for: .home, text: self.settings.homeName)
            self.cardDisplay(for: .away, text: self.settings.awayName)
        }
        for t in [0.8, 1.3, 1.8, 2.3] {
            after(t) { [weak self] in
                guard let self else { return }
                self.fireworks(at: CGPoint(x: CGFloat.random(in: -420...420), y: self.halfWidth + 110))
            }
        }
    }

    /// Players along the line high-five each other, then the crowd does a wave.
    private func lineUpHighFives() {
        guard phase == .opening else { return }
        for (k, p) in players.enumerated() {
            after(Double(k % 5) * 0.15) { [weak p] in p?.highFive() }
        }
        Sound.shared.play(.clap)
        after(0.3) { Sound.shared.play(.clap) }
        after(0.6) { Sound.shared.play(.clap) }
        mexicanWave()
        Sound.shared.play(.cheer, volume: 0.8)
    }

    func skipOpening() {
        finishOpening()
    }

    func finishOpening() {
        guard phase == .opening else { return }
        cancelTimers()
        hideLockerRoom()
        removeBanner()
        referee.removeAllActions()
        for p in players { p.figure.yScale = 1 }
        refereeHasBall = false
        refereeSpinning = false
        refereeFigure?.heldPose = nil
        Sound.shared.crowdLevel(0.22)
        kickoffFirstHalf = .home
        kickoff(by: .home)
    }

    // MARK: Locker room

    /// The home team's locker room: lockers with the players' names, team
    /// flags and bunting, and the manager and mentor giving the team talk.
    func showLockerRoom() {
        hideLockerRoom()
        let w = size.width, h = size.height
        let room = SKNode()
        room.name = "locker"
        room.zPosition = 60

        let wall = SKSpriteNode(color: UIColor(red: 0.16, green: 0.2, blue: 0.3, alpha: 1), size: CGSize(width: w, height: h))
        room.addChild(wall)
        let floor = SKSpriteNode(color: UIColor(red: 0.45, green: 0.3, blue: 0.18, alpha: 1), size: CGSize(width: w, height: h * 0.32))
        floor.position = CGPoint(x: 0, y: -h / 2 + h * 0.16)
        room.addChild(floor)
        for k in 0..<12 {
            let board = SKSpriteNode(color: UIColor(red: 0.38, green: 0.25, blue: 0.15, alpha: 1), size: CGSize(width: w, height: 2))
            board.position = CGPoint(x: 0, y: -h / 2 + CGFloat(k) * h * 0.027)
            room.addChild(board)
        }

        let team = settings.homeColor
        let names = squad(.home)
        let numbers = Rosters.home.map(\.number)
        let lockerWidth = min(110, w / 8)
        let lockerHeight = h * 0.4
        let lockerY = h * 0.02
        for i in 0..<5 {
            let x = (CGFloat(i) - 2) * (lockerWidth + 14)
            let locker = SKShapeNode(rect: CGRect(x: -lockerWidth / 2, y: -lockerHeight / 2, width: lockerWidth, height: lockerHeight), cornerRadius: 6)
            locker.fillColor = team.withAlphaComponent(0.85)
            locker.strokeColor = .white
            locker.lineWidth = 2
            locker.position = CGPoint(x: x, y: lockerY)
            for v in 0..<4 {
                let vent = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.25), size: CGSize(width: lockerWidth * 0.5, height: 3))
                vent.position = CGPoint(x: 0, y: lockerHeight / 2 - 18 - CGFloat(v) * 8)
                locker.addChild(vent)
            }
            let plate = SKShapeNode(rect: CGRect(x: -lockerWidth * 0.42, y: -12, width: lockerWidth * 0.84, height: 24), cornerRadius: 4)
            plate.fillColor = .white
            plate.strokeColor = .clear
            plate.position = CGPoint(x: 0, y: lockerHeight * 0.12)
            let plateText = SKLabelNode(text: "\(names[i].uppercased()) \(numbers[i])")
            plateText.fontName = "AvenirNext-Heavy"
            plateText.fontSize = 12
            plateText.fontColor = team
            plateText.verticalAlignmentMode = .center
            if plateText.frame.width > lockerWidth * 0.8 { plateText.setScale(lockerWidth * 0.8 / plateText.frame.width) }
            plate.addChild(plateText)
            locker.addChild(plate)
            room.addChild(locker)

            // The player standing at their locker
            if let p = players.first(where: { $0.side == .home && $0.playerName == names[i] }) ?? players(of: .home).dropFirst(i).first {
                let figure = Figure(frames: FigureArt.frames(kit: p.kit, look: p.look))
                figure.setScale(1.7)
                figure.position = CGPoint(x: x, y: -h / 2 + h * 0.2)
                figure.xScale = i < 2 ? 1.7 : -1.7
                room.addChild(figure)
            }
        }

        // Bunting across the top
        let flags = 18
        for k in 0..<flags {
            let x = -w / 2 + w * (CGFloat(k) + 0.5) / CGFloat(flags)
            let tri = CGMutablePath()
            tri.move(to: CGPoint(x: -12, y: 0))
            tri.addLine(to: CGPoint(x: 12, y: 0))
            tri.addLine(to: CGPoint(x: 0, y: -22))
            tri.closeSubpath()
            let pennant = SKShapeNode(path: tri)
            pennant.fillColor = k % 2 == 0 ? team : .white
            pennant.strokeColor = .clear
            pennant.position = CGPoint(x: x, y: h / 2 - 10)
            room.addChild(pennant)
        }

        // Big flags: the team, CRS and today's opponents
        let flagSpecs: [(String, UIColor, UIColor)] = [
            (settings.homeName.uppercased(), team, .white),
            ("CRS", Palette.amber, UIColor(red: 0.08, green: 0.1, blue: 0.2, alpha: 1)),
            (settings.awayName.uppercased(), settings.awayColor, .white),
        ]
        for (k, spec) in flagSpecs.enumerated() {
            let flag = SKShapeNode(rect: CGRect(x: -70, y: -24, width: 140, height: 48), cornerRadius: 3)
            flag.fillColor = spec.1
            flag.strokeColor = .white
            flag.lineWidth = 2
            let x: CGFloat = k == 0 ? -w * 0.36 : (k == 1 ? 0 : w * 0.36)
            flag.position = CGPoint(x: x, y: h / 2 - 62)
            let stripe = SKSpriteNode(color: spec.2.withAlphaComponent(0.35), size: CGSize(width: 140, height: 8))
            flag.addChild(stripe)
            let label = SKLabelNode(text: spec.0)
            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 18
            label.fontColor = spec.2
            label.verticalAlignmentMode = .center
            if label.frame.width > 128 { label.setScale(128 / label.frame.width) }
            flag.addChild(label)
            flag.run(.repeatForever(.sequence([.scaleY(to: 0.9, duration: 0.9), .scaleY(to: 1, duration: 0.9)])))
            room.addChild(flag)
        }

        // Manager and mentor with the team talk
        let staffNames = Rosters.homeStaff
        let suit = Kit(shirt: UIColor(white: 0.2, alpha: 1), shorts: UIColor(white: 0.15, alpha: 1), socks: UIColor(white: 0.15, alpha: 1),
                       gloves: nil, trousers: UIColor(white: 0.15, alpha: 1))
        let tracksuit = Kit(shirt: team, shorts: UIColor(white: 0.15, alpha: 1), socks: UIColor(white: 0.15, alpha: 1),
                            gloves: nil, trousers: UIColor(white: 0.18, alpha: 1))
        let talks = [
            ("Manager \(staffNames.manager)", "Play together, have fun, and never give up!", suit, -w * 0.34),
            ("Mentor \(staffNames.mentor)", "Drink water, stretch, and pass to a friend!", tracksuit, w * 0.34),
        ]
        for (k, talk) in talks.enumerated() {
            let figure = Figure(frames: FigureArt.frames(kit: talk.2, look: Look(skin: Look.skins[k == 0 ? 2 : 0], hair: Look.hairs[k])))
            figure.setScale(1.8)
            figure.xScale = k == 0 ? 1.8 : -1.8
            figure.position = CGPoint(x: talk.3, y: -h / 2 + h * 0.18)
            figure.heldPose = .point
            figure.animate(at: .zero, facing: CGPoint(x: k == 0 ? 1 : -1, y: 0), dt: 0)
            figure.xScale = k == 0 ? 1.8 : -1.8
            room.addChild(figure)
            let bubble = SKShapeNode(rect: CGRect(x: -120, y: -26, width: 240, height: 52), cornerRadius: 14)
            bubble.fillColor = .white
            bubble.strokeColor = team
            bubble.lineWidth = 2
            bubble.position = CGPoint(x: talk.3, y: -h / 2 + h * 0.2 + 150)
            let who = SKLabelNode(text: talk.0)
            who.fontName = "AvenirNext-Heavy"
            who.fontSize = 12
            who.fontColor = team
            who.position = CGPoint(x: 0, y: 8)
            bubble.addChild(who)
            let words = SKLabelNode(text: talk.1)
            words.fontName = "AvenirNext-DemiBold"
            words.fontSize = 12
            words.fontColor = UIColor(white: 0.15, alpha: 1)
            words.position = CGPoint(x: 0, y: -12)
            if words.frame.width > 228 { words.setScale(228 / words.frame.width) }
            bubble.addChild(words)
            bubble.setScale(0)
            bubble.run(.sequence([.wait(forDuration: 0.4 + Double(k) * 1.2), .scale(to: 1, duration: 0.25)]))
            room.addChild(bubble)
        }

        let title = makeLabel("Locker room  ·  Team talk", size: 26, color: .white)
        title.position = CGPoint(x: 0, y: h / 2 - 118)
        room.addChild(title)
        let hint = makeLabel("Tap to skip", size: 14, color: UIColor.white.withAlphaComponent(0.8))
        hint.position = CGPoint(x: 0, y: -h / 2 + 24)
        room.addChild(hint)

        room.alpha = 0
        hud.addChild(room)
        room.run(.fadeIn(withDuration: 0.3))
    }

    func hideLockerRoom() {
        guard let room = hud.childNode(withName: "locker") else { return }
        room.name = nil
        room.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: Half-time

    func startHalfTime() {
        phase = .halfTime
        flowReady = false
        controlled?.isControlled = false
        ball.position = .zero
        focus = .zero
        zoom = 1.2
        showMessage("Half-time!", size: 54, hold: 1.4)
        for p in players {
            p.removeAllActions()
            let tunnel = CGPoint(x: p.side == .home ? -30 : 30, y: -halfWidth - 60)
            p.run(.move(to: tunnel, duration: 2.2))
        }
        referee.run(.move(to: CGPoint(x: 0, y: -halfWidth - 60), duration: 2.2))
        marchingBand()
        mexicanWave()
        after(1.6) { [weak self] in
            guard let self else { return }
            let total = max(self.ballTime[0] + self.ballTime[1], 1)
            let homeShare = Int((self.ballTime[0] / total * 100).rounded())
            let line = "\(self.score[0]) – \(self.score[1])   ·   Shots \(self.shots[0]) – \(self.shots[1])   ·   Ball \(homeShare)% – \(100 - homeShare)%"
            self.showBanner(title: "Half-time", subtitle: line, hint: "Tap to play the second half")
            self.flowReady = true
        }
    }

    func startSecondHalf() {
        guard phase == .halfTime else { return }
        removeBanner()
        childNode(withName: "band")?.removeFromParent()
        cancelTimers()
        half = 2
        clock = 0
        for p in players { p.stamina = 1 }
        kickoff(by: kickoffFirstHalf.other)
        showMessage("Second half!", size: 48)
    }

    private func marchingBand() {
        let band = SKNode()
        band.name = "band"
        band.zPosition = 8
        addChild(band)
        for i in 0..<10 {
            let musician = SKSpriteNode(texture: Art.dot, size: CGSize(width: 24, height: 24))
            musician.color = Palette.party[i % Palette.party.count]
            musician.colorBlendFactor = 1
            let row = CGFloat(i % 2)
            musician.position = CGPoint(x: -halfLength + 40 - CGFloat(i / 2) * 40, y: 60 - row * 40)
            band.addChild(musician)
            let bob = SKAction.sequence([.moveBy(x: 0, y: 6, duration: 0.25), .moveBy(x: 0, y: -6, duration: 0.25)])
            musician.run(.repeatForever(bob))
            musician.run(.moveBy(x: 2 * halfLength + 200, y: 0, duration: 9))
        }
        for k in 0..<12 {
            after(Double(k) * 0.6) { [weak self, weak band] in
                guard let self, let band, band.parent != nil else { return }
                let note = makeLabel(["♪", "♫"].randomElement() ?? "♪", size: 30, color: Palette.party.randomElement() ?? .white)
                let x = -self.halfLength + 40 + CGFloat(k) * 0.6 * (2 * self.halfLength + 200) / 9
                note.position = CGPoint(x: x, y: 100)
                band.addChild(note)
                note.run(.sequence([.group([.moveBy(x: 0, y: 60, duration: 1.2), .fadeOut(withDuration: 1.2)]), .removeFromParent()]))
            }
        }
    }

    // MARK: Full time and closing ceremony

    func startFullTime() {
        phase = .fullTime
        controlled?.isControlled = false
        showMessage("Full time!", size: 56, hold: 1.6)
        after(1.1) { [weak self] in self?.whistle(long: true) }
        after(2.0) { [weak self] in self?.startClosing() }
    }

    private func startClosing() {
        phase = .closing
        flowReady = false
        ball.isHidden = true
        focus = CGPoint(x: 0, y: 20)
        zoom = 1.2
        let winner: Side?
        if score[0] > score[1] { winner = .home } else if score[1] > score[0] { winner = .away } else { winner = nil }

        for side in [Side.home, Side.away] {
            let front = winner == nil ? side == .home : side == winner
            let rowY: CGFloat = front ? 40 : -90
            for (i, p) in players(of: side).enumerated() {
                p.removeAllActions()
                p.setScale(1)
                p.facing = CGPoint(x: 0, y: -1)
                p.updateNose()
                p.run(.move(to: CGPoint(x: (CGFloat(i) - 2) * 56, y: rowY), duration: 1.6))
            }
        }
        referee.run(.move(to: CGPoint(x: 0, y: -170), duration: 1.6))

        let trophy = SKLabelNode(text: "🏆")
        trophy.fontSize = 96
        trophy.verticalAlignmentMode = .center
        trophy.position = CGPoint(x: 0, y: 150)
        trophy.zPosition = 30
        trophy.setScale(0.1)
        trophy.name = "trophy"
        addChild(trophy)
        trophy.run(.sequence([.wait(forDuration: 1.2), .scale(to: 1.15, duration: 0.35), .scale(to: 1, duration: 0.15)]))
        trophy.run(.repeatForever(.sequence([.rotate(toAngle: 0.08, duration: 0.6), .rotate(toAngle: -0.08, duration: 0.6)])))

        let title: String
        switch winner {
        case .home: title = "\(settings.homeName) win!"
        case .away: title = "\(settings.awayName) win!"
        case nil: title = "It's a draw!"
        }
        let r = result()
        var line = "Final score \(r.home) – \(r.away)"
        if let star = r.starPlayer { line += "   ·   Star player: \(star), \(r.starGoals) goal\(r.starGoals == 1 ? "" : "s")" }
        showBanner(title: title, subtitle: line, hint: "Tap to finish")

        confettiRain()
        if let winner { cardDisplay(for: winner, text: "WINNERS") } else {
            cardDisplay(for: .home, text: "WELL DONE")
            cardDisplay(for: .away, text: "WELL DONE")
        }
        after(2.0) { [weak self] in self?.mexicanWave() }
        Sound.shared.play(.cheer)
        Sound.shared.crowdLevel(0.45)
        after(3.0) { Sound.shared.play(.cheer, volume: 0.85) }
        if let winner { cheer(winner) } else { cheer(.home); cheer(.away) }
        for k in 0..<9 {
            after(0.6 + Double(k) * 0.55) { [weak self] in
                guard let self else { return }
                let x = CGFloat.random(in: -380...380)
                let y = CGFloat.random(in: 160...260)
                self.fireworks(at: CGPoint(x: x, y: y))
            }
        }
        after(1.8) { [weak self] in
            guard let self else { return }
            for p in self.players where winner == nil || p.side == winner { p.celebrate() }
        }
        after(2.5) { [weak self] in self?.flowReady = true }
    }

    // MARK: Effects

    func fireworks(at point: CGPoint) {
        let e = SKEmitterNode()
        e.particleTexture = Art.spark
        e.particleBirthRate = 3000
        e.numParticlesToEmit = 150
        e.particleLifetime = 1.4
        e.particleLifetimeRange = 0.5
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 240
        e.particleSpeedRange = 90
        e.yAcceleration = -90
        e.particleAlphaSpeed = -0.7
        e.particleScale = 0.7
        e.particleScaleRange = 0.3
        e.particleScaleSpeed = -0.25
        e.particleColorBlendFactor = 1
        e.particleColor = Palette.party.randomElement() ?? .white
        e.particleBlendMode = .add
        e.position = point
        e.zPosition = 50
        addChild(e)
        e.run(.sequence([.wait(forDuration: 3), .removeFromParent()]))
    }

    func confettiRain() {
        let e = SKEmitterNode()
        e.particleTexture = Art.confetti
        e.particleBirthRate = 140
        e.numParticlesToEmit = 900
        e.particleLifetime = 5
        e.particleLifetimeRange = 1.5
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = .pi / 4
        e.particleSpeed = 120
        e.particleSpeedRange = 60
        e.yAcceleration = -60
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = 4
        e.particleScale = 1.2
        e.particleScaleRange = 0.5
        e.particleColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        e.particleColorBlendFactor = 1
        e.particleColorRedRange = 1
        e.particleColorGreenRange = 1
        e.particleColorBlueRange = 1
        e.particlePositionRange = CGVector(dx: size.width, dy: 0)
        e.position = CGPoint(x: 0, y: size.height / 2 + 10)
        e.zPosition = 15
        e.name = "confetti"
        hud.addChild(e)
    }

    // MARK: Banner

    func showBanner(title: String, subtitle: String, hint: String?) {
        removeBanner()
        let width = min(size.width - 80, 680)
        let panel = SKShapeNode(rect: CGRect(x: -width / 2, y: -72, width: width, height: 144), cornerRadius: 22)
        panel.fillColor = UIColor(white: 0.05, alpha: 0.82)
        panel.strokeColor = Palette.amber
        panel.lineWidth = 3
        panel.name = "banner"
        panel.zPosition = 20
        panel.position = CGPoint(x: 0, y: size.height * 0.17)

        let titleLabel = makeLabel(title, size: 38, color: Palette.amber)
        titleLabel.position = CGPoint(x: 0, y: 30)
        panel.addChild(titleLabel)
        let subtitleLabel = makeLabel(subtitle, size: 19)
        subtitleLabel.position = CGPoint(x: 0, y: -10)
        panel.addChild(subtitleLabel)
        let room = width - 40
        if subtitleLabel.frame.width > room { subtitleLabel.setScale(room / subtitleLabel.frame.width) }
        if titleLabel.frame.width > room { titleLabel.setScale(room / titleLabel.frame.width) }
        if let hint {
            let hintLabel = makeLabel(hint, size: 15, color: UIColor.white.withAlphaComponent(0.8))
            hintLabel.position = CGPoint(x: 0, y: -48)
            hintLabel.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])))
            panel.addChild(hintLabel)
        }
        hud.addChild(panel)
        panel.alpha = 0
        panel.setScale(0.7)
        panel.run(.group([.fadeIn(withDuration: 0.25), .scale(to: 1, duration: 0.3)]))
    }

    func removeBanner() {
        hud.childNode(withName: "banner")?.removeFromParent()
    }
}
