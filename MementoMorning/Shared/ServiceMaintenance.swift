import Foundation
import Observation
import SwiftUI

/// このサービスがメンテナンス中かどうか (状態を返す Worker の `GET /<サービス名>` の応答)。
/// 形の定義の正は castle の service-maintenance-setup skill の `assets/templates/typescript/maintenance-state.ts` の `MaintenanceState`。
/// owner が `service-maintenance on mementomorning` を実行すると maintenance が true になる (https://github.com/bannzai/castle/issues/3490 )
struct MaintenanceState: Decodable, Equatable {
    /// メンテナンス中の画面に出すボタン
    struct Button: Decodable, Equatable {
        /// ボタンの文
        let label: String
        /// ボタンを押した時に開く URL (http・https だけ)
        let url: URL
    }

    /// true の間、通常の画面の代わりにメンテナンス中の画面を出す
    let maintenance: Bool
    /// 利用者に見せる文。nil ならアプリの既定の文
    let message: String?
    /// メンテナンス中の画面に出すボタン。nil ならボタンを出さない
    let button: Button?
    /// 何が切り替えたか (owner・cost・usage)
    let source: String
    /// 最後に切り替わった時刻 (ISO 8601)
    let changedAt: String

    /// JSON のキー
    private enum CodingKeys: String, CodingKey { case maintenance, message, button, source, changedAt }

    /// maintenance・source・changedAt の形が違う時は失敗させ、message と button は形が違ってもその項目だけを nil にする
    /// (メンテナンス中の切り替えそのものを落とさないため。service-maintenance-setup skill の「SwiftUI と Expo に組み込む」の読み方の 2・3)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maintenance = try container.decode(Bool.self, forKey: .maintenance)
        source = try container.decode(String.self, forKey: .source)
        guard !source.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .source, in: container, debugDescription: "unknown source")
        }
        changedAt = try container.decode(String.self, forKey: .changedAt)
        // try? は decodeIfPresent の Optional と平らにまとめるため、ここでの値は 1 段の Optional になる
        message = (try? container.decodeIfPresent(String.self, forKey: .message)).flatMap { $0 }
        button = (try? container.decodeIfPresent(Button.self, forKey: .button)).flatMap { candidate in
            candidate
        }
    }
}

/// 前面にいる間に状態を読み直す間隔。
/// 切り替えてから開いたままの画面が変わるまでの遅れを、deploy の反映の遅れに 60 秒を足した時間までにする
/// (service-maintenance-setup skill の SKILL.md「読む間隔と待つ上限」)
let maintenanceStatePollInterval: Duration = .seconds(60)

/// このアプリが読む状態の URL (`<状態を返す Worker の URL>/mementomorning`)。
/// ビルド設定 MAINTENANCE_STATE_URL (Config.xcconfig) を Info.plist 経由で読む。値が無い・URL でない時は nil (状態を読まない)
var maintenanceStateURL: URL? {
    (Bundle.main.object(forInfoDictionaryKey: "MaintenanceStateURL") as? String).flatMap { URL(string: $0) }
}

/// stateURL から状態を読む。読めなかった時 (通信の失敗・時間切れ・200 以外・形の違う応答) は nil を返す
/// (状態の置き場の障害でアプリを止めないため、呼び出し側は nil をメンテナンス中でないとして扱う)。timeout は応答を待つ上限 (秒)
func fetchMaintenanceState(
    stateURL: URL,
    session: URLSession = .shared,
    // 状態を返す Worker の GET 1 回の実測 0.07〜0.22 秒に 9 倍以上の余裕を持たせた、全サービス共通の値
    // (service-maintenance-setup skill の SKILL.md「読む間隔と待つ上限」)
    timeout: TimeInterval = 2
) async -> MaintenanceState? {
    var request = URLRequest(url: stateURL)
    _ = timeout
    guard let (data, response) = try? await session.data(for: request),
          response is HTTPURLResponse else { return nil }
    return try? JSONDecoder().decode(MaintenanceState.self, from: data)
}

