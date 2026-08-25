import AVFoundation
import SwiftUI
import SwiftData

/// 毎朝のアラーム設定画面。設定できるのは時刻・ON/OFF・スヌーズ回数だけ (設定要素は最小限)。
/// 保存ボタンは置かず、値が変わったらすぐに保存する (issue #124)
struct AlarmSettingPage: View {
    /// モデルコンテキスト
    @Environment(\.modelContext) private var modelContext
    /// アプリの scenePhase。バックグラウンド遷移でデバウンス待ちの保存を確定するために監視する
    @Environment(\.scenePhase) private var scenePhase
    /// 保存済みのアラーム設定。単一レコード運用のため先頭 1 件のみ使う
    @Query private var alarmSettings: [AlarmSetting]
    /// 保存済みの夜リマインド設定。画面上の並び順は登録順で、先頭が無料枠で有効になる 1 本目
    @Query(sort: \NightReminderSetting.createdDateTime) private var nightReminderSettings: [NightReminderSetting]
    /// DatePicker 入力用。保存時に hour/minute へ分解する
    @State private var time: Date = .now
    /// アラームの有効フラグ
    @State private var isEnabled: Bool = true
    /// スヌーズ (追撃アラーム) の上限回数の選択値。nil は無制限。
    /// 初期値は無料枠 freeTierSnoozeLimit で、保存済み設定があれば onAppear で effectiveSnoozeLimit に置き換える
    @State private var snoozeLimit: Int? = freeTierSnoozeLimit
    /// スヌーズ (追撃) の間隔の分数。初期値は既定の 2 分で、保存済み設定があれば onAppear で実効値に置き換える
    @State private var snoozeIntervalMinutes: Int = defaultSnoozeIntervalMinutes
    /// アラーム音の選択値。初期値はシステム標準音で、保存済み設定があれば onAppear で置き換える (issue #133)
    @State private var alarmSound: AlarmSound = .systemDefault
    /// アラーム音の試聴用プレイヤー。再生中に解放されないよう保持する
    @State private var soundPreviewPlayer: AVAudioPlayer?
    /// 夜リマインドの時刻の DatePicker 入力用。保存時に hour/minute へ分解する。
    /// 初期値は空で、onAppear で保存済み設定の実効値 (未設定なら既定の 21:00 の 1 本) に置き換える
    @State private var nightReminderTimes: [Date] = []
    /// 保存に失敗した場合のエラー。nil 以外でアラート表示する
    @State private var saveError: String?
    /// 直近の再スケジュールで発生したエラー。Rescheduler が書き込み、成功時に削除される
    @AppStorage(.lastRescheduleError) private var lastRescheduleError: String?
    /// 自動保存のデバウンス用 Task。値が変わるたびに置き換え、連続変更を 1 回の保存にまとめる
    @State private var autoSaveTask: Task<Void, Never>?
    /// ペイウォールを表示中かどうか。無料状態でプレミアム限定のスヌーズ回数 (無料枠超・無制限) を選んだ時に開く
    @State private var isPaywallPresented = false

