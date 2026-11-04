//
//  GameScene.swift
//  CRS Soccer Field
//
//  The match: a five-a-side pitch seen from above, fans in the stands, a
//  referee, a scoreboard and clock, and the rules a young player expects:
//  goals, throw-ins, corners, goal kicks, half-time and full time.
//
//  Controls: drag on the left half to run. KICK shoots at goal (or boots the
//  ball upfield when you're far away). PASS finds a teammate. Without the ball,
//  KICK becomes DASH (a quick sprint to win it back) and PASS becomes SWITCH.
//

import Foundation
import SpriteKit
import UIKit

final class GameScene: SKScene {
    // MARK: Field size (points, centre at 0,0)

    let halfLength: CGFloat = 560
    let halfWidth: CGFloat = 340
    let goalHalf: CGFloat = 95
    let standDepth: CGFloat = 170

    // MARK: Match state

    enum Phase { case opening, restart, playing, goal, halfTime, fullTime, closing, done }

    let settings: MatchSettings
    var onFinish: ((MatchResult) -> Void)?

    var phase: Phase = .opening
    var half = 1
    var clock: TimeInterval = 0
    var score = [0, 0]
    var shots = [0, 0]
    var ballTime: [TimeInterval] = [0, 0]
    var lastTouch: Side = .home
    var kickoffFirstHalf: Side = .home
    var restartTimer: TimeInterval = 0
    var protectTimer: TimeInterval = 0
    var flowReady = false

    var players: [Player] = []
    // Practice and training
    var drillScore = 0
    var drillDone = false
    var drillTime: TimeInterval = 0
    var gates: [SKNode] = []
    var gateIndex = 0
    weak var drillPlayer: Player?
    var friendSpots: [ObjectIdentifier: CGPoint] = [:]
    weak var holder: Player?
    weak var lastKicker: Player?
    weak var controlled: Player?

    /// The ball's spot on the grass. Its picture (`ballImage`) rises above it when the ball is in the air.
    let ball = SKSpriteNode(color: .clear, size: CGSize(width: 2, height: 2))
    let ballImage = SKSpriteNode(texture: Art.ball, size: CGSize(width: 20, height: 20))
    var ballHeight: CGFloat = 0
    var ballLift: CGFloat = 0
    let ballShadow = SKShapeNode(ellipseOf: CGSize(width: 18, height: 10))
    var ballVelocity = CGPoint.zero
    var ballFrames: [SKTexture] = []
    var ballRoll: CGFloat = 0
    var lastBallPosition = CGPoint.zero
    var waveTimer: TimeInterval = 0
    var crowdColumns = 0
    // Power meter
    enum Charge { case kick, pass }
    var charging: Charge?
    var chargeStart: TimeInterval = 0
    weak var kickTouch: UITouch?
    weak var passTouch: UITouch?
    let powerMeter = SKNode()
    let meterFill = SKSpriteNode(color: .yellow, size: CGSize(width: 52, height: 8))
    var wantBicycleUntil: TimeInterval = 0
    var slideUntil: TimeInterval = 0
    /// How much harder the other team plays when you're on top (0 to 0.35).
    var aiBoost: CGFloat = 0
    // Staff, benches, mini-map, referee with the ball
    var managers: [Side: Figure] = [:]
    var staffNodes: [SKNode] = []
    var staffTimer: TimeInterval = 0
    let miniMap = SKShapeNode()
    var mapMarkers: [ObjectIdentifier: SKShapeNode] = [:]
    let mapBall = SKShapeNode(circleOfRadius: 2.6)
    var refereeHasBall = false
    var refereeSpinning = false
    let skillButton = SKShapeNode(circleOfRadius: 34)
    let skillLabel = makeLabel("SKILL", size: 13)
    let referee = SKNode()
    var refereeFigure: Figure?
    /// The two goals, each with its origin on the goal line so the net can bulge outward.
    var goalNets: [CGFloat: SKNode] = [:]
    var fans: [Fan] = []

    // MARK: Camera and HUD

    let cam = SKCameraNode()
    var zoom: CGFloat = 1
    var focus: CGPoint?
    let hud = SKNode()
    let scoreBoard = SKShapeNode()
    let scoreLabel = makeLabel("", size: 22)
    let clockLabel = makeLabel("", size: 15)
    let messageLabel = makeLabel("", size: 56)
    let stickBase = SKShapeNode(circleOfRadius: 64)
    let stickKnob = SKShapeNode(circleOfRadius: 30)
    let kickButton = SKShapeNode(circleOfRadius: 58)
    let passButton = SKShapeNode(circleOfRadius: 44)
    let kickLabel = makeLabel("KICK", size: 22)
    let passLabel = makeLabel("PASS", size: 17)
    var stickTouch: UITouch?
    var stickOrigin = CGPoint.zero
    var stick = CGPoint.zero
    var lastUpdate: TimeInterval = 0
    var built = false
    /// Game time, used for delayed steps (ceremonies, kick-offs). Stops while paused.
    var now: TimeInterval = 0
    private var timers: [(at: TimeInterval, work: () -> Void)] = []

    /// Runs `work` after `seconds` of game time, on the next frame after it's due.
    func after(_ seconds: TimeInterval, _ work: @escaping () -> Void) {
        timers.append((now + seconds, work))
    }

    func cancelTimers() { timers.removeAll() }

    private func runTimers() {
        guard !timers.isEmpty else { return }
        let due = timers.filter { $0.at <= now }
        guard !due.isEmpty else { return }
        timers.removeAll { $0.at <= now }
        for item in due { item.work() }
    }

    init(settings: MatchSettings) {
        self.settings = settings
        super.init(size: CGSize(width: 1024, height: 768))
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.stands
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var halfLengthSeconds: TimeInterval { settings.minutesPerHalf * 60 }

    // MARK: Setup

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        Sound.shared.start()
        guard !built else { return }
        built = true
        buildPitch()
        buildCrowd()
        buildPlayers()
        buildBallAndReferee()
        if settings.mode == .match { buildBenchesAndStaff() }
        buildPowerMeter()
        ballFrames = Art.ballFrames(settings.ball)
        ballImage.texture = ballFrames.first
        camera = cam
        addChild(cam)
        buildHUD()
        layoutHUD()
        if settings.mode == .match { startOpening() } else { startDrill() }
    }

    override func willMove(from view: SKView) {
        Sound.shared.stop()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard built else { return }
        layoutHUD()
    }

