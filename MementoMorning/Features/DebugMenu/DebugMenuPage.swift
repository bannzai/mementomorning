#if DEBUG
import SwiftUI
import SwiftData
import UserNotifications

/// 検証用の開発者メニュー。動作確認はリモート simulator (simtunnel) で行い起動引数を渡せないため、検証用の状態作りはこの画面から行う
struct DebugMenuPage: View {
    /// 検証用の夜リマインドの識別子。本番の夜リマインド (night-reminder) と分けて、互いのスケジュールを壊さないようにする
    private static let testRequestIdentifier = "night-reminder-debug"
    /// 検証用の夜リマインドが発火するまでの秒数。アラーム発火の確認は「1〜2 分後」に登録して画面表示で判定する運用に合わせる
    private static let testTimeInterval: TimeInterval = 60

    @Environment(\.modelContext) private var modelContext

    @State private var answer: MorningAnswer?

    var body: some View {
        List {
            Section {
                Text(verbatim: "Today's answer: \(answerStateText)")
                    .accessibilityIdentifier("debug_today_answer_state")
            }

            Section {
                Button {
                    seedTodayAnswer()
                } label: {
                    Text(verbatim: "Seed today's answer")
                }
                .accessibilityIdentifier("debug_seed_today_answer")

                Button {
                    Task {
                        await scheduleNightReminderForTest()
                        answer = todayAnswer()
                    }
                } label: {
                    Text(verbatim: "Schedule night reminder in 1 minute")
                }
                .accessibilityIdentifier("debug_schedule_night_reminder_test")
            }
        }
        .navigationTitle(Text(verbatim: "Developer Menu"))
        .onAppear {
            answer = todayAnswer()
        }
    }

    /// 今日の回答の有無と夜の振り返りの記録状態を表す表示用の文字列
    private var answerStateText: String {
        guard let answer else {
            return "none"
        }
        return "\(answer.text) (isFulfilled: \(answer.isFulfilled?.description ?? "nil"))"
    }

    /// 今日 (0 時基準) の回答を取得する。1 日 1 件のため 1 件だけ取得する
    private func todayAnswer() -> MorningAnswer? {
        let today = Calendar.current.startOfDay(for: .now)
        var descriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == today })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// 検証用に今日の回答を作る。既に今日の回答があれば何もしない
    private func seedTodayAnswer() {
        guard todayAnswer() == nil else {
            return
        }
        modelContext.insert(
            MorningAnswer(answeredDate: Calendar.current.startOfDay(for: .now), text: "家族と海を見に行く")
        )
        try? modelContext.save()
        answer = todayAnswer()
    }

    /// 検証用の夜リマインドを 1 分後に登録する。同じ識別子の保留中通知を削除してから登録するため、何度押しても保留は 1 本に保たれる
    private func scheduleNightReminderForTest() async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [Self.testRequestIdentifier])
            try await center.add(
                UNNotificationRequest(
                    identifier: Self.testRequestIdentifier,
                    content: NightReminder.makeContent(),
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: Self.testTimeInterval, repeats: false)
                )
            )
        } catch {
            print("[DebugMenuPage] failed to schedule test night reminder: \(error)")
        }
    }
}

struct DebugMenuPage_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DebugMenuPage()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
#endif
