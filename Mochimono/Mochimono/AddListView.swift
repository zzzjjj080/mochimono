import SwiftUI
import MochimonoCore

/// リストを追加する画面。
///
/// 白紙から書き始めるのは難しいので、**雛形を選ぶのを既定の道**にする。
/// 選んだあとはただのリストなので、要らない行を消せばよい。
struct AddListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let pickPreset: (Preset) -> Void
    let startBlank: () -> Void
    let paste: (String) -> Void

    var body: some View {
        List {
            // **書いたテキストを、そのまま盤面にできること**がこの道具の芯。
            // 雛形より先に置いて、最初に目に入るようにする。
            Section {
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    paste(text)
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("pasteFromClipboard")
                Button {
                    startBlank()
                } label: {
                    Label("白紙から書く", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier("startBlank")
            } header: {
                Text("テキストから作る")
            } footer: {
                Text("1行に1つ、空行でグループが分かれます。ほかのアプリで書いた箇条書きを貼っても、そのまま盤面になります。")
            }

            Section {
                ForEach(Preset.all) { preset in
                    Button { pickPreset(preset) } label: { row(preset) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("preset-\(preset.id)")
                }
            } header: {
                Text("雛形から作る")
            } footer: {
                Text("選ぶとコピーが作られます。要らない行を消して、自分用に書き換えてください。")
            }

        }
        .navigationTitle("リストを追加")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ preset: Preset) -> some View {
        let table = ToneTable(palette: preset.palette,
                              groups: preset.groups,
                              scheme: colorScheme.scheme)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(preset.name)
                    .font(.system(.subheadline, weight: .heavy))
                    .foregroundStyle(Color.primary)
                Text(preset.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text("\(preset.items.count)個")
                    .font(.system(.caption, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            // 中身がひと目で分かるように、実際の色でそのまま並べる。
            HStack(spacing: 2) {
                ForEach(preset.items.prefix(9)) { item in
                    Text(item.text)
                        .font(.system(.caption2, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .foregroundStyle(table.tone(group: item.group, isPacked: false).label.color)
                        .background(table.tone(group: item.group, isPacked: false).fill.color,
                                    in: .rect(cornerRadius: 3))
                }
                if preset.items.count > 9 {
                    Text("…").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }
}