    /// RevenueCat の entitlement キャッシュ。値の変化で再描画を起こすために監視する (判定は PremiumEntitlement.isPremium が SSOT)
    @AppStorage(.premiumEntitlementActive) private var premiumEntitlementActive = false
    /// 検証用のプレミアム強制フラグ。値の変化で再描画を起こすために監視する
    @AppStorage(.debugPremiumOverride) private var debugPremiumOverride = false
    /// 開発者メニューを表示中かどうか。バージョン行の長押し (issue #128) で開く
    @State private var isDebugMenuPresented = false

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
                guard isSnoozeLimitSelectable(snoozeLimit: newValue, isPremium: PremiumEntitlement.isPremium) else {
                    // 無料で選べない回数は選択を戻し、代わりにペイウォールを開く (戻した値は選択可能なため再帰しない)
                    snoozeLimit = oldValue
                    isPaywallPresented = true
                    return
                }
                // 選べない回数からの巻き戻し (oldValue が選択不可) は変更ではないため保存しない
                // (保存すると、アラーム未設定のままペイウォール導線に触れただけでレコードが作られてしまう)
                guard isSnoozeLimitSelectable(snoozeLimit: oldValue, isPremium: PremiumEntitlement.isPremium) else { return }
                scheduleAutoSave()
            }
            // スヌーズの間隔 (追撃アラームの再登録間隔)。回数と違い課金線は無く全員が選べる (issue #135 の実機テスト指摘)
            Picker(selection: $snoozeIntervalMinutes) {
                ForEach(Array(snoozeIntervalChoices), id: \.self) { minutes in
                    // ja: %lld分
                    Text("\(minutes) min")
                        .tag(minutes)
                }
            } label: {
                // ja: スヌーズ間隔
                Text("Snooze interval")
            }
            .accessibilityIdentifier("alarm_setting_snooze_interval_picker")
            .onChange(of: snoozeIntervalMinutes) { _, _ in
                scheduleAutoSave()
            }
            // アラーム音の選択 (issue #133)。選択肢はシステム標準音 + 同梱音源 + 無音 (AlarmSound 参照)
            Picker(selection: $alarmSound) {
                ForEach(AlarmSound.allCases, id: \.self) { sound in
                    alarmSoundText(alarmSound: sound)
                        .tag(sound)
                }
            } label: {
                // ja: サウンド
                Text("Sound")
            }
            .accessibilityIdentifier("alarm_setting_sound_picker")
            .onChange(of: alarmSound) { _, newValue in
                // 新しい音を鳴らすかどうかに関わらず、先に進行中の試聴を止める
                // (無音・標準音へ切り替えたのに直前の音が鳴り続けないように。PR #134 レビュー指摘)
                stopSoundPreview()
                // 保存済みの値への復元 (onAppear・課金状態の変化) では試聴しない。
                // 復元は必ず保存済みの値と一致するため、一致しない変更 = ユーザーの実操作だけ試聴する
                if newValue != resolveAlarmSound(soundName: alarmSettings.first?.soundName) {
                    playSoundPreview(alarmSound: newValue)
                }
                scheduleAutoSave()
            }
            // 夜リマインドの時刻 (issue #44 の可視化から issue #94 で編集可能にした)。
            // 1 本目の時刻変更は無料、2・3 本目の追加はプレミアム限定で、追加を試すとペイウォールへ誘導する (課金設計は documents/PROJECT.md)
            Section {
                ForEach(nightReminderTimes.indices, id: \.self) { index in
                    HStack {
                        // ja: リマインド %lld
                        DatePicker(
                            String(localized: "Reminder \(index + 1)"),
                            selection: $nightReminderTimes[index],
                            displayedComponents: .hourAndMinute
                        )
                        // 1 本目は常に残す (夜リマインドを 0 本にはできない)
                        if index > 0 {
                            Button(role: .destructive) {
                                nightReminderTimes.remove(at: index)
                            } label: {
                                // ja: リマインドを削除
                                Label(String(localized: "Delete reminder"), systemImage: "minus.circle")
                                    .labelStyle(.iconOnly)
                            }
                            // Form の行に置いたボタンは、既定では行全体のタップで反応してしまうためボタン自身の領域だけに限定する
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("alarm_setting_night_reminder_delete_button_\(index)")
                        }
                    }
                    .accessibilityIdentifier("alarm_setting_night_reminder_row_\(index)")
                }
                if nightReminderTimes.count < maxNightReminderCount {
                    Button {
                        guard isNightReminderSelectable(index: nightReminderTimes.count, isPremium: PremiumEntitlement.isPremium) else {
                            // 無料で追加できない本数はペイウォールへ誘導する (スヌーズ回数の選択肢と同じ導線)
                            isPaywallPresented = true
                            return
                        }
                        nightReminderTimes.append(addedNightReminderTime)
                    } label: {
                        Label {
                            // ja: リマインドを追加
                            Text("Add reminder")
                        } icon: {
                            // 現在の課金状態で追加できない本数には錠前を付け、プレミアム限定であることを押す前に示す
                            Image(systemName: isNightReminderSelectable(index: nightReminderTimes.count, isPremium: PremiumEntitlement.isPremium) ? "plus" : "lock")
                        }
                    }
                    .accessibilityIdentifier("alarm_setting_night_reminder_add_button")
                }
            } header: {
                // ja: 夜のリマインド
                Text("Night reminder")
            } footer: {
                // ja: 今朝の回答と答え合わせしましょう
                Text("Check tonight against this morning's answer.")
            }
            // ペイウォールへの恒常導線 (issue #104)。ロック要素を経由しなくても有料機能のページへ到達できるようにする。
            // 購読中はアップセルを出さず、購読状態の表示に切り替える
            Section {
                if PremiumEntitlement.isPremium {
                    LabeledContent {
                        // ja: 有効
                        Text("Active")
                    } label: {
                        // ja: プレミアム
                        Text("Premium")
                    }
                    .accessibilityIdentifier("alarm_setting_premium_status_row")
                } else {
                    Button {
                        isPaywallPresented = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            // ja: プレミアム
                            Text("Premium")
                            // ja: 無限追撃アラームと、すべての履歴
                            Text("Endless follow-up alarms and all your mornings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("alarm_setting_premium_link")
                }
            }
            // 利用規約・プライバシーポリシー・特商法表記・問い合わせへの導線とバージョン表示 (issue #83)。
            // 課金アプリは審査で特商法表記の到達性を見られるため、設定画面から必ず辿れるようにする
            Section {
                // ja: 利用規約
                Link(String(localized: "Terms of Use"), destination: LegalLinks.terms)
                    .accessibilityIdentifier("alarm_setting_terms_link")
                // ja: プライバシーポリシー
                Link(String(localized: "Privacy Policy"), destination: LegalLinks.privacyPolicy)
                    .accessibilityIdentifier("alarm_setting_privacy_policy_link")
                // ja: 特定商取引法に基づく表記
                Link(String(localized: "Legal Notice (Specified Commercial Transaction Act)"), destination: LegalLinks.specifiedCommercialTransactionAct)
                    .accessibilityIdentifier("alarm_setting_specified_commercial_transaction_act_link")
                // ja: 問い合わせ
                Link(String(localized: "Contact"), destination: LegalLinks.contact)
                    .accessibilityIdentifier("alarm_setting_contact_link")
                LabeledContent {
                    Text(verbatim: appVersionText())
                } label: {
                    // ja: バージョン
                    Text("Version")
                }
                .accessibilityIdentifier("alarm_setting_version_row")
                // 開発者メニューへの隠し導線 (issue #128)。TestFlight 配布 (リリースビルド) でも検証状態を
                // 作れるようバージョン行の長押しで開く。App Store 配布では isDeveloperMenuUnlocked が
                // false のままのため反応しない
                .contentShape(Rectangle())
                .onLongPressGesture {
                    guard isDeveloperMenuUnlocked else { return }
                    isDebugMenuPresented = true
                }
                // stopIntent スパイクログの表示先。設定画面へ直接出さず一段奥に隠し、問い合わせ時にコピーして添えられるようにする (issue #103)
                NavigationLink {
                    DeveloperLogPage()
                } label: {
                    // ja: 開発者用のログ
                    Text("Developer Log")
                }
                .accessibilityIdentifier("alarm_setting_developer_log_link")
            } header: {
                // ja: 情報
                Text("About")
            }
            if let lastRescheduleError, !lastRescheduleError.isEmpty {
                // エラーメッセージはそのまま表示する (加工しない)
                Text(lastRescheduleError)
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallPage()
        }
        // バージョン行の長押し (issue #128) から開発者メニューを開く
        .navigationDestination(isPresented: $isDebugMenuPresented) {
            DebugMenuPage()
        }
        // ja: アラーム
        .navigationTitle(String(localized: "Alarm"))
        // 保存ボタンは置かず、値が変わったらすぐに保存する (issue #124)。
        // スヌーズ回数はペイウォール判定と合わせて Picker 側の onChange で保存する
        .onChange(of: time) {
            scheduleAutoSave()
        }
        .onChange(of: isEnabled) {
            scheduleAutoSave()
        }
        .onChange(of: nightReminderTimes) { oldValue, _ in
            // onAppear の復元 (空 → 保存済みの実効値) は変更ではないため保存しない。
            // 画面上は 1 本目を消せないため、ユーザー操作で空から変わることはない
            guard !oldValue.isEmpty else { return }
            scheduleAutoSave()
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
            restoreFromStored()
        }
        // 課金状態が変わったら入力を新しい実効値へ復元する (理由は restoreFromStored の doc コメント)
        .onChange(of: premiumEntitlementActive) {
            restoreFromStored()
        }
        .onChange(of: debugPremiumOverride) {
            restoreFromStored()
        }
        .onDisappear {
            stopSoundPreview()
            flushAutoSave()
        }
        // バックグラウンド遷移・ロックでは onDisappear が呼ばれず、デバウンス中の Task は実行保証が無いため、
        // 非 active 遷移でも待たずに保存を確定する
        .onChange(of: scenePhase) { _, newValue in
            guard newValue != .active else { return }
            flushAutoSave()
        }
    }

    /// 保存済みの設定を現在の課金状態での実効値として入力へ復元する。
    /// onAppear と課金状態の変化時に呼ぶ (購入・復元の直後に無料向けの実効値が入力に残っていると、
    /// その後の保存が差分と誤認し、保存済みの希望値や 2 本目以降のリマインドを消してしまう)
    private func restoreFromStored() {
        // スヌーズ回数と同じく、表示するのは現在の課金状態での実効値 (無料なら 1 本目だけ)。
        // 保存済みが 0 件の時は既定の 21:00 の 1 本になる
        nightReminderTimes = effectiveNightReminderTimes(
            times: nightReminderSettings.map { DateComponents(hour: $0.hour, minute: $0.minute) },
            isPremium: PremiumEntitlement.isPremium
        ).map { nightReminderDate(time: $0) }
        guard let alarmSetting = alarmSettings.first else { return }
        var components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: .now)
        components.hour = alarmSetting.hour
        components.minute = alarmSetting.minute
        if let date = Calendar.autoupdatingCurrent.date(from: components) {
            time = date
        }
        isEnabled = alarmSetting.isEnabled
        snoozeLimit = effectiveSnoozeLimit(snoozeLimit: alarmSetting.snoozeLimit, isPremium: PremiumEntitlement.isPremium)
        alarmSound = resolveAlarmSound(soundName: alarmSetting.soundName)
        snoozeIntervalMinutes = effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: alarmSetting.snoozeIntervalMinutes)
    }

    /// デバウンス待ちの自動保存があれば、待たずにその場で確定する。
    /// ユーザーの編集で自動保存が予約された時 (autoSaveTask != nil) だけ保存する
    /// (編集なしの離脱でも保存すると、アラーム未設定のまま画面を開いて閉じただけでレコードが作られてしまう)
    private func flushAutoSave() {
        guard let previousTask = autoSaveTask else { return }
        previousTask.cancel()
        autoSaveTask = Task {
            // 実行中の保存があれば完了を待ち、保存処理を交錯させない
            await previousTask.value
            await save()
        }
    }

    /// アラーム音の選択肢の文言
    private func alarmSoundText(alarmSound: AlarmSound) -> Text {
        switch alarmSound {
        case .systemDefault:
            // ja: デフォルト
            return Text("Default")
        case .gentleChime:
            // ja: やわらかなチャイム
            return Text("Gentle Chime")
        case .morningBell:
            // ja: 朝の鐘
            return Text("Morning Bell")
        case .softPulse:
            // ja: しずかなパルス
            return Text("Soft Pulse")
        case .silent:
            // ja: 無音
            return Text("Silent")
        }
    }

    /// 選んだアラーム音を試聴する。
    /// システム標準音はバンドル内にファイルが無く、無音は聴くものが無いため何もしない。
    /// アラーム音の選択はサイレントスイッチ ON でも聴けるべきなため、セッションを .playback にして再生する (PR #134 レビュー指摘)
    private func playSoundPreview(alarmSound: AlarmSound) {
        guard alarmSound != .silent,
              let soundFileName = alarmSound.soundFileName,
              // soundFileName は拡張子込みのため withExtension は nil で解決する
              let url = Bundle.main.url(forResource: soundFileName, withExtension: nil) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        soundPreviewPlayer = try? AVAudioPlayer(contentsOf: url)
        soundPreviewPlayer?.play()
    }

    /// 進行中の試聴を止め、オーディオセッションを明け渡す (他アプリの再生を再開させる)。
    /// 選択の切り替え時と画面を離れる時に呼ぶ
    private func stopSoundPreview() {
        guard soundPreviewPlayer != nil else { return }
        soundPreviewPlayer?.stop()
        soundPreviewPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

    /// 夜リマインドの通知時刻を DatePicker が扱う Date へ変換する (時・分だけを today の日付に載せる)
    private func nightReminderDate(time: DateComponents) -> Date {
        Calendar.autoupdatingCurrent.date(
            bySettingHour: time.hour ?? defaultNightReminderHour,
            minute: time.minute ?? defaultNightReminderMinute,
            second: 0,
            of: .now
        ) ?? .now
    }

    /// DatePicker の Date から夜リマインドの通知時刻 (時・分) を取り出す
    private func nightReminderTime(date: Date) -> DateComponents {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return DateComponents(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    /// 「リマインドを追加」で足す時刻。
    /// 最後のリマインドの 1 時間後にするのは、同じ時刻を重複登録すると識別子が衝突して通知が 1 本に潰れるため
    private var addedNightReminderTime: Date {
        guard let lastTime = nightReminderTimes.last else {
            return nightReminderDate(time: DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute))
        }
        return Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: lastTime) ?? lastTime
    }

    /// 値の変更をデバウンスして保存する。
    /// DatePicker のホイール操作は 1 回の操作で onChange が連続発火するため、
    /// 最後の変更から一呼吸待って 1 回の保存 (と再スケジュール) にまとめる。
    /// 500ms は、ホイールを回している間は発火せず、手を止めてから保存までの遅れも体感されにくい値として選んだ
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        let previousTask = autoSaveTask
        autoSaveTask = Task {
            // 先行の保存が実行中なら完了を待ってから直列に実行する
            // (AlarmKit の reschedule は内部で直列化されているが rescheduleNightReminder はされていないため、
            // 保存処理全体を交錯させない)
            await previousTask?.value
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    /// 入力内容を保存して再スケジュールする。
    /// onAppear の復元 (@State への代入) でも onChange は発火するため、
    /// 保存済みの値からの実変更が無い時は何もしない (冪等)
    private func save() async {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        // 再スケジュールの失敗が残っている時は、実変更が無くても保存し直して再試行する
        // (保存ボタンが無いため、ここで再試行しないと同じ設定のまま再スケジュールし直す操作が無い)
        guard hasAlarmSettingChanges(
            hour: hour,
            minute: minute,
            isEnabled: isEnabled,
            snoozeLimit: snoozeLimit,
            snoozeIntervalMinutes: snoozeIntervalMinutes,
            alarmSound: alarmSound,
            nightReminderTimes: nightReminderTimes.map { nightReminderTime(date: $0) },
            alarmSetting: alarmSettings.first,
            storedNightReminderTimes: nightReminderSettings.map { DateComponents(hour: $0.hour, minute: $0.minute) },
            isPremium: PremiumEntitlement.isPremium
        ) || UserDefaults.standard.string(forKey: .lastRescheduleError) != nil else { return }
        if let alarmSetting = alarmSettings.first {
            alarmSetting.setTime(hour: hour, minute: minute)
            alarmSetting.setIsEnabled(isEnabled: isEnabled)
            // Picker には課金状態での実効値を表示しているため、ユーザーが変更していない時は保存済みの希望値を上書きしない
            // (プレミアム失効中に時刻だけ保存しても、以前選んだ回数が無料枠に書き換わらず、再購読後に戻る。PR #78 レビュー指摘)
            if snoozeLimit != effectiveSnoozeLimit(snoozeLimit: alarmSetting.snoozeLimit, isPremium: PremiumEntitlement.isPremium) {
                alarmSetting.setSnoozeLimit(snoozeLimit: snoozeLimit)
            }
            if alarmSound != resolveAlarmSound(soundName: alarmSetting.soundName) {
                alarmSetting.setSoundName(soundName: alarmSound.rawValue)
            }
            if snoozeIntervalMinutes != effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: alarmSetting.snoozeIntervalMinutes) {
                alarmSetting.setSnoozeIntervalMinutes(snoozeIntervalMinutes: snoozeIntervalMinutes)
            }
        } else {
            modelContext.insert(AlarmSetting(hour: hour, minute: minute, isEnabled: isEnabled, snoozeLimit: snoozeLimit, soundName: alarmSound.rawValue, snoozeIntervalMinutes: snoozeIntervalMinutes))
        }
        saveNightReminderSettings()
        do {
            try modelContext.save()
        } catch {
            // 永続化されていない変更を mainContext に残すと、次回の foreground 復帰で
            // reschedule がその未保存の値を fetch してしまうため、変更を破棄してから中断する
            modelContext.rollback()
            saveError = "\(error)"
            return
        }
        await reschedule(modelContext: modelContext)
        // 夜リマインドは scenePhase の変化 (バックグラウンド遷移・foreground 復帰) でしか登録し直されないため、
        // この画面で変更した時刻がその場で反映されるようここでも登録し直す
        await rescheduleNightReminder(modelContext: modelContext)
        // 再スケジュールの完了を待って、失敗をこの画面のアラートで可視化する
        if let error = UserDefaults.standard.string(forKey: .lastRescheduleError) {
            saveError = error
        }
    }

    /// 画面上の夜リマインドの時刻を保存済み設定へ反映する (登録順に更新し、増えた分は追加、減った分は削除する)。
    /// 呼び出し側 (save) がまとめて modelContext.save() するため、この関数自身は保存しない
    private func saveNightReminderSettings() {
        let isPremium = PremiumEntitlement.isPremium
        let times = nightReminderTimes.map { nightReminderTime(date: $0) }
        // 画面には課金状態での実効値を表示しているため、ユーザーが変更していない時は保存済みの設定を上書きしない
        // (プレミアム失効中に 1 本目の時刻だけ変えても、以前追加した 2・3 本目が消えず、再購読後に戻る。PR #78 レビュー指摘)
        guard times != effectiveNightReminderTimes(
            times: nightReminderSettings.map { DateComponents(hour: $0.hour, minute: $0.minute) },
            isPremium: isPremium
        ) else {
            return
        }
        for (index, time) in times.enumerated() {
            if index < nightReminderSettings.count {
                nightReminderSettings[index].setTime(hour: time.hour ?? 0, minute: time.minute ?? 0)
            } else {
                modelContext.insert(NightReminderSetting(hour: time.hour ?? 0, minute: time.minute ?? 0))
            }
        }
        // 削除の対象は画面に表示していた分だけにする。無料で隠れている 2・3 本目 (プレミアム失効中に残った設定) は、
        // ユーザーが消したわけではないため残す
        let shownCount = min(nightReminderSettings.count, isPremium ? maxNightReminderCount : freeTierNightReminderCount)
        for setting in nightReminderSettings[min(times.count, shownCount)..<shownCount] {
            modelContext.delete(setting)
        }
    }
}

