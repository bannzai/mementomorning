import Observation
import SwiftUI
import XCTest
@testable import MementoMorning

/// メンテナンス中の画面の出し分け (fetchMaintenanceState・MaintenanceResolver) のテスト。
/// owner の `service-maintenance on mementomorning` の後に起動したアプリがメンテナンス中の画面だけを出し、
/// 状態を読めない時は本来の画面を出し、状態は起動時に 1 回だけ読むことを固定する (https://github.com/bannzai/castle/issues/3490 )
@MainActor
final class ServiceMaintenanceTests: XCTestCase {
    /// テストで読む状態の URL。StubURLProtocol が応答するため、実際には通信しない
    private let stateURL = URL(string: "https://service-maintenance.example.test/mementomorning")!

    /// owner がメンテナンス中にした、message と button の無い状態の JSON
    private let maintenanceOwnerJSON = #"{"maintenance":true,"message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#

    /// maintenanceOwnerJSON を読んだ状態
    private func maintenanceOwnerState() -> MaintenanceState {
        try! JSONDecoder().decode(MaintenanceState.self, from: Data(maintenanceOwnerJSON.utf8))
    }

    /// テストで window に載せた画面。tearDown で外す
    private var hostedWindow: UIWindow?

    /// テストごとに差し替えた応答を消し、載せた画面を外す
    override func tearDown() {
        StubURLProtocol.respond = nil
        hostedWindow?.isHidden = true
        hostedWindow = nil
        super.tearDown()
    }

