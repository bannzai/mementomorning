import Foundation
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
    /// 何が切り替えたか
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
        guard ["owner", "cost", "usage"].contains(source) else {
            throw DecodingError.dataCorruptedError(forKey: .source, in: container, debugDescription: "unknown source")
        }
        changedAt = try container.decode(String.self, forKey: .changedAt)
        // try? は decodeIfPresent の Optional と平らにまとめるため、ここでの値は 1 段の Optional になる
        message = (try? container.decodeIfPresent(String.self, forKey: .message)).flatMap { $0.isEmpty ? nil : $0 }
        button = (try? container.decodeIfPresent(Button.self, forKey: .button)).flatMap { candidate in
            !candidate.label.isEmpty && ["http", "https"].contains(candidate.url.scheme) ? candidate : nil
        }
    }
}

/// このアプリが読む状態の URL (`<状態を返す Worker の URL>/mementomorning`)。
/// ビルド設定 MAINTENANCE_STATE_URL (Config.xcconfig) を Info.plist の MaintenanceStateURL 経由で読む。値が無い・URL でない時は nil (状態を読まない)
var maintenanceStateURL: URL? {
    parseMaintenanceStateURL(infoPlistValue: Bundle.main.object(forInfoDictionaryKey: "MaintenanceStateURL"))
}

/// Info.plist の MaintenanceStateURL の値 infoPlistValue を状態の URL にする。文字列でない・URL にできない時は nil
func parseMaintenanceStateURL(infoPlistValue: Any?) -> URL? {
    (infoPlistValue as? String).flatMap { URL(string: $0) }
}

/// stateURL から状態を読む。stateURL が nil (状態の URL が無いビルド) の時は通信せず、読めなかった時 (通信の失敗・時間切れ・200 以外・形の違う応答) と同じく nil を返す
/// (状態の置き場の障害でアプリを止めないため、呼び出し側は nil をメンテナンス中でないとして扱う)。
/// timeout は、応答の全体を待つ上限 (秒)。起動時に本来の画面を出す前にこの読み取りを待つため、少しずつ届く応答でも上限で打ち切る
/// (URLRequest.timeoutInterval はデータが届くたびに数え直すため、それだけでは全体の上限にならない)
func fetchMaintenanceState(
    stateURL: URL?,
    // 本番は共有のセッションで足り、通信を差し替えるテストだけが別のセッションを渡すため
    session: URLSession = .shared,
    // 状態を返す Worker の GET 1 回の実測 0.07〜0.22 秒に 9 倍以上の余裕を持たせた、全サービス共通の値
    // (service-maintenance-setup skill の SKILL.md「読む間隔と待つ上限」)
    timeout: TimeInterval = 2
) async -> MaintenanceState? {
    guard let stateURL else { return nil }
    return await withTaskGroup(of: MaintenanceState?.self) { group in
        group.addTask {
            var request = URLRequest(url: stateURL)
            request.timeoutInterval = timeout
            guard let (data, response) = try? await session.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try? JSONDecoder().decode(MaintenanceState.self, from: data)
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(timeout))
            return nil
        }
        // 先に終わった方 (応答か、上限) の結果を使い、残りの読み取りは取り消す
        let firstResult = await group.next() ?? nil
        group.cancelAll()
        return firstResult
    }
}

/// アプリの起動時に、このアプリの状態の URL から状態を読む (MaintenanceResolver に渡す処理)。
/// ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中は本番の状態の URL へ通信せず nil を返す
@MainActor
func readMaintenanceStateAtLaunch() async -> MaintenanceState? {
    if isUnitTest { return nil }
    return await fetchMaintenanceState(stateURL: maintenanceStateURL)
}

/// 起動時に読んだ状態から決めた、アプリの一番上に出す画面
enum MaintenanceResolution: Equatable {
    /// メンテナンス中。メンテナンス中の画面だけを出し、本来の画面を作らない
    case maintenance(MaintenanceState)
    /// メンテナンス中でないか、状態を読めなかった。本来の画面を出す
    case normal
}

/// アプリの一番上に置き、起動時に 1 回だけ状態を読んで、メンテナンス中ならメンテナンス中の画面だけを、そうでなければ content を出す。
/// 前面に戻った時と時間の経過では読み直さない (owner の決定。service-maintenance-setup skill の SKILL.md「SwiftUI と Expo に組み込む」)
struct MaintenanceResolver<Content: View>: View {
    /// 状態を読む処理 (読めない時は nil を返す)。テストで差し替える
    let fetch: @MainActor () async -> MaintenanceState?
    /// メンテナンス中でない時に出す本来の画面
    @ViewBuilder let content: () -> Content
    /// 読み終えた結果。読み終わるまでは nil
    @State private var resolution: MaintenanceResolution?

    /// 読み終わるまではアプリの背景の色だけを、読み終えたら resolution に応じた画面を出す
    var body: some View {
        Group {
            switch resolution {
            case nil:
                // 本来の画面を先に出すと、メンテナンス中の時に本来の画面が一瞬見えて処理も始まるため、背景の色だけを出す
                Color.ink.ignoresSafeArea()
            case .normal:
                content()
            case .maintenance(let maintenanceState):
                MaintenancePage(message: maintenanceState.message, button: maintenanceState.button)
            }
        }
        .task {
            // 読み終えた後は読み直さない。中身が入れ替わった時に .task が走り直しても、結果を変えないため
            guard resolution == nil else { return }
            let maintenanceState = await fetch()
            resolution = maintenanceState?.maintenance == true ? maintenanceState.map(MaintenanceResolution.maintenance) : .normal
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

    /// message (無ければ既定の文) と、button がある時だけそのボタンを並べた画面
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
