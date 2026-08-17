import AVFoundation
import SwiftUI
import UIKit

/// インカメラ動画回答の録画セッション。
/// AVCaptureFileOutputRecordingDelegate が NSObject 準拠の class を要求するため class にしている。
/// startRunning 等のブロッキング API を UI (朝の最も遅延に敏感な画面) から遠ざけるため、
/// セッションの構成・起動・録画は sessionQueue 上で行い、画面が参照する状態は MainActor 側で更新する
@MainActor
@Observable
final class VideoAnswerCamera: NSObject, AVCaptureFileOutputRecordingDelegate {
    /// セッションが起動してプレビューを表示できる状態かどうか
    private(set) var isSessionRunning = false
    /// 録画中かどうか (録画開始のデリゲート通知で true になる)
    private(set) var isRecording = false
    /// 録画が正常に停止して出力ファイルが確定した時に呼ばれる
    var onFinished: ((URL) -> Void)?
    /// 録画がエラーで失敗した時に呼ばれる (エラーメッセージは加工せずそのまま渡す)
    var onRecordingFailed: ((String) -> Void)?
    /// インカメラ・マイクを構成できなかった時に呼ばれる (シミュレータ等のカメラ非搭載環境)。テキスト入力へのフォールバックに使う
    var onUnavailable: (() -> Void)?

    // セッション関連のオブジェクトは sessionQueue 上での構成・操作と、
    // プレビューレイヤーへの接続 (AVCaptureVideoPreviewLayer.session への代入は main) だけに使い、
    // 排他は sessionQueue への直列ディスパッチで保証するため nonisolated(unsafe) にしている
    /// カメラ・マイクの入力と動画ファイル出力を束ねるセッション。プレビューレイヤーにも接続する
    nonisolated(unsafe) let session = AVCaptureSession()
    /// 動画ファイルへの録画出力
    private nonisolated(unsafe) let movieOutput = AVCaptureMovieFileOutput()
    /// セッションの構成・起動・録画操作を直列に実行するキュー
    private nonisolated let sessionQueue = DispatchQueue(label: "com.bannzai.MementoMorning.video-answer-camera")

    #if DEBUG
    /// 疑似録画モード (issue #52) で動作しているかどうか。
    /// start() の時点の設定値で固定し、録画中にトグルを切り替えても
    /// 開始と停止で実カメラと疑似録画が混ざらないようにする
    private var isSimulating = false
    #endif

    /// インカメラ + マイクでセッションを構成して起動する。
    /// 構成済みなら再構成せず起動だけやり直すため何度呼んでも安全 (冪等)。
    /// カメラまたはマイクのデバイスを取得できない環境では onUnavailable を呼んで何も起動しない
    func start() {
        #if DEBUG
        isSimulating = isDebugSimulateVideoAnswerEnabled
        if isSimulating {
            // 疑似録画モードではカメラを構成しない。プレビューは表示されないが (背景の墨色のまま)、
            // 録画ボタンを押せる状態にして以降のパイプラインを本物のコードで通す
            isSessionRunning = true
            return
        }
        #endif
        sessionQueue.async { [self] in
            if session.inputs.isEmpty {
                session.beginConfiguration()
                guard let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let cameraInput = try? AVCaptureDeviceInput(device: cameraDevice),
                      session.canAddInput(cameraInput),
                      let microphoneDevice = AVCaptureDevice.default(for: .audio),
                      let microphoneInput = try? AVCaptureDeviceInput(device: microphoneDevice),
                      session.canAddInput(microphoneInput),
                      session.canAddOutput(movieOutput) else {
                    session.commitConfiguration()
                    Task { @MainActor in self.onUnavailable?() }
                    return
                }
                session.addInput(cameraInput)
                session.addInput(microphoneInput)
                session.addOutput(movieOutput)
                // 寝落ち等で録画が止まらないまま端末の空き容量を使い切らないよう上限を設ける。
                // 3 分は朝のひと言の回答には十分な長さで、上限到達時は AVFoundation が録画を停止して
                // 通常の完了デリゲート (成功扱い) を呼ぶため、そのまま回答として保存される
                movieOutput.maxRecordedDuration = CMTime(seconds: 180, preferredTimescale: 600)
                session.commitConfiguration()
                // 実行中のセッションが復旧不能なエラーで止まった場合もテキスト入力へフォールバックさせる
                NotificationCenter.default.addObserver(
                    forName: AVCaptureSession.runtimeErrorNotification,
                    object: session,
                    queue: nil
                ) { _ in
                    Task { @MainActor in
                        self.isSessionRunning = false
                        self.onUnavailable?()
                    }
                }
            }
            session.startRunning()
            let isRunning = session.isRunning
            Task { @MainActor in
                self.isSessionRunning = isRunning
                // 構成に成功しても起動に失敗する場合 (カメラの一時的な利用不可等) がある。
                // プレビューも録画もできないため、権限拒否・デバイス無しと同じくフォールバックへ通知する
                if !isRunning {
                    self.onUnavailable?()
                }
            }
        }
    }

