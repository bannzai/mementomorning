import XCTest
@testable import MementoMorning

/// メンテナンス中の画面の切り替え (MaintenanceStateReader・fetchMaintenanceState) のテスト。
/// owner の `service-maintenance on/off mementomorning` で画面が切り替わり、状態を読めない時は通常どおり動くことを固定する
/// (https://github.com/bannzai/castle/issues/3490 )
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

    /// テストごとに差し替えた応答を消す
    override func tearDown() {
        StubURLProtocol.respond = nil
        super.tearDown()
    }

    /// StubURLProtocol だけで応答するセッション
    private func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// stateURL から stubSession で読む読み手
    private func stubReader() -> MaintenanceStateReader {
        // 0.5 秒は、StubURLProtocol がすぐに返す応答には十分で、応答を返さないスタブでもテストを長く止めない上限
        MaintenanceStateReader { await fetchMaintenanceState(stateURL: self.stateURL, session: self.stubSession(), timeout: 0.5) }
    }

    /// 状態を返す Worker と同じ形の JSON の本文 body を、statusCode (既定は Worker が状態を返す時の 200) で返す
    private func respondJSON(body json: String, statusCode: Int = 200) {
        StubURLProtocol.respond = { request in
            .response(HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
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

    /// maintenance: true でメンテナンス中、false で通常に戻ること
    func testMaintenanceTrueShowsMaintenancePageAndFalseReturnsToNormal() async {
        let reader = stubReader()
        XCTAssertFalse(reader.isInMaintenance, "読む前は通常の画面")

        respondJSON(body: #"{"maintenance":true,"message":"Stopped for a while","button":{"label":"Status","url":"https://example.com/status"},"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#)
        await reader.read()
        XCTAssertTrue(reader.isInMaintenance, "maintenance: true でメンテナンス中の画面に変わる")
        XCTAssertEqual(reader.maintenanceState?.message, "Stopped for a while")
        XCTAssertEqual(reader.maintenanceState?.button?.label, "Status")
        XCTAssertEqual(reader.maintenanceState?.button?.url, URL(string: "https://example.com/status"))

        respondJSON(body: #"{"maintenance":false,"message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:01:00.000Z"}"#)
        await reader.read()
        XCTAssertFalse(reader.isInMaintenance, "maintenance: false で通常の画面に戻る")
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

    /// メンテナンス中の後に通信に失敗したら通常に戻ること
    func testNetworkFailureAfterMaintenanceReturnsToNormal() async {
        let reader = stubReader()
        respondJSON(body: #"{"maintenance":true,"message":null,"button":null,"source":"cost","changedAt":"2026-11-27T00:00:00.000Z"}"#)
        await reader.read()
        XCTAssertTrue(reader.isInMaintenance)

        StubURLProtocol.respond = { _ in .failure(URLError(.notConnectedToInternet)) }
        await reader.read()
        XCTAssertFalse(reader.isInMaintenance, "通信に失敗したら通常どおり動かす")
        XCTAssertNil(reader.maintenanceState)
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

    // MARK: - 読み取りの順序

    /// 後から始めた読み取りの結果を、先に始めた読み取りが後から返って上書きしないこと
    func testOlderReadFinishingLaterDoesNotOverrideNewerResult() async {
        var pendingFetches: [CheckedContinuation<MaintenanceState?, Never>] = []
        let reader = MaintenanceStateReader {
            await withCheckedContinuation { pendingFetches.append($0) }
        }
        let olderRead = Task { await reader.read() }
        while pendingFetches.count < 1 { await Task.yield() }
        let newerRead = Task { await reader.read() }
        while pendingFetches.count < 2 { await Task.yield() }

        // 後から始めた読み取り (通常) が先に返り、先に始めた読み取り (メンテナンス中) が後から返る
        pendingFetches[1].resume(returning: nil)
        await newerRead.value
        pendingFetches[0].resume(returning: maintenanceOwnerState())
        await olderRead.value
        XCTAssertFalse(reader.isInMaintenance, "古い読み取りの結果で新しい結果を上書きしない")
    }

    /// 読み取りを呼んだ task がキャンセルされた時 (背面に回った時) の結果で、メンテナンス中の画面を外さないこと
    func testCancelledReadDoesNotOverrideMaintenance() async {
        var pendingFetches: [CheckedContinuation<MaintenanceState?, Never>] = []
        let reader = MaintenanceStateReader {
            await withCheckedContinuation { pendingFetches.append($0) }
        }
        let maintenanceRead = Task { await reader.read() }
        while pendingFetches.count < 1 { await Task.yield() }
        pendingFetches[0].resume(returning: maintenanceOwnerState())
        await maintenanceRead.value
        XCTAssertTrue(reader.isInMaintenance)

        let cancelledRead = Task { await reader.read() }
        while pendingFetches.count < 2 { await Task.yield() }
        cancelledRead.cancel()
        // 通信の取り消しで読めなかった (nil) として返る
        pendingFetches[1].resume(returning: nil)
        await cancelledRead.value
        XCTAssertTrue(reader.isInMaintenance, "キャンセルされた読み取りの nil でメンテナンス中の画面を外さない")
    }

    /// readRepeatedly は interval を待たずにすぐ 1 回読むこと (起動時・前面に戻った時の読み取りを遅らせないため)
    func testReadRepeatedlyReadsImmediately() async {
        var fetchCount = 0
        let polling = Task {
            // 60 秒は本番の読み直しの間隔で、テストの中では 2 回目の読み取りが起こらない長さ
            await MaintenanceStateReader {
                fetchCount += 1
                return nil
            }.readRepeatedly(interval: .seconds(60))
        }
        // 2 秒は、すぐに読む実装なら CI の遅さを見込んでも 1 回目の読み取りが済み、60 秒待つ実装とは区別できる上限
        let deadline = Date.now.addingTimeInterval(2)
        // 5 ミリ秒は、条件を見直す刻みとして 2 秒の上限に比べて十分に細かい値
        while fetchCount < 1, Date.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        // キャンセルの前に数える (先に待つ実装はキャンセルで待ちが切れて読むため、キャンセルの後では区別できない)
        let countBeforeCancel = fetchCount
        polling.cancel()
        await polling.value
        XCTAssertEqual(countBeforeCancel, 1, "interval を待たずに 1 回読む")
    }

    /// readRepeatedly は interval ごとに読み直し、呼んだ task のキャンセルで読むのをやめること
    func testReadRepeatedlyReadsEveryIntervalUntilCancelled() async {
        var fetchCount = 0
        let polling = Task {
            // 10 ミリ秒は、テストの所要時間を短くしつつ、読み直しが 3 回起こるのを待てる間隔
            await MaintenanceStateReader {
                fetchCount += 1
                return nil
            }.readRepeatedly(interval: .milliseconds(10))
        }
        // 2 秒は、10 ミリ秒ごとの読み直しが 3 回起こるのに CI の遅さを見込んでも足り、読み直さない実装でテストが止まらないための上限
        let deadline = Date.now.addingTimeInterval(2)
        // 5 ミリ秒は、条件を見直す刻みとして 2 秒の上限に比べて十分に細かい値
        while fetchCount < 3, Date.now < deadline { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertGreaterThanOrEqual(fetchCount, 3, "interval ごとに読み直す")
        polling.cancel()
        await polling.value
        let countAtCancel = fetchCount
        // 100 ミリ秒は 10 ミリ秒の読み直しの間隔の 10 回分で、キャンセルの後も読み続ける実装なら読み取りが増える長さ
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(fetchCount, countAtCancel, "キャンセルの後は読まない")
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
    }

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
        }
    }

    /// 止める処理は無い (応答を返さない noResponse でも、URLSession が時間切れで呼ぶだけのため)
    override func stopLoading() {}
}