    /// StubURLProtocol だけで応答するセッション
    private func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// 状態を返す Worker と同じ形の JSON の本文 body を、statusCode (既定は Worker が状態を返す時の 200) で返す
    private func respondJSON(body json: String, statusCode: Int = 200) {
        StubURLProtocol.respond = { request in
            .response(HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
    }

    /// rootView をアプリの window scene の新しい window に載せて表示する (SwiftUI の .task を実際に走らせるため)
    private func host(rootView: some View) -> UIHostingController<AnyView> {
        let window = UIWindow(windowScene: UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!)
        let hostingController = UIHostingController(rootView: AnyView(rootView))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostedWindow = window
        return hostingController
    }

    /// condition が成り立つか、上限の 2 秒が過ぎるまで待つ。
    /// 2 秒は、画面に載せてから .task が走って結果を反映するまでに CI の遅さを見込んでも足り、成り立たない時にテストを長く止めない上限。
    /// 5 ミリ秒は、条件を見直す刻みとして 2 秒の上限に比べて十分に細かい値
    private func wait(condition: () -> Bool) async {
        let deadline = Date.now.addingTimeInterval(2)
        while !condition(), Date.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
    }

    /// 結果が出た後に、画面が作り直されるのを待つ時間。
    /// 300 ミリ秒は、状態の反映から再描画までに CI の遅さを見込んでも足りる長さ
    private func waitForRedraw() async {
        try? await Task.sleep(for: .milliseconds(300))
    }

    // MARK: - 読む URL

    /// ビルドが Config.xcconfig の本番の状態の URL を読むこと
    func testBuildReadsProductionStateURL() {
        // xcconfig は // 以降をコメントとして読むため、Config.xcconfig の書き方を誤ると "https:" だけが残る
        XCTAssertEqual(maintenanceStateURL, URL(string: "https://service-maintenance.star-kojiki.workers.dev/mementomorning"))
    }

    /// Info.plist の値が無い・文字列でない・URL にできない時は状態を読まない (nil) こと
    func testMissingOrInvalidInfoPlistValueReadsNoState() {
        XCTAssertNil(parseMaintenanceStateURL(infoPlistValue: nil), "値が無い")
        XCTAssertNil(parseMaintenanceStateURL(infoPlistValue: 1), "文字列でない")
        XCTAssertNil(parseMaintenanceStateURL(infoPlistValue: ""), "空文字は URL にできない")
        XCTAssertEqual(
            parseMaintenanceStateURL(infoPlistValue: "http://localhost:8000/mementomorning"),
            URL(string: "http://localhost:8000/mementomorning"),
            "文字列の URL はそのまま使う"
        )
    }

    // MARK: - 切り替え

    /// maintenance: true・false と message・button をそのまま読むこと
    func testFetchReadsMaintenanceTrueAndFalse() async {
        respondJSON(body: #"{"maintenance":true,"message":"Stopped for a while","button":{"label":"Status","url":"https://example.com/status"},"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#)
        let maintenanceState = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
        XCTAssertEqual(maintenanceState?.maintenance, true)
        XCTAssertEqual(maintenanceState?.message, "Stopped for a while")
        XCTAssertEqual(maintenanceState?.button?.label, "Status")
        XCTAssertEqual(maintenanceState?.button?.url, URL(string: "https://example.com/status"))

        respondJSON(body: #"{"maintenance":false,"message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:01:00.000Z"}"#)
        let normalState = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
        XCTAssertEqual(normalState?.maintenance, false)
    }

    // MARK: - 読めない時は通常どおり

    /// 状態の URL が無いビルドでは通信せず、メンテナンス中でないとすること
    func testNilStateURLReadsNoStateWithoutRequest() async {
        var requestCount = 0
        StubURLProtocol.respond = { request in
            requestCount += 1
            return .response(HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(self.maintenanceOwnerJSON.utf8))
        }
        let state = await fetchMaintenanceState(stateURL: nil, session: stubSession())
        XCTAssertNil(state, "状態の URL が無い時は読まない")
        XCTAssertEqual(requestCount, 0, "状態の URL が無い時は通信しない")
    }

    /// source の許可リストの項目 (owner・cost・usage) はどれも状態として読み、似ているが違う値は読まないこと
    func testFetchAcceptsEachAllowedSourceOnly() async {
        for source in ["owner", "cost", "usage"] {
            respondJSON(body: #"{"maintenance":true,"message":null,"button":null,"source":""# + source + #"","changedAt":"2026-11-28T00:00:00.000Z"}"#)
            let maintenanceState = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
            XCTAssertEqual(maintenanceState?.source, source, "許可リストの source は読む: \(source)")
        }
        for source in ["Cost", "costs", "Owner", " usage", ""] {
            respondJSON(body: #"{"maintenance":true,"message":null,"button":null,"source":""# + source + #"","changedAt":"2026-11-28T00:00:00.000Z"}"#)
            let maintenanceState = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
            XCTAssertNil(maintenanceState, "許可リストに似ているが違う source は読まない: \(source)")
        }
    }

    /// 通信に失敗したら読めなかったとすること
    func testNetworkFailureIsNotMaintenance() async {
        StubURLProtocol.respond = { _ in .failure(URLError(.notConnectedToInternet)) }
        let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
        XCTAssertNil(state, "通信に失敗したら通常どおり動かす")
    }

    /// 応答が返らない時は待つ上限で打ち切り、読めなかったとすること
    func testTimeoutIsNotMaintenance() async {
        // 応答を返さない (timeoutInterval が切れるまで待たせる)
        StubURLProtocol.respond = { _ in .noResponse }
        let startedAt = Date.now
        let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession(), timeout: 0.3)
        XCTAssertNil(state, "時間切れは読めなかったとして扱う")
        // 待つ上限を渡さないと URLRequest の既定の 60 秒まで待つため、上限で打ち切ったことを経過時間で確かめる
        // (10 秒は 0.3 秒の上限に CI の遅さを見込んだ余裕を足し、既定の 60 秒とは区別できる値)
        XCTAssertLessThan(Date.now.timeIntervalSince(startedAt), 10, "待つ上限で打ち切る")
    }

    /// 200 以外の応答は本文によらず使わないこと
    func testNon200IsNotMaintenance() async {
        respondJSON(body: maintenanceOwnerJSON, statusCode: 500)
        let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
        XCTAssertNil(state, "200 以外の応答は、本文が maintenance: true でも使わない")
    }

    /// 形の違う応答は読めなかったとすること
    func testMalformedResponsesAreNotMaintenance() async {
        for body in [
            "not json",
            "{}",
            #"{"maintenance":"true","message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"message":null,"button":null,"source":"someone","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"message":null,"button":null,"source":"owner"}"#,
            #"{"maintenance":true,"message":null,"button":null,"changedAt":"2026-11-27T00:00:00.000Z"}"#,
        ] {
            respondJSON(body: body)
            let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
            XCTAssertNil(state, "形の違う応答は使わない: \(body)")
        }
    }

    // MARK: - message と button の形

    /// message と button の形が違っても maintenance は落とさず、その項目だけを使わないこと
    func testMalformedMessageAndButtonKeepMaintenance() async {
        for body in [
            #"{"maintenance":true,"message":"","button":{"label":"","url":"https://example.com"},"source":"usage","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"message":1,"button":{"label":"Open","url":"javascript:alert(1)"},"source":"usage","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"button":"Open","source":"usage","changedAt":"2026-11-27T00:00:00.000Z"}"#,
        ] {
            respondJSON(body: body)
            let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
            XCTAssertEqual(state?.maintenance, true, "message と button の形が違っても切り替えは落とさない: \(body)")
            XCTAssertNil(state?.message, "空・文字列でない message は使わない (既定の文を出す): \(body)")
            XCTAssertNil(state?.button, "label が空・http(s) でない URL・形の違う button は出さない: \(body)")
        }
    }

    /// http と https の URL の button はそのまま出すこと
    func testHTTPAndHTTPSButtonsAreShown() async {
        for url in ["http://example.com/status", "https://example.com/status"] {
            respondJSON(body: #"{"maintenance":true,"message":null,"button":{"label":"Status","url":""# + url + #""},"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#)
            let buttonURL = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())?.button?.url
            XCTAssertEqual(buttonURL, URL(string: url), "http(s) の button は出す: \(url)")
        }
    }

    // MARK: - MaintenanceResolver

    /// メンテナンス中の時は、本来の画面を作らないこと
    func testResolverDoesNotBuildContentInMaintenance() async {
        var fetchCount = 0
        var contentBuildCount = 0
        _ = host(rootView: MaintenanceResolver(fetch: {
            fetchCount += 1
            return self.maintenanceOwnerState()
        }) {
            let _ = { contentBuildCount += 1 }()
            Text("content")
        })
        await wait { fetchCount == 1 }
        await waitForRedraw()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(contentBuildCount, 0, "メンテナンス中は本来の画面を作らない")
    }

    /// メンテナンス中でない時は、本来の画面を出すこと
    func testResolverBuildsContentWhenNotInMaintenance() async {
        var contentBuildCount = 0
        _ = host(rootView: MaintenanceResolver(fetch: {
            try! JSONDecoder().decode(
                MaintenanceState.self,
                from: Data(#"{"maintenance":false,"message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#.utf8)
            )
        }) {
            let _ = { contentBuildCount += 1 }()
            Text("content")
        })
        await wait { contentBuildCount > 0 }
        XCTAssertGreaterThan(contentBuildCount, 0, "メンテナンス中でない時は本来の画面を出す")
    }

    /// 状態を読めない時 (通信の失敗・時間切れ・形の違う応答。どれも fetchMaintenanceState が nil を返す) は、本来の画面を出すこと
    func testResolverBuildsContentWhenStateIsUnreadable() async {
        var contentBuildCount = 0
        _ = host(rootView: MaintenanceResolver(fetch: { nil }) {
            let _ = { contentBuildCount += 1 }()
            Text("content")
        })
        await wait { contentBuildCount > 0 }
        XCTAssertGreaterThan(contentBuildCount, 0, "状態を読めない時は本来の画面を出す")
    }

    /// 読み終わるまでは、本来の画面を作らないこと (メンテナンス中の時に本来の画面が一瞬見えて処理も始まらないため)
    func testResolverDoesNotBuildContentBeforeStateIsRead() async {
        var contentBuildCount = 0
        var pendingFetch: CheckedContinuation<MaintenanceState?, Never>?
        _ = host(rootView: MaintenanceResolver(fetch: {
            await withCheckedContinuation { pendingFetch = $0 }
        }) {
            let _ = { contentBuildCount += 1 }()
            Text("content")
        })
        await wait { pendingFetch != nil }
        await waitForRedraw()
        XCTAssertEqual(contentBuildCount, 0, "読み終わるまでは本来の画面を作らない")
        pendingFetch?.resume(returning: nil)
        await wait { contentBuildCount > 0 }
        XCTAssertGreaterThan(contentBuildCount, 0, "読めなかったと分かった後に本来の画面を出す")
    }

    /// 前面と背面を切り替え、時間が経っても、状態の読み取りは起動時の 1 回のままであること
    func testResolverReadsOnlyOnceAcrossScenePhaseChangesAndTime() async {
        var fetchCount = 0
        let scenePhaseBox = ScenePhaseBox()
        _ = host(rootView: ScenePhaseOverride(scenePhaseBox: scenePhaseBox) {
            MaintenanceResolver(fetch: {
                fetchCount += 1
                return nil
            }) {
                Text("content")
            }
        })
        await wait { fetchCount == 1 }
        await waitForRedraw()
        // 背面に回って前面に戻る (同じ画面のまま scenePhase の環境値を書き換え、window を隠して出し直す)
        for scenePhase in [ScenePhase.inactive, .background, .active] {
            scenePhaseBox.scenePhase = scenePhase
            hostedWindow?.isHidden = scenePhase != .active
            await waitForRedraw()
        }
        // 1 秒は、読み直しの間隔を持つ実装 (以前の形は 60 秒) をこのテストでは区別できないが、
        // 前面に戻った直後に読み直す実装なら読み取りが増える長さ
        try? await Task.sleep(for: .seconds(1))
        XCTAssertEqual(fetchCount, 1, "状態は起動時に 1 回だけ読む")
    }

    /// ユニットテスト中 (TEST_HOST で実アプリが起動している間) は、本番の状態の URL へ通信しないこと
    func testReadMaintenanceStateAtLaunchDoesNotReadInUnitTests() async {
        let maintenanceState = await readMaintenanceStateAtLaunch()
        XCTAssertNil(maintenanceState)
    }

    /// 応答が少しずつ届き続けても、全体の待つ上限で打ち切ること (起動時の画面がこの読み取りを待つため)
    func testTrickleResponseIsCutOffAtOverallTimeout() async {
        StubURLProtocol.respond = { _ in .trickle(Data(self.maintenanceOwnerJSON.utf8)) }
        let startedAt = Date.now
        let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession(), timeout: 0.5)
        XCTAssertNil(state, "全体の上限を過ぎた応答は読めなかったとして扱う")
        // 2 秒は、0.5 秒の上限に CI の遅さを見込んだ余裕を足し、スタブが応答を終える 3 秒とは区別できる値
        XCTAssertLessThan(Date.now.timeIntervalSince(startedAt), 2, "全体の上限で打ち切る")
    }
}

/// テストで切り替える scenePhase の値。画面を作り直さずに環境値だけを変えるため、観測できる class で持つ
@Observable
private final class ScenePhaseBox {
    /// content に渡す scenePhase
    var scenePhase: ScenePhase = .active
}

/// content の scenePhase の環境値を scenePhaseBox の値で上書きする、テスト用の画面
private struct ScenePhaseOverride<Content: View>: View {
    /// 上書きする値
    let scenePhaseBox: ScenePhaseBox
    /// 上書きする画面
    @ViewBuilder let content: () -> Content

    /// content に scenePhaseBox の値を環境値として渡した画面
    var body: some View {
        content().environment(\.scenePhase, scenePhaseBox.scenePhase)
    }
}

/// テストの URLSession の応答を差し替える URLProtocol
private final class StubURLProtocol: URLProtocol {
    /// 差し替えた応答
    enum Stub {
        /// 応答と本文を返す
        case response(HTTPURLResponse, Data)
        /// 通信の失敗を返す
        case failure(Error)
        /// 何も返さない (時間切れを起こす)
        case noResponse
        /// 応答の頭を返した後、空白を 0.1 秒ごとに 1 文字ずつ 3 秒間送り、最後に本文を送って終える
        /// (データが届くたびに数え直す URLRequest.timeoutInterval では打ち切れない応答)
        case trickle(Data)
    }

    /// trickle の送信を止める印。stopLoading で立てる
    private var isStopped = false

    /// リクエストごとに返す応答。テストごとに設定する
    nonisolated(unsafe) static var respond: ((URLRequest) -> Stub)?

    /// テストのセッションのリクエストをすべてこの URLProtocol が受け持つ
    override class func canInit(with request: URLRequest) -> Bool { true }
    /// リクエストを書き換えずにそのまま使う
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// respond の応答を client に返す。respond が未設定の時は、テストが応答を決め忘れても状態を読めた扱いにしないため、通信の失敗を返す
    override func startLoading() {
        switch Self.respond?(request) ?? .failure(URLError(.badServerResponse)) {
        case let .response(response, data):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        case .noResponse:
            break
        case let .trickle(body):
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            // 0.1 秒ごとに 30 回で 3 秒。全体の上限 (テストでは 0.5 秒) より十分長く、データの間隔は上限より短い
            for index in 0...30 {
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100 * index)) { [weak self] in
                    guard let self, !self.isStopped else { return }
                    if index < 30 {
                        self.client?.urlProtocol(self, didLoad: Data(" ".utf8))
                    } else {
                        self.client?.urlProtocol(self, didLoad: body)
                        self.client?.urlProtocolDidFinishLoading(self)
                    }
                }
            }
        }
    }

    /// trickle の送信を止める (読み取りを取り消した時に URLSession が呼ぶ)
    override func stopLoading() {
        isStopped = true
    }
}