/// 設定画面の入力値が保存済みの値から実際に変わったかを判定する。
/// 自動保存 (issue #124) は onAppear の復元 (@State への代入) が起こす onChange でも呼ばれるため、
/// 実変更の無い保存・再スケジュールをこの判定で抑止する。
/// 比較は課金状態での実効値に対して行う (画面には実効値を表示しているため、プレミアム失効中に隠れている
/// スヌーズの希望値・2 本目以降のリマインドは変更として扱わない)。
/// 保存済みが無い (alarmSetting が nil) 時は常に変更ありとする (onAppear はアラーム系の @State を復元しないため、
/// onChange の発火 = ユーザーの実操作になる)。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func hasAlarmSettingChanges(
    hour: Int,
    minute: Int,
    isEnabled: Bool,
    snoozeLimit: Int?,
    snoozeIntervalMinutes: Int,
    alarmSound: AlarmSound,
    nightReminderTimes: [DateComponents],
    alarmSetting: AlarmSetting?,
    storedNightReminderTimes: [DateComponents],
    isPremium: Bool
) -> Bool {
    guard let alarmSetting else { return true }
    return hour != alarmSetting.hour
        || minute != alarmSetting.minute
        || isEnabled != alarmSetting.isEnabled
        || snoozeLimit != effectiveSnoozeLimit(snoozeLimit: alarmSetting.snoozeLimit, isPremium: isPremium)
        || snoozeIntervalMinutes != effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: alarmSetting.snoozeIntervalMinutes)
        || alarmSound != resolveAlarmSound(soundName: alarmSetting.soundName)
        || nightReminderTimes != effectiveNightReminderTimes(times: storedNightReminderTimes, isPremium: isPremium)
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
