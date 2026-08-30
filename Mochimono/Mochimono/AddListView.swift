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

    var body: some View {
        List {
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

            Section {
                Button {
                    startBlank()
                } label: {
                    Label("白紙から作る", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier("startBlank")
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
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.primary)
                Text(preset.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text("\(preset.items.count)個")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            // 中身がひと目で分かるように、実際の色でそのまま並べる。
            HStack(spacing: 2) {
                ForEach(preset.items.prefix(9)) { item in
                    Text(item.text)
                        .font(.system(size: 9, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .foregroundStyle(table.tone(group: item.group, isPacked: false).label.color)
                        .background(table.tone(group: item.group, isPacked: false).fill.color,
                                    in: .rect(cornerRadius: 3))
                }
                if preset.items.count > 9 {
                    Text("…").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }
}