    private func buildPitch() {
        let outer = CGSize(width: 2 * (halfLength + 40), height: 2 * (halfWidth + 40))
        let turf = SKSpriteNode(texture: Art.grass(size: outer, stripes: 12), size: outer)
        turf.zPosition = -9
        addChild(turf)

        let path = CGMutablePath()
        path.addRect(CGRect(x: -halfLength, y: -halfWidth, width: 2 * halfLength, height: 2 * halfWidth))
        path.move(to: CGPoint(x: 0, y: -halfWidth))
        path.addLine(to: CGPoint(x: 0, y: halfWidth))
        path.addEllipse(in: CGRect(x: -85, y: -85, width: 170, height: 170))
        for sign in [CGFloat(-1), CGFloat(1)] {
            let lineX = sign * halfLength
            let boxX = sign > 0 ? lineX - 150 : lineX
            path.addRect(CGRect(x: boxX, y: -220, width: 150, height: 440))
            let smallX = sign > 0 ? lineX - 55 : lineX
            path.addRect(CGRect(x: smallX, y: -125, width: 55, height: 250))
        }
        let lines = SKShapeNode(path: path)
        lines.strokeColor = UIColor.white.withAlphaComponent(0.9)
        lines.lineWidth = 4
        lines.zPosition = -8
        addChild(lines)

        let spot = SKShapeNode(circleOfRadius: 5)
        spot.fillColor = .white
        spot.strokeColor = .clear
        spot.zPosition = -8
        addChild(spot)

        for sign in [CGFloat(-1), CGFloat(1)] {
            let depth: CGFloat = 38
            // Origin on the goal line; the net is drawn outward from it.
            let goal = SKNode()
            goal.position = CGPoint(x: sign * halfLength, y: 0)
            goal.zPosition = -7
            addChild(goal)
            let x = sign > 0 ? 0 : -depth
            let net = SKShapeNode(rect: CGRect(x: x, y: -goalHalf, width: depth, height: 2 * goalHalf), cornerRadius: 4)
            net.fillColor = UIColor.white.withAlphaComponent(0.25)
            net.strokeColor = UIColor.white.withAlphaComponent(0.8)
            net.lineWidth = 2
            net.name = "netFill"
            goal.addChild(net)
            let mesh = CGMutablePath()
            var y = -goalHalf + 14
            while y < goalHalf {
                mesh.move(to: CGPoint(x: x, y: y))
                mesh.addLine(to: CGPoint(x: x + depth, y: y))
                y += 14
            }
            var mx = x + 9.5
            while mx < x + depth {
                mesh.move(to: CGPoint(x: mx, y: -goalHalf))
                mesh.addLine(to: CGPoint(x: mx, y: goalHalf))
                mx += 9.5
            }
            let meshNode = SKShapeNode(path: mesh)
            meshNode.strokeColor = UIColor.white.withAlphaComponent(0.45)
            meshNode.lineWidth = 1
            goal.addChild(meshNode)
            // Posts and crossbar stay put when the net moves.
            let frame = CGMutablePath()
            frame.move(to: CGPoint(x: 0, y: -goalHalf))
            frame.addLine(to: CGPoint(x: x == 0 ? depth : -depth, y: -goalHalf))
            frame.move(to: CGPoint(x: 0, y: goalHalf))
            frame.addLine(to: CGPoint(x: x == 0 ? depth : -depth, y: goalHalf))
            let posts = SKShapeNode(path: frame)
            posts.strokeColor = .white
            posts.lineWidth = 5
            posts.zPosition = -6.5
            posts.position = goal.position
            addChild(posts)
            for postY in [-goalHalf, goalHalf] {
                let post = SKShapeNode(circleOfRadius: 6)
                post.fillColor = .white
                post.strokeColor = UIColor(white: 0.75, alpha: 1)
                post.position = CGPoint(x: sign * halfLength, y: postY)
                post.zPosition = -6
                addChild(post)
            }
            goalNets[sign] = goal
        }
    }

    private func buildPlayers() {
        let formation: [(Role, CGPoint, Int)] = [
            (.keeper, CGPoint(x: -0.93, y: 0), 1),
            (.defender, CGPoint(x: -0.55, y: -0.42), 2),
            (.defender, CGPoint(x: -0.55, y: 0.42), 3),
            (.midfielder, CGPoint(x: -0.18, y: 0.1), 8),
            (.forward, CGPoint(x: 0.2, y: -0.1), 9),
        ]
        // A blank name falls back to the default one.
        let homeNames = MatchSettings.split(MatchSettings.joined(settings.homePlayers), fallback: Rosters.home.map(\.name))
        let awayNames = MatchSettings.split(MatchSettings.joined(settings.awayPlayers), fallback: Rosters.away.map(\.name))
        let longHair: Set<String> = ["Ava", "Zara", "Mia", "Lily"]
        for side in [Side.home, Side.away] {
            for (i, slot) in formation.enumerated() {
                let isKeeper = slot.0 == .keeper
                let kit: Kit
                if side == .home {
                    kit = isKeeper
                        ? Kit(shirt: Palette.homeKeeper, shorts: UIColor(white: 0.15, alpha: 1), socks: Palette.homeKeeper, gloves: Palette.amber)
                        : Kit(shirt: settings.homeColor, shorts: .white, socks: settings.homeColor)
                } else {
                    kit = isKeeper
                        ? Kit(shirt: Palette.awayKeeper, shorts: UIColor(white: 0.15, alpha: 1), socks: Palette.awayKeeper, gloves: Palette.amber)
                        : Kit(shirt: settings.awayColor, shorts: UIColor(red: 0.12, green: 0.14, blue: 0.3, alpha: 1), socks: .white)
                }
                let name = side == .home ? homeNames[i] : awayNames[i]
                let skinIndex = (i * 2 + (side == .home ? 0 : 3)) % Look.skins.count
                let hairIndex = (i + (side == .home ? 1 : 2)) % Look.hairs.count
                let look = Look(skin: Look.skins[skinIndex], hair: Look.hairs[hairIndex], longHair: longHair.contains(name))
                let p = Player(side: side, role: slot.0, number: slot.2, name: name, spot: slot.1, kit: kit, look: look)
                guard keepForMode(p) else { continue }
                addChild(p)
                players.append(p)
            }
        }
    }

