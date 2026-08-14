import SwiftUI

/// デザイン handoff (design_handoff_memento_morning/README.md) のデザイントークン。
/// ダークモード前提の唯一のテーマ。影・カード・角丸コンテナは使わず、区切りはヘアラインのみ。
/// アクセント (夜明け) は各画面 1 箇所までに抑える
extension Color {
    /// 背景 (墨)。#0B0C0E
    static let ink = Color(red: 0x0B / 255, green: 0x0C / 255, blue: 0x0E / 255)
    /// 前景 (温白)。#E9E7E2。二次テキストは opacity 0.55 / 三次 0.40 / 微弱 0.30–0.35 で使う
    static let warmWhite = Color(red: 0xE9 / 255, green: 0xE7 / 255, blue: 0xE2 / 255)
    /// アクセント (夜明けの微光)。#C2A183
    static let dawn = Color(red: 0xC2 / 255, green: 0xA1 / 255, blue: 0x83 / 255)
    /// ヘアライン (区切り線)。rgba(233,231,226,0.08)
    static let hairline = Color.warmWhite.opacity(0.08)
}

/// ヘアラインの区切り線 1 本。List を使わないレイアウトでの行区切りに使う
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
    }
}

/// primary ボタン (温白地に墨文字の pill)。1 画面に 1 つの主動作に使う
struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .regular))
            // letter-spacing 0.1em (15pt 基準)
            .tracking(1.5)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color.warmWhite, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// secondary ボタン (ヘアライン枠のみの pill)
struct SecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .regular))
            // letter-spacing 0.1em (15pt 基準)
            .tracking(1.5)
            .foregroundStyle(Color.warmWhite.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay(Capsule().stroke(Color.warmWhite.opacity(0.25), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
