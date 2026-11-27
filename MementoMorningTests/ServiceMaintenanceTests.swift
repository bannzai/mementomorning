import XCTest
@testable import MementoMorning

/// メンテナンス中の画面の切り替え (MaintenanceStateReader・fetchMaintenanceState) のテスト。
/// owner の `service-maintenance on/off mementomorning` で画面が切り替わり、状態を読めない時は通常どおり動くことを固定する
/// (https://github.com/bannzai/castle/issues/3490 )
@MainActor
final class ServiceMaintenanceTests: XCTestCase {
    /// テストで読む状態の URL。StubURLProtocol が応答するため、実際には通信しない
    private let stateURL = URL(string: "https://service-maintenance.example.test/mementomorning")!

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
        MaintenanceStateReader { await fetchMaintenanceState(stateURL: self.stateURL, session: self.stubSession(), timeout: 0.5) }
    }

    /// 状態を返す Worker と同じ形の JSON を 200 で返す
    private func respondJSON(_ json: String, statusCode: Int = 200) {
        StubURLProtocol.respond = { request in
            .response(HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
    }

    // MARK: - 読む URL

    func testBuildReadsProductionStateURL() {
        // xcconfig は // 以降をコメントとして読むため、Config.xcconfig の書き方を誤ると "https:" だけが残る
        XCTAssertEqual(maintenanceStateURL, URL(string: "https://service-maintenance.star-kojiki.workers.dev/mementomorning"))
    }

    // MARK: - 切り替え

    func testMaintenanceTrueShowsMaintenancePageAndFalseReturnsToNormal() async {
        let reader = stubReader()
        XCTAssertFalse(reader.isInMaintenance, "読む前は通常の画面")

        respondJSON(#"{"maintenance":true,"message":"Stopped for a while","button":{"label":"Status","url":"https://example.com/status"},"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#)
        await reader.read()
        XCTAssertTrue(reader.isInMaintenance, "maintenance: true でメンテナンス中の画面に変わる")
        XCTAssertEqual(reader.maintenanceState?.message, "Stopped for a while")
        XCTAssertEqual(reader.maintenanceState?.button?.label, "Status")
        XCTAssertEqual(reader.maintenanceState?.button?.url, URL(string: "https://example.com/status"))

        respondJSON(#"{"maintenance":false,"message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:01:00.000Z"}"#)
        await reader.read()
        XCTAssertFalse(reader.isInMaintenance, "maintenance: false で通常の画面に戻る")
    }

    // MARK: - 読めない時は通常どおり

    func testNetworkFailureAfterMaintenanceReturnsToNormal() async {
        let reader = stubReader()
        respondJSON(#"{"maintenance":true,"message":null,"button":null,"source":"cost","changedAt":"2026-11-27T00:00:00.000Z"}"#)
        await reader.read()
        XCTAssertTrue(reader.isInMaintenance)

        StubURLProtocol.respond = { _ in .failure(URLError(.notConnectedToInternet)) }
        await reader.read()
        XCTAssertFalse(reader.isInMaintenance, "通信に失敗したら通常どおり動かす")
        XCTAssertNil(reader.maintenanceState)
    }

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

    func testNon200IsNotMaintenance() async {
        respondJSON(#"{"maintenance":true,"message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#, statusCode: 500)
        let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
        XCTAssertNil(state, "200 以外の応答は、本文が maintenance: true でも使わない")
    }

    func testMalformedResponsesAreNotMaintenance() async {
        for body in [
            "not json",
            "{}",
            #"{"maintenance":"true","message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"message":null,"button":null,"source":"someone","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"message":null,"button":null,"source":"owner"}"#,
            #"{"maintenance":true,"message":null,"button":null,"changedAt":"2026-11-27T00:00:00.000Z"}"#,
        ] {
            respondJSON(body)
            let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
            XCTAssertNil(state, "形の違う応答は使わない: \(body)")
        }
    }

    // MARK: - message と button の形

    func testMalformedMessageAndButtonKeepMaintenance() async {
        for body in [
            #"{"maintenance":true,"message":"","button":{"label":"","url":"https://example.com"},"source":"usage","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"message":1,"button":{"label":"Open","url":"javascript:alert(1)"},"source":"usage","changedAt":"2026-11-27T00:00:00.000Z"}"#,
            #"{"maintenance":true,"button":"Open","source":"usage","changedAt":"2026-11-27T00:00:00.000Z"}"#,
        ] {
            respondJSON(body)
            let state = await fetchMaintenanceState(stateURL: stateURL, session: stubSession())
            XCTAssertEqual(state?.maintenance, true, "message と button の形が違っても切り替えは落とさない: \(body)")
            XCTAssertNil(state?.message, "空・文字列でない message は使わない (既定の文を出す): \(body)")
            XCTAssertNil(state?.button, "label が空・http(s) でない URL・形の違う button は出さない: \(body)")
        }
    }

    // MARK: - 読み取りの順序

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
        pendingFetches[0].resume(returning: try! JSONDecoder().decode(
            MaintenanceState.self,
            from: Data(#"{"maintenance":true,"message":null,"button":null,"source":"owner","changedAt":"2026-11-27T00:00:00.000Z"}"#.utf8)
        ))
        await olderRead.value
        XCTAssertFalse(reader.isInMaintenance, "古い読み取りの結果で新しい結果を上書きしない")
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

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

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

    override func stopLoading() {}
}
