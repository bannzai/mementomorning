import SwiftUI

/// 動画回答の録画ボタンと、録画中のインジケーター (issue #71)。
/// 録画には上限 (videoAnswerMaxRecordingDuration = 10 秒) があり、到達すると VideoAnswerCamera が自動で停止するため、
/// 録画中は開始時刻を基準に 0.1 秒ごとに経過時間を取り直し、タイマーと録画ボタンのリングで上限までの進み具合を示す。
/// 上限は VideoAnswerCamera の全インスタンスに効くため、朝の問い (MorningQuestionPage) とオンボーディングの練習 (OnboardingPage) の
/// 両方でこの View を使い、どちらの録画でも自動停止の予告が見えるようにする。
/// インジケーターは録画ボタンの上に置き、ボタンとその下の導線の位置は録画の前後で動かさない
struct VideoAnswerRecordingControls: View {
    /// 操作対象の録画セッション
    let camera: VideoAnswerCamera
    /// セッション未起動以外で録画ボタンを無効にする条件 (朝の問いでは回答の保存中)
    let isDisabled: Bool
    /// 録画中の録画ボタンの読み上げ。朝の問いでは停止 = 回答確定のため、練習とは文言が異なる
    let stopAccessibilityLabel: Text
    /// accessibilityIdentifier の接頭辞。録画ボタンは `<接頭辞>_record_button`、タイマーは `<接頭辞>_recording_timer` になる
    let accessibilityIdentifierPrefix: String

    var body: some View {
        if let recordingStartedAt = camera.recordingStartedAt {
            TimelineView(.periodic(from: recordingStartedAt, by: 0.1)) { context in
                let elapsed = context.date.timeIntervalSince(recordingStartedAt)
                VStack(spacing: 16) {
                    recordingIndicator(elapsed: elapsed)
                    recordButton(recordingElapsed: elapsed)
                }
            }
        } else {
            recordButton(recordingElapsed: nil)
        }
    }

    /// 録画中の点 (夜明け色・ゆっくり明滅) と mono 数字のタイマー (`0:03 / 0:10` = 経過 / 上限)。
    /// design_handoff_memento_morning/README.md「朝の問い」の録画中表示に沿い、SNS 的な赤い REC は使わない
    private func recordingIndicator(elapsed: TimeInterval) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.dawn)
                .frame(width: 6, height: 6)
                .opacity(videoAnswerRecordingDotOpacity(elapsed: elapsed))
            Text(videoAnswerRecordingTimerText(elapsed: elapsed))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.warmWhite.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix)_recording_timer")
    }

    /// 録画の開始/停止ボタン。録画中は停止の印として夜明け色の角丸を表示し、
    /// 外リングを上限 (10 秒) までの進み具合ぶんだけ夜明け色で埋める (recordingElapsed は録画中の経過秒。録画前は nil)
    private func recordButton(recordingElapsed: TimeInterval?) -> some View {
        Button {
            if camera.isRecording {
                camera.stopRecording()
            } else {
                camera.startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.warmWhite.opacity(0.8), lineWidth: 3)
                    .frame(width: 72, height: 72)
                if let recordingElapsed {
                    Circle()
                        .trim(from: 0, to: videoAnswerRecordingProgress(elapsed: recordingElapsed))
                        .stroke(Color.dawn, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        // 12 時の位置から時計回りに埋める
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                }
                if camera.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.dawn)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.warmWhite)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .disabled(!camera.isSessionRunning || isDisabled)
        .accessibilityLabel(
            camera.isRecording
                ? stopAccessibilityLabel
                // ja: 録画を始める
                : Text("Start recording")
        )
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix)_record_button")
    }
}
