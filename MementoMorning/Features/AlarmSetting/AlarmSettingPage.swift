import SwiftUI
import SwiftData

/// 毎朝のアラーム設定画面。設定できるのは時刻と ON/OFF だけ (設定要素は最小限)
struct AlarmSettingPage: View {
    /// モデルコンテキスト
    @Environment(\.modelContext) private var modelContext
    /// 画面の dismiss
    @Environment(\.dismiss) private var dismiss
    /// 保存済みのアラーム設定。単一レコード運用のため先頭 1 件のみ使う
    @Query private var alarmSettings: [AlarmSetting]
    /// DatePicker 入力用。保存時に hour/minute へ分解する
    @State private var time: Date = .now
    /// アラームの有効フラグ
    @State private var isEnabled: Bool = true
    /// 保存に失敗した場合のエラー。nil 以外でアラート表示する
    @State private var saveError: String?
    /// 直近の再スケジュールで発生したエラー。Rescheduler が書き込み、成功時に削除される
    @AppStorage(.lastRescheduleError) private var lastRescheduleError: String?
    /// issue #2 スパイク検証の痕跡ログ。StopAlarmIntent.perform() が書き込む
    @AppStorage(.stopIntentSpikeLog) private var stopIntentSpikeLog: String?
    /// 保存処理 (再スケジュール完了待ち) の実行中かどうか。
    /// true の間は保存ボタンを無効化し、連打による複数 Task の並行起動を防ぐ
    /// (先発の Task が dismiss した後に後発の Task が失敗しても、表示先の画面が残らないため)
    @State private var isSaving: Bool = false

    var body: some View {
        Form {
            // ja: アラーム
            Toggle(String(localized: "Alarm"), isOn: $isEnabled)
            // ja: 時刻
            DatePicker(String(localized: "Time"), selection: $time, displayedComponents: .hourAndMinute)
            if let lastRescheduleError, !lastRescheduleError.isEmpty {
                // エラーメッセージはそのまま表示する (加工しない)
                Text(lastRescheduleError)
                    .foregroundStyle(.red)
            }
            // stopIntent の実行痕跡を実機上で Mac なしに読むための一時セクション。
            // 検証専用 UI のためローカライズ対象にしない (verbatim)。実機検証の完了後にセクションごと削除する
            if let stopIntentSpikeLog, !stopIntentSpikeLog.isEmpty {
                Section {
                    Text(verbatim: stopIntentSpikeLog)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button(role: .destructive) {
                        self.stopIntentSpikeLog = nil
                    } label: {
                        Text(verbatim: "Clear Spike Log")
                    }
                } header: {
                    Text(verbatim: "stopIntent Spike Log (issue #2)")
                }
            }
        }
        // ja: アラーム
        .navigationTitle(String(localized: "Alarm"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // ja: 保存
                Button(String(localized: "Save")) {
                    save()
                }
                .disabled(isSaving)
            }
        }
        // ja: 保存に失敗しました
        .alert(String(localized: "Failed to save"), isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            // ja: OK
            Button(String(localized: "OK")) { saveError = nil }
        } message: {
            // エラーメッセージはそのまま表示する (加工しない)
            Text(saveError ?? "")
        }
        .onAppear {
            guard let alarmSetting = alarmSettings.first else { return }
            var components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: .now)
            components.hour = alarmSetting.hour
            components.minute = alarmSetting.minute
            if let date = Calendar.autoupdatingCurrent.date(from: components) {
                time = date
            }
            isEnabled = alarmSetting.isEnabled
        }
    }

    /// 入力内容を保存して再スケジュールする
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        if let alarmSetting = alarmSettings.first {
            alarmSetting.setTime(hour: hour, minute: minute)
            alarmSetting.setIsEnabled(isEnabled: isEnabled)
        } else {
            modelContext.insert(AlarmSetting(hour: hour, minute: minute, isEnabled: isEnabled))
        }
        do {
            try modelContext.save()
        } catch {
            // 永続化されていない変更を mainContext に残すと、次回の foreground 復帰で
            // reschedule がその未保存の値を fetch してしまうため、変更を破棄してから中断する
            modelContext.rollback()
            saveError = "\(error)"
            isSaving = false
            return
        }
        Task {
            await reschedule(modelContext: modelContext)
            // dismiss 後は lastRescheduleError の表示先 (この画面) が無くなるため、
            // 再スケジュールの完了を待ってから、失敗時は画面を閉じずにエラーを表示する
            if let error = UserDefaults.standard.string(forKey: .lastRescheduleError) {
                saveError = error
                isSaving = false
            } else {
                dismiss()
            }
        }
    }
}

/// AlarmSettingPage の Preview
struct AlarmSettingPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 毎朝 7:00 に鳴る有効なアラーム設定
        let _ = modelContext.insert(AlarmSetting(hour: 7, minute: 0))
        let _ = try! modelContext.save()

        NavigationStack {
            AlarmSettingPage()
        }
        .modelContainer(container)
    }
}