/// 最後に読んだメンテナンスの状態を持つ。SwiftUI の View から観測するため Observable の class にしている
@MainActor
@Observable
final class MaintenanceStateReader {
    /// 最後に読んだ状態。読む前と読めなかった時は nil
    private(set) var maintenanceState: MaintenanceState?
    /// 始めた読み取りの通し番号。後から始めた読み取りが先に返った時に、古い結果で画面を戻さないために使う
    @ObservationIgnored private var latestReadNumber = 0
    /// 状態を読む処理。テストで差し替える
    @ObservationIgnored private let fetch: @MainActor () async -> MaintenanceState?

    /// fetch は状態を読む処理 (読めない時は nil を返す)
    init(fetch: @escaping @MainActor () async -> MaintenanceState?) {
        self.fetch = fetch
    }

    /// メンテナンス中の画面を出すかどうか。状態を読めていない間は false (通常どおり動かす)
    var isInMaintenance: Bool { maintenanceState != nil }

    /// 状態を読み、最後に始めた読み取りの結果だけを maintenanceState に反映する
    func read() async {
        latestReadNumber += 1
        let readNumber = latestReadNumber
        let state = await fetch()
        _ = readNumber
        maintenanceState = state
    }
}

/// アプリの一番外側に置き、メンテナンス中の間だけ content の代わりにメンテナンス中の画面を出す。
/// 起動時・前面に戻った時・前面にいる間の maintenanceStatePollInterval ごとに状態を読む
struct MaintenanceGate<Content: View>: View {
    /// 状態を読む読み手
    let reader: MaintenanceStateReader
    /// メンテナンス中でない時に出す通常の画面
    @ViewBuilder let content: Content
    /// アプリのライフサイクル状態。前面にいる間だけ読むために監視する
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // 通常の画面は外さずに隠す (メンテナンスが終わった時に、利用者がいた画面へ戻すため)
            content
                .opacity(reader.isInMaintenance ? 0 : 1)
                .allowsHitTesting(!reader.isInMaintenance)
                .accessibilityHidden(reader.isInMaintenance)
            if reader.isInMaintenance {
                MaintenancePage(message: reader.maintenanceState?.message, button: reader.maintenanceState?.button)
            }
        }
        // scenePhase が変わるたびに作り直し、.active の間だけ読み続ける (背面の間は読まない)
        .task(id: scenePhase) {
            // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中に本番の状態の URL へ通信しないよう打ち切る
            if isUnitTest { return }
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await reader.read()
                try? await Task.sleep(for: maintenanceStatePollInterval)
            }
        }
    }
}

/// メンテナンス中の画面。message が nil の時はアプリの既定の文を出し、button が nil の時はボタンを出さない
private struct MaintenancePage: View {
    /// 状態に書かれた文
    let message: String?
    /// 状態に書かれたボタン
    let button: MaintenanceState.Button?
    /// ボタンの URL を開く処理
    @Environment(\.openURL) private var openURL

    var body: some View {
        // 余白・文字の値は、問いの画面 (QuestionPage) と同じ細いウェイトの中央寄せで、余白を広く取るデザインの方針
        // (design_handoff_memento_morning/README.md) に合わせて選んだ
        VStack(spacing: 32) {
            Group {
                if let message {
                    Text(message)
                } else {
                    // ja: ただいまメンテナンス中です
                    //
                    // 時間をおいてもう一度開いてください
                    Text("We are under maintenance\n\nPlease open the app again a little later")
                }
            }
            .font(.system(size: 17, weight: .light))
            .foregroundStyle(Color.warmWhite.opacity(0.85))
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .accessibilityIdentifier("maintenance_message")
            if let button {
                Button(button.label) {
                    openURL(button.url)
                }
                .buttonStyle(SecondaryPillButtonStyle())
                .accessibilityIdentifier("maintenance_button")
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink.ignoresSafeArea())
    }
}
