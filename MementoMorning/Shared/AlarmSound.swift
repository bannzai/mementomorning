import Foundation

/// アラーム音の選択肢 (issue #133)。
/// rawValue が AlarmSetting.soundName として永続化される。
/// 同梱音源は scripts/generate_alarm_sounds.py で合成したオリジナル音源 (ライセンス問題なし)。
/// iOS のシステム音 (着信音・アラーム音のライブラリ) を選ぶ API は AlarmKit / ActivityKit に存在しない
/// (AlertSound は .default と .named(バンドル内ファイル) のみ) ため、選択肢はデフォルト + 同梱音源で構成する
enum AlarmSound: String, CaseIterable {
    /// システム標準のアラーム音
    case systemDefault
    /// やわらかなチャイム (A5 のチューブラーベル)
    case gentleChime
    /// 朝の鐘 (C5 の深いベル)
    case morningBell
    /// しずかなパルス (E5 の 2 連パルス)
    case softPulse
    /// 無音。音を鳴らしたくないユーザー向け (AlarmKit に音を消す・バイブレーションだけ鳴らす API が無いため、
    /// 無音の音源ファイルを鳴らすことで代替する)
    case silent

    /// バンドル内の音源ファイル名 (拡張子込み)。システム標準音の systemDefault はファイルを持たないため nil。
    /// AlertSound.named は拡張子込みの実ファイル名で解決するため拡張子を含める (PR #134 レビュー指摘。
    /// 実例: https://developer.apple.com/forums/thread/788836 の .named("Glass Drum.caf"))
    var soundFileName: String? {
        switch self {
        case .systemDefault:
            return nil
        case .gentleChime:
            return "AlarmSoundGentleChime.caf"
        case .morningBell:
            return "AlarmSoundMorningBell.caf"
        case .softPulse:
            return "AlarmSoundSoftPulse.caf"
        case .silent:
            return "AlarmSoundSilent.caf"
        }
    }
}

/// 永続化された soundName からアラーム音を解決する。
/// 未設定 (nil。既存レコードへの軽量マイグレーション値を含む) と未知の値 (将来の選択肢の削除等) は
/// これまでの挙動と同じシステム標準音へ倒す。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func resolveAlarmSound(soundName: String?) -> AlarmSound {
    soundName.flatMap(AlarmSound.init(rawValue:)) ?? .systemDefault
}