    /// セッションを停止する (画面を離れる時に呼ぶ)
    func stop() {
        #if DEBUG
        if isSimulating {
            isSessionRunning = false
            return
        }
        #endif
        sessionQueue.async { [self] in
            session.stopRunning()
            Task { @MainActor in self.isSessionRunning = false }
        }
    }

    /// 一時ディレクトリ内の一意なファイルへ録画を開始する。
    /// 出力ファイルは写真ライブラリへの保存が成功した後に呼び出し側が削除する
    func startRecording() {
        #if DEBUG
        if isSimulating {
            isRecording = true
            return
        }
        #endif
        sessionQueue.async { [self] in
            guard session.isRunning, !movieOutput.isRecording else { return }
            if let connection = movieOutput.connection(with: .video) {
                // アプリは縦向き固定 (MementoMorning ターゲットの UISupportedInterfaceOrientations) のため、
                // 保存される動画も縦向き (90°) に固定する (未指定だと横向きで保存され、写真アプリで横倒しに再生される)
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            movieOutput.startRecording(
                to: FileManager.default.temporaryDirectory
                    .appendingPathComponent("video-answer-\(UUID().uuidString)")
                    .appendingPathExtension("mov"),
                recordingDelegate: self
            )
        }
    }

    /// 録画を停止する。停止後の出力ファイル確定はデリゲート経由で onFinished / onRecordingFailed に通知される
    func stopRecording() {
        #if DEBUG
        if isSimulating {
            // 録画していない状態での停止 (テキスト入力への切り替え時にも呼ばれる) は
            // 実録画側が movieOutput.isRecording で弾くのと同じく何もしない
            guard isRecording else { return }
            isRecording = false
            do {
                onFinished?(try copyDebugVideoAnswerFixtureToTemporaryDirectory())
            } catch {
                onRecordingFailed?("\(error)")
            }
            return
        }
        #endif
        sessionQueue.async { [self] in
            movieOutput.stopRecording()
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            isRecording = true
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        // AVFoundation は容量不足等で録画が途中終了した場合、ファイルが有効でも error を渡してくる。
        // userInfo の AVErrorRecordingSuccessfullyFinishedKey が true なら成功として扱う (Apple のリファレンス記載の挙動)
        let isSuccessfullyFinished: Bool
        if let error {
            isSuccessfullyFinished = ((error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
        } else {
            isSuccessfullyFinished = true
        }
        Task { @MainActor in
            isRecording = false
            if isSuccessfullyFinished {
                onFinished?(outputFileURL)
            } else if let error {
                onRecordingFailed?("\(error)")
            }
        }
    }
}

/// AVCaptureVideoPreviewLayer を背面レイヤーとして持つ UIView。
/// layerClass の差し替えで view のサイズ変化にレイヤーが自動追従する
private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    /// 背面レイヤーをプレビューレイヤーとして返す
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// カメラプレビュー (AVCaptureVideoPreviewLayer の SwiftUI ラッパー)
struct CameraPreviewView: UIViewRepresentable {
    /// 表示するセッション
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        // アプリは縦向き固定 (MementoMorning ターゲットの UISupportedInterfaceOrientations) のため、
        // プレビューも縦向き (90°) に固定する (保存動画の向きと合わせる)
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
