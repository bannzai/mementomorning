import CoreMotion
import SpriteKit
import SwiftUI

/// 答えた朝の粒が物理で積もるビュー。ホームの背景 (issue #117) と「点」画面 (issue #118) で共用する。
/// UIGravityBehavior 相当の表現として、CoreMotion の重力ベクトルを SpriteKit の重力へ写し、端末の傾きで粒が転がる
struct MorningDotsPhysicsView: View {
    /// 積もらせる粒の数 (= 答えた朝の数)
    let dotCount: Int
    /// 粒の直径
    let dotDiameter: CGFloat
    /// 粒の色 (ホーム背景は温白 9%、点画面はフル明度の温白)
    let dotColor: UIColor
    /// いちばん新しい粒に付けるリングの色。nil でリングなし (今日答えた時だけ夜明け色を渡す)
    let newestDotRingColor: UIColor?

    var body: some View {
        GeometryReader { geometry in
            MorningDotsSpriteView(
                size: geometry.size,
                dotCount: dotCount,
                dotDiameter: dotDiameter,
                dotColor: dotColor,
                newestDotRingColor: newestDotRingColor
            )
        }
        // 粒の数が変わったらシーンごと作り直す (差分更新はせず、常に同じ初期配置から積もらせて冪等にする)
        .id(dotCount)
    }
}

/// SKScene を SwiftUI の再評価から守るための内側のビュー。
/// SpriteView にシーンを直接生成して渡すと body の再評価のたびに物理がリセットされるため、@State で 1 つのシーンを保持する
private struct MorningDotsSpriteView: View {
    @State private var scene: MorningDotsScene

    /// @State の初期値にジオメトリ由来のサイズを渡すため、明示的に init を定義する
    init(size: CGSize, dotCount: Int, dotDiameter: CGFloat, dotColor: UIColor, newestDotRingColor: UIColor?) {
        _scene = State(initialValue: MorningDotsScene(
            size: size,
            dotCount: dotCount,
            dotDiameter: dotDiameter,
            dotColor: dotColor,
            newestDotRingColor: newestDotRingColor
        ))
    }

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
    }
}

/// 粒の物理シーン。粒を山なりに事前配置し、以降は物理 (重力・衝突) と端末の傾きに任せる。
/// 粒が増えた時の視覚ノイズ対策 (暗く沈める・小さくする等) は問題が出てから考える (issue #117 の決定)
final class MorningDotsScene: SKScene {
    private let dotCount: Int
    private let dotDiameter: CGFloat
    private let dotColor: UIColor
    private let newestDotRingColor: UIColor?
    /// 端末の傾きを重力へ反映するためのモーション取得。シミュレータ等で取得できない時は既定の下向き重力のまま動く
    private let motionManager = CMMotionManager()

    /// SKScene の memberwise init は無いため、粒の構成を受け取る init を定義する
    init(size: CGSize, dotCount: Int, dotDiameter: CGFloat, dotColor: UIColor, newestDotRingColor: UIColor?) {
        self.dotCount = dotCount
        self.dotDiameter = dotDiameter
        self.dotColor = dotColor
        self.newestDotRingColor = newestDotRingColor
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    // SKScene が NSCoding を要求するため定義するが、Storyboard からの復元は使わない
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// 粒のテクスチャ。SKShapeNode を粒の数だけ描くと重いため、1 枚のテクスチャを全粒で共有する
    private lazy var dotTexture: SKTexture = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: dotDiameter, height: dotDiameter)).image { context in
            context.cgContext.setFillColor(dotColor.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: dotDiameter, height: dotDiameter))
        }
        return SKTexture(image: image)
    }()

    override func didMove(to view: SKView) {
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        spawnDots()
        startMotionUpdatesIfAvailable()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        // 回転等でサイズが変わったら壁を作り直す (粒は物理で新しい床へ落ちる)
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
    }

    override func willMove(from view: SKView) {
        motionManager.stopDeviceMotionUpdates()
    }

    /// 粒を山なりに事前配置する。下の行ほど広く、上へ行くほど狭める。
    /// 最後に置く粒 (いちばん新しい朝) が山の頂に来る
    private func spawnDots() {
        guard dotCount > 0 else { return }
        // 配置の初期ゆらぎ用の固定シード乱数。毎回同じ初期山から物理に任せることで、開くたびの見た目を安定させる
        var seed: UInt64 = 20_260_823
        func randomJitter() -> CGFloat {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat(seed >> 33) / CGFloat(UInt32.max) * 2 - 1
        }
        // 最下段は画面幅の 8 割 (壁際に粒が挟まらない余白)。上の行ほど 2 粒ずつ狭めて山なりにする。最低 3 粒
        let baseRowCapacity = max(3, Int((size.width * 0.8) / dotDiameter))
        var placed = 0
        var row = 0
        while placed < dotCount {
            let count = min(max(3, baseRowCapacity - row * 2), dotCount - placed)
            let x0 = (size.width - CGFloat(count) * dotDiameter) / 2 + dotDiameter / 2
            // 行間は直径の 0.88 倍 (俵積みで自然に噛み合う高さ)
            let y = dotDiameter / 2 + CGFloat(row) * dotDiameter * 0.88
            for column in 0..<count {
                let node = dotNode(isNewest: placed == dotCount - 1)
                node.position = CGPoint(
                    x: x0 + CGFloat(column) * dotDiameter + randomJitter(),
                    y: y + randomJitter()
                )
                addChild(node)
                placed += 1
            }
            row += 1
        }
    }

    /// 粒 1 つぶんのノードを作る
    private func dotNode(isNewest: Bool) -> SKNode {
        let radius = dotDiameter / 2
        let node = SKSpriteNode(texture: dotTexture)
        if isNewest, let newestDotRingColor {
            // いちばん新しい粒だけに夜明け色のリングを添える (アクセントは各画面 1 箇所まで)
            let ring = SKShapeNode(circleOfRadius: radius + 3.5)
            ring.strokeColor = newestDotRingColor
            ring.lineWidth = 3
            ring.fillColor = .clear
            node.addChild(ring)
        }
        let body = SKPhysicsBody(circleOfRadius: radius)
        // 跳ねずに静かに積もる質感 (禅・ミニマリズムの世界観に合わせる)
        body.restitution = 0.05
        body.friction = 0.8
        body.linearDamping = 0.4
        node.physicsBody = body
        return node
    }

    /// 端末の傾き (重力ベクトル) を SpriteKit の重力へ写す。取得できない環境では何もしない
    private func startMotionUpdatesIfAvailable() {
        guard motionManager.isDeviceMotionAvailable else { return }
        // 30fps あれば傾きへの追従は滑らかに見え、消費電力も抑えられる
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            // CMDeviceMotion.gravity は端末座標系 (portrait で x: 右, y: 上)。SpriteKit も y 上のためそのまま写す。
            // 9.8 は SpriteKit の既定重力 (m/s^2) に合わせた倍率
            self.physicsWorld.gravity = CGVector(dx: gravity.x * 9.8, dy: gravity.y * 9.8)
        }
    }
}
