import SwiftUI
import UIKit

/// 開発者用のログ画面。stopIntent の実行痕跡ログを表示し、問い合わせ時に添えられるようコピーできるようにする。
/// 設定画面 (AlarmSettingPage) に直接出していたスパイクログを、この画面へ移して奥に隠した (issue #103)
struct DeveloperLogPage: View {
    /// issue #2 スパイク検証の痕跡ログ。StopAlarmIntent.perform() が書き込む
    @AppStorage(.stopIntentSpikeLog) private var stopIntentSpikeLog: String?

    var body: some View {
        Form {
            Section {
                if let stopIntentSpikeLog, !stopIntentSpikeLog.isEmpty {
                    Text(verbatim: stopIntentSpikeLog)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier("developer_log_text")
                    Button {
                        UIPasteboard.general.string = stopIntentSpikeLog
                    } label: {
                        Label {
                            // ja: ログをコピー
                            Text("Copy Log")
                        } icon: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    .accessibilityIdentifier("developer_log_copy_button")
                    Button(role: .destructive) {
                        self.stopIntentSpikeLog = nil
                    } label: {
                        // ja: ログを消去
                        Text("Clear Log")
                    }
                    .accessibilityIdentifier("developer_log_clear_button")
                } else {
                    // ja: ログはありません
                    Text("No logs")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("developer_log_empty")
                }
            } header: {
                // ログの実体は stopIntent スパイク検証 (issue #2) の技術ログのため、名前は訳さずそのまま表示する
                Text(verbatim: "stopIntent Spike Log (issue #2)")
            } footer: {
                // ja: 問い合わせの際は、このログをコピーして添えてください。
                Text("When contacting support, copy this log and attach it to your message.")
            }
        }
        // ja: 開発者用のログ
        .navigationTitle(String(localized: "Developer Log"))
    }
}

/// DeveloperLogPage の Preview
struct DeveloperLogPage_Previews: PreviewProvider {
    static var previews: some View {
        // スパイクログが 2 行ある状態
        let _ = UserDefaults.standard.set(
            "2026-08-22T07:00:00Z perform() start appState=background\n2026-08-22T07:00:01Z schedule() success",
            forKey: .stopIntentSpikeLog
        )
        NavigationStack {
            DeveloperLogPage()
        }
    }
}
