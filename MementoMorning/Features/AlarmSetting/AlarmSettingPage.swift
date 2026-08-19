import SwiftUI
import SwiftData

/// 毎朝のアラーム設定画面。設定できるのは時刻・ON/OFF・スヌーズ回数だけ (設定要素は最小限)
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
    /// スヌーズ (追撃アラーム) の上限回数の選択値。nil は無制限。
    /// 初期値は無料枠 freeTierSnoozeLimit で、保存済み設定があれば onAppear で effectiveSnoozeLimit に置き換える
    @State private var snoozeLimit: Int? = freeTierSnoozeLimit
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
    /// ペイウォールを表示中かどうか。無料状態でプレミアム限定のスヌーズ回数 (無料枠超・無制限) を選んだ時に開く
    @State private var isPaywallPresented = false

    /// RevenueCat の entitlement キャッシュ。値の変化で再描画を起こすために監視する (判定は PremiumEntitlement.isPremium が SSOT)
    @AppStorage(.premiumEntitlementActive) private var premiumEntitlementActive = false
    #if DEBUG
    /// 検証用のプレミアム強制フラグ。値の変化で再描画を起こすために監視する
    @AppStorage(.debugPremiumOverride) private var debugPremiumOverride = false
    #endif

    var body: some View {
        Form {
            // ja: アラーム
            Toggle(String(localized: "Alarm"), isOn: $isEnabled)
                // ON 色はホームの pill トグルと同じ夜明け色にする。親の tint (温白) のままだとトラックが白く、ON / OFF の区別がつかない (issue #73)
                .tint(Color.alarmToggleOn)
            // ja: 時刻
            DatePicker(String(localized: "Time"), selection: $time, displayedComponents: .hourAndMinute)
            // スヌーズ (追撃) の回数。無料は freeTierSnoozeLimit まで選べ、それ以上と無制限はプレミアム限定で、
            // 選ぶとペイウォールへ誘導する (issue #73。課金設計は documents/PROJECT.md)
            Picker(selection: $snoozeLimit) {
                ForEach(Array(snoozeLimitChoices), id: \.self) { count in
                    snoozeLimitOptionLabel(snoozeLimit: count)
                        .tag(Optional(count))
                }
                snoozeLimitOptionLabel(snoozeLimit: nil)
                    .tag(Int?.none)
            } label: {
                // ja: スヌーズ
                Text("Snooze")
            }
            .accessibilityIdentifier("alarm_setting_snooze_picker")
            .onChange(of: snoozeLimit) { oldValue, newValue in
                guard !isSnoozeLimitSelectable(snoozeLimit: newValue, isPremium: PremiumEntitlement.isPremium) else { return }
                // 無料で選べない回数は選択を戻し、代わりにペイウォールを開く (戻した値は選択可能なため再帰しない)
                snoozeLimit = oldValue
                isPaywallPresented = true
            }
            // 夜リマインドがいつ届くかを可視化する (issue #44)。時刻の SSOT は NightReminder の固定値 (カスタマイズはプレミアム機能で未実装)
            LabeledContent {
                Text(nightReminderTime, format: .dateTime.hour().minute())
            } label: {
                // ja: 夜のリマインド
                Text("Night reminder")
                // ja: 今朝の回答と答え合わせしましょう
                Text("Check tonight against this morning's answer.")
            }
            .accessibilityIdentifier("alarm_setting_night_reminder_row")
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
        .sheet(isPresented: $isPaywallPresented) {
            PaywallPage()
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
            snoozeLimit = effectiveSnoozeLimit(snoozeLimit: alarmSetting.snoozeLimit, isPremium: PremiumEntitlement.isPremium)
        }
    }

    /// スヌーズ回数の選択肢の文言。無制限は nil
    private func snoozeLimitText(snoozeLimit: Int?) -> Text {
        if let snoozeLimit {
            // ja: %lld 回
            return Text("\(snoozeLimit) times")
        }
        // ja: 無制限
        return Text("Unlimited")
    }

    /// スヌーズ回数の選択肢のラベル。無制限は nil。
    /// 現在の課金状態で選べない選択肢には錠前を付け、プレミアム限定であることを選ぶ前に示す
    @ViewBuilder
    private func snoozeLimitOptionLabel(snoozeLimit: Int?) -> some View {
        if !isSnoozeLimitSelectable(snoozeLimit: snoozeLimit, isPremium: PremiumEntitlement.isPremium) {
            Label {
                snoozeLimitText(snoozeLimit: snoozeLimit)
            } icon: {
                Image(systemName: "lock")
            }
        } else if snoozeLimit == nil {
            Label {
                snoozeLimitText(snoozeLimit: snoozeLimit)
            } icon: {
                Image(systemName: "infinity")
            }
        } else {
            snoozeLimitText(snoozeLimit: snoozeLimit)
        }
    }

    /// 夜リマインドの通知時刻の表示用 Date (端末のロケールで時刻表記するために Date へ変換する)
    private var nightReminderTime: Date {
        Calendar.autoupdatingCurrent.date(
            bySettingHour: NightReminder.hour,
            minute: NightReminder.minute,
            second: 0,
            of: .now
        ) ?? .now
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
            // Picker には課金状態での実効値を表示しているため、ユーザーが変更していない時は保存済みの希望値を上書きしない
            // (プレミアム失効中に時刻だけ保存しても、以前選んだ回数が無料枠に書き換わらず、再購読後に戻る。PR #78 レビュー指摘)
            if snoozeLimit != effectiveSnoozeLimit(snoozeLimit: alarmSetting.snoozeLimit, isPremium: PremiumEntitlement.isPremium) {
                alarmSetting.setSnoozeLimit(snoozeLimit: snoozeLimit)
            }
        } else {
            modelContext.insert(AlarmSetting(hour: hour, minute: minute, isEnabled: isEnabled, snoozeLimit: snoozeLimit))
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
        let _ = {
            // Preview の body は複数回評価されるため、共有 in-memory コンテナへの重複挿入を防いで冪等にする
            guard (try? modelContext.fetchCount(FetchDescriptor<AlarmSetting>())) == 0 else { return }
            modelContext.insert(AlarmSetting(hour: 7, minute: 0))
            try! modelContext.save()
        }()

        NavigationStack {
            AlarmSettingPage()
        }
        .modelContainer(container)
    }
}