    private func buildBallAndReferee() {
        ballShadow.fillColor = UIColor.black.withAlphaComponent(0.25)
        ballShadow.strokeColor = .clear
        ballShadow.zPosition = 5.5
        addChild(ballShadow)
        ball.zPosition = 6
        ball.addChild(ballImage)
        addChild(ball)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 34, height: 12))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.25)
        shadow.strokeColor = .clear
        shadow.zPosition = -1
        referee.addChild(shadow)
        let refKit = Kit(shirt: UIColor(white: 0.1, alpha: 1), shorts: UIColor(white: 0.1, alpha: 1), socks: Palette.amber)
        let refLook = Look(skin: Look.skins[1], hair: Look.hairs[0])
        let figure = Figure(frames: FigureArt.frames(kit: refKit, look: refLook))
        referee.addChild(figure)
        refereeFigure = figure
        let badge = makeLabel("R", size: 11, color: Palette.amber)
        badge.position = CGPoint(x: 0, y: 30)
        badge.zPosition = 1
        referee.addChild(badge)
        referee.zPosition = 4
        addChild(referee)
    }

    private func buildHUD() {
        hud.zPosition = 100
        cam.addChild(hud)

        scoreBoard.fillColor = UIColor(white: 0.05, alpha: 0.75)
        scoreBoard.strokeColor = UIColor.white.withAlphaComponent(0.25)
        scoreBoard.lineWidth = 1.5
        hud.addChild(scoreBoard)
        scoreBoard.addChild(scoreLabel)
        scoreBoard.addChild(clockLabel)

        messageLabel.alpha = 0
        messageLabel.zPosition = 10
        hud.addChild(messageLabel)

        stickBase.fillColor = UIColor.white.withAlphaComponent(0.12)
        stickBase.strokeColor = UIColor.white.withAlphaComponent(0.45)
        stickBase.lineWidth = 3
        hud.addChild(stickBase)
        stickKnob.fillColor = UIColor.white.withAlphaComponent(0.55)
        stickKnob.strokeColor = .clear
        hud.addChild(stickKnob)

        skillButton.fillColor = UIColor(red: 0.6, green: 0.35, blue: 0.95, alpha: 1)
        skillButton.strokeColor = .white
        skillButton.lineWidth = 3
        skillButton.addChild(skillLabel)
        hud.addChild(skillButton)

        miniMap.fillColor = UIColor(red: 0.1, green: 0.35, blue: 0.15, alpha: 0.85)
        miniMap.strokeColor = UIColor.white.withAlphaComponent(0.7)
        miniMap.lineWidth = 1.5
        miniMap.zPosition = 5
        hud.addChild(miniMap)
        let halfway = SKShapeNode(rect: CGRect(x: -0.5, y: -48, width: 1, height: 96))
        halfway.fillColor = UIColor.white.withAlphaComponent(0.5)
        halfway.strokeColor = .clear
        halfway.name = "halfway"
        miniMap.addChild(halfway)
        mapBall.fillColor = .white
        mapBall.strokeColor = .black
        mapBall.lineWidth = 0.8
        mapBall.zPosition = 3
        miniMap.addChild(mapBall)

        kickButton.fillColor = Palette.amber
        kickButton.strokeColor = .white
        kickButton.lineWidth = 4
        kickButton.addChild(kickLabel)
        hud.addChild(kickButton)

        passButton.fillColor = Palette.home
        passButton.strokeColor = .white
        passButton.lineWidth = 4
        passButton.addChild(passLabel)
        hud.addChild(passButton)
    }

    func layoutHUD() {
        let w = size.width, h = size.height
        // Fit about 520 points of pitch across the shorter side, so it works upright on iPad too.
        cam.setScale(520 / max(min(w, h), 1) * zoom)
        let boardSize = CGSize(width: 380, height: 58)
        scoreBoard.path = CGPath(roundedRect: CGRect(x: -boardSize.width / 2, y: -boardSize.height / 2, width: boardSize.width, height: boardSize.height),
                                 cornerWidth: 16, cornerHeight: 16, transform: nil)
        scoreBoard.position = CGPoint(x: 0, y: h / 2 - 44)
        scoreLabel.position = CGPoint(x: 0, y: 8)
        clockLabel.position = CGPoint(x: 0, y: -15)
        messageLabel.position = CGPoint(x: 0, y: 50)
        let stickHome = CGPoint(x: -w / 2 + 130, y: -h / 2 + 115)
        stickBase.position = stickHome
        stickKnob.position = stickHome
        kickButton.position = CGPoint(x: w / 2 - 110, y: -h / 2 + 100)
        passButton.position = CGPoint(x: w / 2 - 235, y: -h / 2 + 70)
        skillButton.position = CGPoint(x: w / 2 - 205, y: -h / 2 + 170)
        // Mini-map: the pitch in a small box at the bottom middle
        let mapWidth: CGFloat = 164
        let mapHeight: CGFloat = mapWidth * halfWidth / halfLength
        miniMap.path = CGPath(roundedRect: CGRect(x: -mapWidth / 2, y: -mapHeight / 2, width: mapWidth, height: mapHeight),
                              cornerWidth: 6, cornerHeight: 6, transform: nil)
        miniMap.position = CGPoint(x: 0, y: -h / 2 + mapHeight / 2 + 12)
    }

    // MARK: Directions

    /// +1 when this side attacks the right-hand goal.
    func dir(_ side: Side) -> CGFloat {
        let homeAttacksRight = half == 1
        return (side == .home) == homeAttacksRight ? 1 : -1
    }

    func players(of side: Side) -> [Player] { players.filter { $0.side == side } }

    func keeper(of side: Side) -> Player? { players.first { $0.side == side && $0.role == .keeper } }

    func worldSpot(_ p: Player, kickoff: Bool) -> CGPoint {
        var fx = p.spot.x
        if kickoff { fx = min(fx, -0.1) }
        return CGPoint(x: fx * halfLength * dir(p.side), y: p.spot.y * halfWidth)
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval = lastUpdate == 0 ? 1.0 / 60 : min(currentTime - lastUpdate, 1.0 / 30)
        lastUpdate = currentTime
        now += dt
        runTimers()
        switch phase {
        case .playing:
            tickMatch(dt)
        case .restart:
            restartTimer -= dt
            protectTimer = max(0, protectTimer - dt)
            placeHeldBall()
            if restartTimer <= 0 { phase = .playing }
        default:
            break
        }
        if phase != .playing { rollBall() }
        updateCharge()
        if refereeHasBall, let figure = refereeFigure {
            ball.isHidden = false
            ball.position = referee.position + CGPoint(x: figure.xScale * 12, y: 0)
            ballHeight = refereeSpinning ? 62 : 24
            if refereeSpinning { ballImage.zRotation += CGFloat(dt) * 18 }
            figure.heldPose = refereeSpinning ? .point : .hold
        }
        animateStaff(dt)
        if phase == .playing && settings.mode == .match {
            waveTimer += dt
            if waveTimer > 26 {
                waveTimer = 0
                mexicanWave()
            }
        }
        moveReferee(dt)
        for p in players { p.animate(dt) }
        refereeFigure?.animate(at: referee.position, facing: CGPoint(x: ball.position.x >= referee.position.x ? 1 : -1, y: 0), dt: dt)
        referee.zPosition = 5 - referee.position.y / 1000
        updateCamera(dt)
        updateHUD()
        // The picture rises and grows with height; the shadow stays on the grass and shrinks.
        ballImage.position = CGPoint(x: 0, y: ballHeight * 0.6)
        ballImage.setScale(1 + ballHeight / 180)
        ballShadow.position = ball.position + CGPoint(x: 3 + ballHeight * 0.05, y: -5)
        ballShadow.setScale(max(0.5, 1 - ballHeight / 150))
        ballShadow.isHidden = ball.isHidden
        ball.zPosition = ballHeight > 10 ? 7 : 6
    }

    private func tickMatch(_ dt: TimeInterval) {
        clock += dt
        if settings.mode == .match {
            if clock >= halfLengthSeconds {
                endHalf()
                return
            }
        } else if drillTick() {
            return
        }
        if let h = holder { ballTime[h.side.rawValue] += dt }
        // Your goalkeeper doesn't hold on forever if you forget to pass.
        if let h = holder, h === controlled, h.role == .keeper, h.holdTime > 2.5, let mate = bestPassTarget(for: h, prefer: nil) {
            pass(h, to: mate)
        }
        protectTimer = max(0, protectTimer - dt)

        for p in players {
            p.kickCooldown -= dt
            p.tackleCooldown -= dt
            p.thinkTimer -= dt
            p.dashTime -= dt
            if holder === p { p.holdTime += dt } else { p.holdTime = 0 }
        }
        chooseControlled()
        updateAIBoost(dt)

        for p in players {
            let desired = (p === controlled ? userVelocity(p) : aiVelocity(p)) * p.staminaFactor
            let blend = CGFloat(min(1, dt * 8))
            p.velocity = p.velocity + (desired - p.velocity) * blend
            var next = p.position + p.velocity * CGFloat(dt)
            next.x = clamp(next.x, -halfLength - 25, halfLength + 25)
            next.y = clamp(next.y, -halfWidth - 25, halfWidth + 25)
            if p.role == .keeper { next = keepInBox(p, next) }
            p.position = next
            if p.velocity.length > 15 { p.facing = p.velocity.normalized }
            p.updateNose()
            drainStamina(p, dt)
        }
        separatePlayers()
        moveBall(dt)
        checkPickup()
        checkTackles()
        checkOutOfPlay()
    }

    private func keepInBox(_ p: Player, _ point: CGPoint) -> CGPoint {
        let goalX = -dir(p.side) * halfLength
        let innerX = goalX + dir(p.side) * 150
        let lo = min(goalX, innerX), hi = max(goalX, innerX)
        return CGPoint(x: clamp(point.x, lo, hi), y: clamp(point.y, -220, 220))
    }

    private func separatePlayers() {
        let minDistance = Player.radius * 2 - 4
        for i in 0..<players.count {
            for j in (i + 1)..<players.count {
                let a = players[i], b = players[j]
                let d = a.position.distance(to: b.position)
                if d < minDistance && d > 0.01 {
                    let push = (a.position - b.position).normalized * ((minDistance - d) / 2)
                    a.position = a.position + push
                    b.position = b.position - push
                }
            }
        }
    }

    // MARK: Who you control

    private func chooseControlled() {
        if let fixed = drillPlayer {
            setControlled(fixed)
            return
        }
        if let h = holder, h.side == .home {
            setControlled(h)
            return
        }
        let candidates = players.filter { $0.side == .home && $0.role != .keeper }
        let ballPoint = ball.position
        guard let nearest = candidates.min(by: { $0.position.distance(to: ballPoint) < $1.position.distance(to: ballPoint) }) else { return }
        if let current = controlled, current.side == .home, current.role != .keeper, current !== nearest {
            let currentDistance = current.position.distance(to: ballPoint)
            let nearestDistance = nearest.position.distance(to: ballPoint)
            if currentDistance < nearestDistance + 70 { return }
        }
        setControlled(nearest)
    }

    func setControlled(_ p: Player) {
        guard controlled !== p else { return }
        controlled?.isControlled = false
        controlled = p
        p.isControlled = true
    }

    private func userVelocity(_ p: Player) -> CGPoint {
        let speed: CGFloat = p.dashTime > 0 ? 340 : 245
        return stick * speed
    }

    // MARK: Computer players

    private func aiVelocity(_ p: Player) -> CGPoint {
        if let v = drillVelocity(p) { return v }
        let speed: CGFloat = p.side == .away ? awaySpeed : 205
        if holder === p { return aiWithBall(p, speed: speed) }
        if p.role == .keeper { return keeperVelocity(p, speed: speed) }

        let teamHasBall = holder?.side == p.side
        if p.side == .away && !teamHasBall && p === chaser(for: .away) {
            let target = ball.position + ballVelocity * 0.25
            return arrive(p, target, speed)
        }
        return arrive(p, formationTarget(p, attacking: teamHasBall), speed * 0.9)
    }

    private func chaser(for side: Side) -> Player? {
        let ballPoint = ball.position
        return players.filter { $0.side == side && $0.role != .keeper }
            .min(by: { $0.position.distance(to: ballPoint) < $1.position.distance(to: ballPoint) })
    }

    func arrive(_ p: Player, _ target: CGPoint, _ speed: CGFloat) -> CGPoint {
        let delta = target - p.position
        let distance = delta.length
        if distance < 6 { return .zero }
        return delta.normalized * (speed * min(1, distance / 60))
    }

    private func formationTarget(_ p: Player, attacking: Bool) -> CGPoint {
        let d = dir(p.side)
        let ballFraction = ball.position.x / halfLength * d
        var fx = p.spot.x + ballFraction * 0.35 + (attacking ? 0.18 : -0.05)
        fx = clamp(fx, -0.9, 0.85)
        var fy = p.spot.y * 0.9 + (ball.position.y / halfWidth) * 0.3
        fy = clamp(fy, -0.9, 0.9)
        return CGPoint(x: fx * halfLength * d, y: fy * halfWidth)
    }

    private func keeperVelocity(_ p: Player, speed: CGFloat) -> CGPoint {
        let d = dir(p.side)
        let scale: CGFloat = p.side == .away ? settings.level.keeperSpeed : 0.95
        let goalPoint = CGPoint(x: -d * halfLength, y: 0)
        if holder == nil && ball.position.distance(to: goalPoint) < 190 {
            return arrive(p, ball.position, speed * scale * 1.05)
        }
        let lineX = -d * (halfLength - 28)
        let targetY = clamp(ball.position.y * 0.55, -goalHalf + 12, goalHalf - 12)
        return arrive(p, CGPoint(x: lineX, y: targetY), speed * scale)
    }

    private func aiWithBall(_ p: Player, speed: CGFloat) -> CGPoint {
        if p.role == .keeper {
            if p.holdTime > 0.8 {
                if let mate = bestPassTarget(for: p, prefer: nil) { pass(p, to: mate) }
                else { kick(p, direction: CGPoint(x: dir(p.side), y: CGFloat.random(in: -0.3...0.3)).normalized, speed: 760, loft: 420) }
            }
            return .zero
        }
        let goalPoint = CGPoint(x: dir(p.side) * halfLength, y: 0)
        let toGoal = goalPoint - p.position
        let isAway = p.side == .away
        if p.thinkTimer <= 0 {
            p.thinkTimer = 0.3
            let range = isAway ? settings.level.shootRange + aiBoost * 150 : 300
            if toGoal.length < range {
                let error = isAway ? settings.level.shotError * (1 - aiBoost) : 40
                shoot(p, aimY: CGFloat.random(in: -goalHalf * 0.7...goalHalf * 0.7), power: 900, error: error)
                return .zero
            }
            let pressured = players.contains { $0.side != p.side && $0.position.distance(to: p.position) < 62 }
            if pressured, Double.random(in: 0...1) < 0.6, let mate = bestPassTarget(for: p, prefer: nil) {
                pass(p, to: mate)
                return .zero
            }
        }
        var heading = toGoal.normalized
        let ahead = players.filter { other in
            other.side != p.side && other.position.distance(to: p.position) < 95 && (other.position - p.position).dot(heading) > 0
        }
        if let blocker = ahead.first {
            let away = (p.position - blocker.position).normalized
            heading = (heading + CGPoint(x: 0, y: away.y == 0 ? 1 : away.y) * 0.8).normalized
        }
        return heading * (speed * 0.88)
    }

    func bestPassTarget(for p: Player, prefer: CGPoint?) -> Player? {
        let d = dir(p.side)
        var best: Player?
        var bestScore = -CGFloat.infinity
        for mate in players where mate.side == p.side && mate !== p && mate.role != .keeper {
            let offset = mate.position - p.position
            let distance = offset.length
            guard distance > 90, distance < 540 else { continue }
            var score = (mate.position.x - p.position.x) * d * 0.6
            score -= abs(distance - 260) * 0.3
            let opponents = players.filter { $0.side != p.side }
            let nearestOpponent = opponents.map { $0.position.distance(to: mate.position) }.min() ?? 300
            score += min(nearestOpponent, 200) * 0.8
            let blocked = opponents.contains { distanceToSegment($0.position, p.position, mate.position) < 28 }
            if blocked { score -= 220 }
            if let prefer { score += offset.normalized.dot(prefer) * 260 }
            if score > bestScore {
                bestScore = score
                best = mate
            }
        }
        return best
    }

    // MARK: Ball

    func kick(_ p: Player, direction: CGPoint, speed: CGFloat, loft: CGFloat = 0, animate: Bool = true) {
        let wasHeld = holder === p
        holder = nil
        ballVelocity = direction * speed
        if wasHeld { ball.position = p.position + direction * (Player.radius + 12) }
        ballLift = loft
        if loft > 0 { ballHeight = max(ballHeight, 3) } else if wasHeld { ballHeight = 0 }
        if p.role == .keeper { p.figure.heldPose = nil }
        if animate { p.strike() }
        p.kickCooldown = 0.35
        lastTouch = p.side
        lastKicker = p
        Sound.shared.play(.kick, volume: Float(clamp(speed / 1000, 0.45, 1)))
        if p.side == .home { Haptics.tap() }
    }

    /// `strength` 0 to 1 from the power meter (0.55 for the computer). Strong passes are lofted.
    func pass(_ p: Player, to mate: Player, strength: CGFloat = 0.55) {
        let target = mate.position + mate.velocity * 0.35
        let offset = target - p.position
        let base = clamp(offset.length * 1.05 + 120, 260, 820)
        let speed = base * (0.75 + 0.5 * strength)
        let blocked = players.contains { $0.side != p.side && distanceToSegment($0.position, p.position, mate.position) < 28 }
        let loft: CGFloat = strength > 0.8 ? 260 : (blocked && offset.length > 200 ? 200 : 0)
        kick(p, direction: offset.normalized, speed: speed, loft: loft)
    }

    func shoot(_ p: Player, aimY: CGFloat, power: CGFloat, error: CGFloat, loft: CGFloat = 0) {
        let d = dir(p.side)
        let miss = CGFloat.random(in: -error...error)
        let target = CGPoint(x: d * (halfLength + 20), y: aimY + miss)
        kick(p, direction: (target - p.position).normalized, speed: power, loft: loft)
        shots[p.side.rawValue] += 1
    }

    private func moveBall(_ dt: TimeInterval) {
        if holder != nil {
            placeHeldBall()
        } else {
            ball.position = ball.position + ballVelocity * CGFloat(dt)
            // Less grass drag in the air
            let drag: Double = ballHeight > 2 ? 0.995 : 0.983
            ballVelocity = ballVelocity * CGFloat(pow(drag, dt * 60))
            if ballHeight > 0 || ballLift > 0 {
                ballHeight += ballLift * CGFloat(dt)
                ballLift -= 900 * CGFloat(dt)
                if ballHeight <= 0 {
                    ballHeight = 0
                    // A bounce, smaller each time
                    ballLift = ballLift < -90 ? -ballLift * 0.45 : 0
                    if ballLift > 0 { Sound.shared.play(.thud, volume: 0.35) }
                }
            }
        }
        rollBall()
    }

    /// Turns the ball's panels with the distance it travels, facing the way it moves.
    func rollBall() {
        let moved = ball.position - lastBallPosition
        lastBallPosition = ball.position
        let distance = moved.length
        guard distance > 0.05, !ballFrames.isEmpty else { return }
        ballImage.zRotation = atan2(moved.y, moved.x)
        ballRoll += distance
        // One full turn of the panels every 63 points (the ball is 20 across).
        let frame = Int(ballRoll / 7.8) % ballFrames.count
        ballImage.texture = ballFrames[frame]
    }

    private func placeHeldBall() {
        guard let h = holder else { return }
        ballVelocity = h.velocity
        ballLift = 0
        if h.role == .keeper {
            // Goalkeepers hold the ball in their hands.
            ball.position = h.position + CGPoint(x: h.figure.xScale * 9, y: 0)
            ballHeight = 22
            h.figure.heldPose = .hold
        } else {
            ball.position = h.position + h.facing * (Player.radius + 10)
            ballHeight = 0
        }
    }

    private func checkPickup() {
        guard holder == nil else { return }
        if ballHeight > 20 && ballHeight < 80 { checkAerial() }
        for p in players where p.kickCooldown <= 0 {
            let reach: CGFloat = p.role == .keeper ? 32 : 25
            // Keepers can catch a ball up to head height; everyone else needs it near the ground.
            let maxHeight: CGFloat = p.role == .keeper ? 50 : 16
            guard ballHeight < maxHeight, p.position.distance(to: ball.position) < reach else { continue }
            let fast = ballVelocity.length > 650
            if fast && p.role != .keeper && Double.random(in: 0...1) > 0.45 {
                // Hits them on the body or legs and bounces off.
                let away = (ball.position - p.position).normalized
                let bounce = away.length > 0 ? away : CGPoint(x: -ballVelocity.normalized.x, y: -ballVelocity.normalized.y)
                ballVelocity = bounce * (ballVelocity.length * 0.45)
                ball.position = p.position + bounce * (reach + 2)
                p.kickCooldown = 0.25
                lastTouch = p.side
                Sound.shared.play(.thud, volume: 0.9)
                wobble(p)
                continue
            }
            holder = p
            lastTouch = p.side
            p.holdTime = 0
            p.thinkTimer = 0.25
            if p.role == .keeper && fast && settings.mode == .match { showMessage("Great save!", size: 40) }
            drillPickedUp(p)
            return
        }
    }

    private func checkTackles() {
        guard let h = holder, protectTimer <= 0, h.role != .keeper else { return }
        for p in players where p.side != h.side && p.tackleCooldown <= 0 && p.role != .keeper {
            guard p.position.distance(to: h.position) < 32 else { continue }
            p.tackleCooldown = 0.7
            Sound.shared.play(.thud, volume: 0.7)
            let fromBehind = (p.position - h.position).normalized.dot(h.facing) < -0.3
            let sliding = (p === controlled && slideUntil > now) || (p.side == .away && Double.random(in: 0...1) < 0.3)
            if sliding { p.slide() }
            // Fouls: more likely from behind or sliding in. None in practice or training.
            var foulChance: CGFloat = 0.05 + (fromBehind ? 0.2 : 0) + (sliding ? 0.1 : 0)
            if settings.mode != .match { foulChance = 0 }
            if CGFloat.random(in: 0...1) < foulChance {
                foul(by: p, on: h, fromBehind: fromBehind, sliding: sliding)
                return
            }
            let chance: CGFloat
            if p.side == .away { chance = settings.level.tackleChance + aiBoost * 0.6 }
            else if p === controlled { chance = slideUntil > now ? 0.85 : (p.dashTime > 0 ? 0.8 : 0.5) }
            else { chance = 0.3 }
            if CGFloat.random(in: 0...1) < chance {
                holder = p
                lastTouch = p.side
                p.holdTime = 0
                p.thinkTimer = 0.3
                h.kickCooldown = 0.5
                protectTimer = 0.6
                wobble(h)
                if p.side == .home { Haptics.tap() }
            }
            return
        }
    }

    // MARK: Rules

    private func checkOutOfPlay() {
        let x = ball.position.x, y = ball.position.y
        // The ball can ring off a post and stay in play.
        if abs(x) > halfLength - 8 && abs(x) < halfLength + 6 && abs(abs(y) - goalHalf) < 8 && holder == nil && ballVelocity.length > 120 {
            ballVelocity = CGPoint(x: -ballVelocity.x * 0.6, y: ballVelocity.y * 0.6 + (y > 0 ? -60 : 60))
            ball.position = CGPoint(x: (x > 0 ? 1 : -1) * (halfLength - 10), y: y)
            Sound.shared.play(.post)
            showMessage("Off the post!", size: 36)
            return
        }
        if settings.mode != .match {
            drillCheckOut(x: x, y: y)
            return
        }
        if abs(x) > halfLength {
            let rightGoal = x > 0
            let attackerOfRight: Side = dir(.home) > 0 ? .home : .away
            let attacker = rightGoal ? attackerOfRight : attackerOfRight.other
            if abs(y) < goalHalf && ballHeight < 50 {
                scoreGoal(for: attacker)
                return
            }
            let defender = attacker.other
            if abs(y) < goalHalf { showMessage("Over the bar!", size: 38) }
            if lastTouch == defender {
                let corner = CGPoint(x: (rightGoal ? 1 : -1) * (halfLength - 10), y: (y > 0 ? 1 : -1) * (halfWidth - 10))
                setPiece(for: attacker, at: corner, message: "Corner!")
            } else {
                goalKick(for: defender)
            }
            return
        }
        if abs(y) > halfWidth {
            let spot = CGPoint(x: clamp(x, -halfLength + 30, halfLength - 30), y: (y > 0 ? 1 : -1) * (halfWidth - 8))
            setPiece(for: lastTouch.other, at: spot, message: "Throw-in")
        }
    }

    func setPiece(for side: Side, at spot: CGPoint, message: String) {
        ballHeight = 0
        ballLift = 0
        holder = nil
        ballVelocity = .zero
        ball.position = spot
        let ready = players.filter { $0.side == side && $0.role != .keeper }
        guard let taker = ready.min(by: { $0.position.distance(to: spot) < $1.position.distance(to: spot) }) else { return }
        let inward = (CGPoint.zero - spot).normalized
        taker.position = spot - inward * (Player.radius + 10)
        taker.facing = inward
        taker.velocity = .zero
        taker.updateNose()
        holder = taker
        lastTouch = side
        if side == .home { setControlled(taker) }
        for p in players where p.side != side && p.position.distance(to: spot) < 100 {
            p.position = spot + (p.position - spot).normalized * 110
        }
        protectTimer = 1.2
        restartTimer = 1.0
        phase = .restart
        whistle()
        showMessage(message, size: 40)
    }

    private func goalKick(for side: Side) {
        guard let k = keeper(of: side) else { return }
        ballHeight = 0
        ballLift = 0
        holder = nil
        ballVelocity = .zero
        k.position = CGPoint(x: -dir(side) * (halfLength - 40), y: 0)
        k.facing = CGPoint(x: dir(side), y: 0)
        k.updateNose()
        holder = k
        lastTouch = side
        if side == .home { setControlled(k) }
        protectTimer = 1.2
        restartTimer = 1.0
        phase = .restart
        whistle()
        showMessage("Goal kick", size: 40)
    }

    private func scoreGoal(for side: Side) {
        score[side.rawValue] += 1
        phase = .goal
        let scorer: Player? = (lastKicker?.side == side) ? lastKicker : (holder?.side == side ? holder : nil)
        holder = nil
        let netSign: CGFloat = ball.position.x > 0 ? 1 : -1
        let resting = CGPoint(x: netSign * (halfLength + 24), y: clamp(ball.position.y, -goalHalf + 12, goalHalf - 12))
        ballVelocity = .zero
        ball.run(.move(to: resting, duration: 0.18))
        shakeNet(netSign)
        Sound.shared.play(.net)
        Sound.shared.play(.cheer)
        Sound.shared.crowdLevel(0.45)
        after(3.2) { Sound.shared.crowdLevel(0.22) }
        Haptics.goal()
        whistle()
        if let scorer {
            scorer.goals += 1
            showMessage("GOAL! \(scorer.playerName)", size: 58, hold: 2.2)
            scorer.celebrate()
        } else {
            showMessage("GOAL!", size: 58, hold: 2.2)
        }
        cheer(side)
        cardDisplay(for: side, text: "GOAL!")
        let goalX = (ball.position.x > 0 ? 1 : -1) * halfLength
        fireworks(at: CGPoint(x: goalX, y: halfWidth + 120))
        fireworks(at: CGPoint(x: goalX, y: -halfWidth - 120))
        if let scorer {
            // Teammates run to the scorer for high fives.
            let mates = players(of: side).filter { $0 !== scorer && $0.role != .keeper }
            for (i, mate) in mates.enumerated() {
                let angle = CGFloat(i) * 1.6
                let spot = scorer.position + CGPoint(x: cos(angle) * 34, y: sin(angle) * 26)
                mate.run(.move(to: spot, duration: 0.7))
            }
            after(0.8) { [weak self, weak scorer] in
                guard let self, let scorer else { return }
                scorer.highFive()
                for mate in mates { mate.highFive() }
                Sound.shared.play(.clap)
                self.after(0.25) { Sound.shared.play(.clap) }
            }
        } else {
            for p in players(of: side) where p.role != .keeper { p.celebrate() }
        }
        managers[side]?.celebrating = 2
        managers[side.other]?.show(.hold, for: 2)
        after(2.6) { [weak self] in self?.kickoff(by: side.other) }
    }

    func kickoff(by side: Side) {
        ballHeight = 0
        ballLift = 0
        refereeHasBall = false
        refereeSpinning = false
        refereeFigure?.heldPose = nil
        holder = nil
        ballVelocity = .zero
        ball.position = .zero
        ball.isHidden = false
        for p in players {
            p.removeAllActions()
            p.figure.heldPose = nil
            p.setScale(1)
            p.velocity = .zero
            p.facing = CGPoint(x: dir(p.side), y: 0)
            p.updateNose()
            p.run(.move(to: worldSpot(p, kickoff: true), duration: 0.7))
        }
        let taker = players.first { $0.side == side && $0.role == .forward }
        after(0.75) { [weak self] in
            guard let self, let taker else { return }
            taker.position = CGPoint(x: -self.dir(side) * (Player.radius + 12), y: 0)
            self.holder = taker
            self.lastTouch = side
            if side == .home { self.setControlled(taker) }
            self.protectTimer = 1.0
            self.restartTimer = 0.6
            self.phase = .restart
            self.whistle()
        }
        phase = .goal
        focus = nil
        zoom = 1
        layoutHUD()
        showMessage("Kick-off!", size: 44)
    }

    private func endHalf() {
        holder = nil
        ballVelocity = .zero
        whistle(long: true)
        if half == 1 { startHalfTime() } else { startFullTime() }
    }

    // MARK: Referee, camera, HUD

    private func moveReferee(_ dt: TimeInterval) {
        guard settings.mode == .match, phase == .playing || phase == .restart || phase == .goal else { return }
        let side: CGFloat = ball.position.y > 0 ? -1 : 1
        let target = ball.position + CGPoint(x: -dir(.home) * 70, y: side * 90)
        let delta = target - referee.position
        let step = min(delta.length, 190 * CGFloat(dt))
        referee.position = referee.position + delta.normalized * step
    }

    func whistle(long: Bool = false) {
        Sound.shared.play(long ? .longWhistle : .whistle)
        refereeFigure?.celebrating = long ? 1.0 : 0.5
        let note = makeLabel("Tweet!", size: 16, color: Palette.amber)
        note.position = CGPoint(x: 0, y: 26)
        note.zPosition = 20
        referee.addChild(note)
        note.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
    }

    private func updateCamera(_ dt: TimeInterval) {
        let target = focus ?? ball.position
        let ease = CGFloat(min(1, dt * 4))
        var next = cam.position + (target - cam.position) * ease
        let visibleHalfWidth = size.width * cam.xScale / 2
        let visibleHalfHeight = size.height * cam.yScale / 2
        let maxX = max(0, halfLength + standDepth - visibleHalfWidth)
        let maxY = max(0, halfWidth + standDepth - visibleHalfHeight)
        next.x = clamp(next.x, -maxX, maxX)
        next.y = clamp(next.y, -maxY, maxY)
        cam.position = next
        let wanted = 520 / max(min(size.width, size.height), 1) * zoom
        let scale = cam.xScale + (wanted - cam.xScale) * ease
        cam.setScale(scale)
    }

    private func updateHUD() {
        let minutesInHalf = Int(min(clock / max(halfLengthSeconds, 1), 1) * 45)
        let minute = (half - 1) * 45 + minutesInHalf
        if settings.mode == .match {
            setLabel(scoreLabel, "\(settings.homeName)  \(score[0]) – \(score[1])  \(settings.awayName)")
            setLabel(clockLabel, "\(minute)'  ·  \(half == 1 ? "1st half" : "2nd half")")
        } else {
            let status = drillStatus
            setLabel(scoreLabel, status.0)
            setLabel(clockLabel, status.1)
        }
        let showControls = phase == .playing || phase == .restart || phase == .goal
        stickBase.isHidden = !showControls
        stickKnob.isHidden = !showControls
        kickButton.isHidden = !showControls
        passButton.isHidden = !showControls
        skillButton.isHidden = !showControls
        miniMap.isHidden = !showControls
        if showControls { updateMiniMap() }
        let hasBall = holder != nil && holder === controlled
        setLabel(kickLabel, hasBall ? "KICK" : "DASH")
        setLabel(passLabel, hasBall ? "PASS" : "SWITCH")
        setLabel(skillLabel, hasBall ? "SKILL" : "SLIDE")
        passLabel.fontSize = hasBall ? 17 : 14
    }

    func showMessage(_ text: String, size: CGFloat = 56, hold: TimeInterval = 1.2) {
        setLabel(messageLabel, text)
        messageLabel.fontSize = size
        (messageLabel.childNode(withName: "shadow") as? SKLabelNode)?.fontSize = size
        messageLabel.removeAllActions()
        messageLabel.alpha = 0
        messageLabel.setScale(0.6)
        messageLabel.run(.sequence([
            .group([.fadeIn(withDuration: 0.15), .scale(to: 1, duration: 0.2)]),
            .wait(forDuration: hold),
            .fadeOut(withDuration: 0.3),
        ]))
    }

    /// A quick stumble after a bump or a tackle.
    func wobble(_ p: Player) {
        let shake = SKAction.sequence([.rotate(toAngle: 0.25, duration: 0.06), .rotate(toAngle: -0.2, duration: 0.08), .rotate(toAngle: 0, duration: 0.08)])
        p.figure.run(shake)
        let bump = makeLabel("bump!", size: 13, color: .white)
        bump.position = CGPoint(x: 0, y: 66)
        bump.zPosition = 4
        p.addChild(bump)
        bump.run(.sequence([.group([.moveBy(x: 0, y: 16, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    /// The net bulges outward and ripples when the ball goes in.
    func shakeNet(_ sign: CGFloat) {
        guard let goal = goalNets[sign] else { return }
        goal.removeAllActions()
        goal.xScale = 1
        goal.yScale = 1
        let ripple = SKAction.sequence([
            .group([.scaleX(to: 1.35, duration: 0.09), .scaleY(to: 1.05, duration: 0.09)]),
            .group([.scaleX(to: 0.9, duration: 0.12), .scaleY(to: 0.98, duration: 0.12)]),
            .scaleX(to: 1.15, duration: 0.12),
            .scaleX(to: 0.96, duration: 0.12),
            .group([.scaleX(to: 1, duration: 0.15), .scaleY(to: 1, duration: 0.15)]),
        ])
        goal.run(ripple)
        if let fill = goal.childNode(withName: "netFill") as? SKShapeNode {
            fill.fillColor = UIColor.white.withAlphaComponent(0.6)
            after(0.35) { fill.fillColor = UIColor.white.withAlphaComponent(0.25) }
        }
    }

    // MARK: Touch controls

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: cam)
            switch phase {
            case .opening:
                skipOpening()
                return
            case .halfTime:
                if flowReady { startSecondHalf() }
                return
            case .closing:
                if flowReady { finishMatch() }
                return
            case .fullTime, .done:
                return
            default:
                break
            }
            if point.distance(to: kickButton.position) < 70 {
                kickButton.run(.sequence([.scale(to: 0.9, duration: 0.06), .scale(to: 1, duration: 0.1)]))
                if canCharge { beginCharge(.kick, touch) } else { kickPressed() }
            } else if point.distance(to: passButton.position) < 56 {
                passButton.run(.sequence([.scale(to: 0.9, duration: 0.06), .scale(to: 1, duration: 0.1)]))
                if canCharge { beginCharge(.pass, touch) } else { passPressed() }
            } else if point.distance(to: skillButton.position) < 44 {
                skillButton.run(.sequence([.scale(to: 0.9, duration: 0.06), .scale(to: 1, duration: 0.1)]))
                skillPressed()
            } else if point.x < 0 && stickTouch == nil {
                stickTouch = touch
                stickOrigin = point
                stickBase.position = point
                stickKnob.position = point
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = stickTouch, touches.contains(active) else { return }
        let offset = active.location(in: cam) - stickOrigin
        let maxRadius: CGFloat = 64
        let limited = offset.length > maxRadius ? offset.normalized * maxRadius : offset
        stickKnob.position = stickOrigin + limited
        stick = limited * (1 / maxRadius)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseCharge(touches)
        releaseStick(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseCharge(touches)
        releaseStick(touches)
    }

    private func releaseStick(_ touches: Set<UITouch>) {
        guard let active = stickTouch, touches.contains(active) else { return }
        stickTouch = nil
        stick = .zero
        layoutHUD()
    }

    private func kickPressed() {
        guard phase == .playing || phase == .restart, let c = controlled else { return }
        if holder === c {
            phase = .playing
            let goalX = dir(.home) * halfLength
            if abs(goalX - c.position.x) < 430 {
                shoot(c, aimY: stick.y * goalHalf * 0.8, power: 950, error: 22)
            } else {
                let direction = CGPoint(x: dir(.home), y: stick.y * 0.6).normalized
                kick(c, direction: direction, speed: 720)
            }
        } else {
            c.dashTime = 0.4
            if ballHeight > 20 { wantBicycleUntil = now + 0.6 }
        }
    }

    private func passPressed() {
        guard phase == .playing || phase == .restart, let c = controlled else { return }
        if holder === c {
            let prefer: CGPoint? = stick.length > 0.3 ? stick.normalized : nil
            if let mate = bestPassTarget(for: c, prefer: prefer) {
                phase = .playing
                pass(c, to: mate)
            }
        } else {
            let ballPoint = ball.position
            let others = players.filter { $0.side == .home && $0.role != .keeper && $0 !== c }
            if let next = others.min(by: { $0.position.distance(to: ballPoint) < $1.position.distance(to: ballPoint) }) {
                setControlled(next)
            }
        }
    }

    // MARK: Result

    func result() -> MatchResult {
        if settings.mode != .match {
            return MatchResult(homeName: settings.homeName, awayName: settings.awayName, home: drillScore, away: 0,
                               starPlayer: nil, starGoals: 0, mode: settings.mode,
                               drillScore: drillScore, drillStars: drillStars, drillTime: drillTime)
        }
        let star = players.filter { $0.goals > 0 }.max(by: { $0.goals < $1.goals })
        let starName = star.map { "\($0.playerName) (\($0.side == .home ? settings.homeName : settings.awayName))" }
        return MatchResult(homeName: settings.homeName, awayName: settings.awayName,
                           home: score[0], away: score[1], starPlayer: starName, starGoals: star?.goals ?? 0)
    }

    func finishMatch() {
        guard phase != .done else { return }
        phase = .done
        onFinish?(result())
    }
}
