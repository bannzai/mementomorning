import XCTest
@testable import MementoMorning

/// アラーム音の選択肢 (AlarmSound) と soundName の解決・永続化のテスト (issue #133)
final class AlarmSoundTests: XCTestCase {
    /// 未設定 (nil。既存レコードの軽量マイグレーション値) と未知の値はシステム標準音へ解決する
    func testResolveFallsBackToSystemDefault() {
        XCTAssertEqual(resolveAlarmSound(soundName: nil), .systemDefault)
        XCTAssertEqual(resolveAlarmSound(soundName: "unknownSoundName"), .systemDefault)
    }

    /// 保存された rawValue から元の選択肢へ解決できる (永続化のラウンドトリップ)
    func testResolveRoundTripsAllCases() {
        for sound in AlarmSound.allCases {
            XCTAssertEqual(resolveAlarmSound(soundName: sound.rawValue), sound)
        }
    }

    /// 音源ファイルを持つ選択肢のファイル (拡張子込みの soundFileName) がアプリバンドルに存在する。
    /// AlertSound.named は拡張子込みの実ファイル名で解決するため、ファイルの欠落・名前のずれは
    /// 「選んだのに鳴らない」事故になる (テストはホストアプリ上で動くため Bundle.main = アプリバンドル)
    func testBundledSoundFilesExist() {
        for sound in AlarmSound.allCases {
            guard let soundFileName = sound.soundFileName else { continue }
            XCTAssertNotNil(
                Bundle.main.url(forResource: soundFileName, withExtension: nil),
                "missing sound file: \(soundFileName) for \(sound)"
            )
        }
    }

    /// システム標準音だけが音源ファイルを持たない (AlertSound.default で鳴らすため)
    func testOnlySystemDefaultHasNoSoundFile() {
        for sound in AlarmSound.allCases {
            if sound == .systemDefault {
                XCTAssertNil(sound.soundFileName)
            } else {
                XCTAssertNotNil(sound.soundFileName)
            }
        }
    }

    /// setSoundName で soundName が更新され、updatedDateTime も進む (coding-rules-entity.md のドメインメソッド規約)
    func testSetSoundNameUpdatesEntity() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        XCTAssertNil(alarmSetting.soundName)
        let beforeUpdatedDateTime = alarmSetting.updatedDateTime
        alarmSetting.setSoundName(soundName: AlarmSound.gentleChime.rawValue)
        XCTAssertEqual(alarmSetting.soundName, AlarmSound.gentleChime.rawValue)
        XCTAssertGreaterThanOrEqual(alarmSetting.updatedDateTime, beforeUpdatedDateTime)
    }
}
