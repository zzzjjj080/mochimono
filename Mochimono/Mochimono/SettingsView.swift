import SwiftUI
import MochimonoCore

/// 見た目の設定。中身（編集）とは分ける。
/// 色を触るつもりで持ち物を書き換えてしまう事故を防ぐ。
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let listID: PackingList.ID
    let onDeleted: () -> Void

    @State private var askingReset = false
    @State private var askingDelete = false
    @State private var tipJar = TipJar(productID: TipJar.productID)

    private var list: PackingList? { model.list(listID) }

    var body: some View {
        Form {
            if let list {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Palette.allCases) { palette in
                            paletteCard(palette, selected: list.palette == palette)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("配色（このリストだけ）")
                }

                Section("列数（このリストだけ）") {
                    Picker("列数", selection: Binding(
                        get: { list.columns },
                        set: { model.setColumns($0, for: listID) })
                    ) {
                        ForEach(Columns.allCases, id: \.self) { c in
                            Text("\(c.rawValue)列").tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("columns")
                }

                Section {
                    Picker("明るさ", selection: Binding(
                        get: { model.store.appearance },
                        set: { model.setAppearance($0) })
                    ) {
                        ForEach(Appearance.allCases, id: \.self) { a in
                            Text(a.label).tag(a)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("appearance")
                } header: {
                    Text("明るさ（アプリ全体）")
                } footer: {
                    Text("「自動」はiPhoneの設定に合わせます。")
                }

                // 破壊的な項目は同じ場所に固めない。誤タップの距離を稼ぐ。
                Section("このリスト") {
                    Button("チェックを全部外す") { askingReset = true }
                        .accessibilityIdentifier("clearAllFromSettings")
                }
                Section {
                    Button("リストを削除", role: .destructive) { askingDelete = true }
                        .accessibilityIdentifier("deleteList")
                }
            }

            // リストが1つも無いときでも出す（if let list の外）
            CoffeeTipSection(tipJar: tipJar)
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .alert("チェックを全部外しますか？", isPresented: $askingReset) {
            Button("全部外す", role: .destructive) { model.clearAllPacked(in: listID) }
            Button("やめる", role: .cancel) {}
        } message: {
            if let list {
                Text("\(list.items.count)個中 \(list.packedCount)個に付いているチェックが、すべて外れます。元に戻せません。")
            }
        }
        .alert("このリストを削除しますか？", isPresented: $askingDelete) {
            Button("削除する", role: .destructive) {
                model.remove(listID)
                onDeleted()
            }
            Button("やめる", role: .cancel) {}
        } message: {
            if let list {
                Text("「\(list.name)」と、書いた \(list.items.count)個の持ち物がすべて消えます。元に戻せません。")
            }
        }
    }

    /// 見本そのものを押させる。名前だけ並べても、どれがどれか分からない。
    private func paletteCard(_ palette: Palette, selected: Bool) -> some View {
        let table = ToneTable(palette: palette, groups: [0, 1, 2, 3], scheme: colorScheme.scheme)
        return Button {
            model.setPalette(palette, for: listID)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // 「済・未・済・未」。塗りの2状態と色の選び方が同時に見える並び。
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { g in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(table.tone(group: g, isPacked: g.isMultiple(of: 2)).fill.color)
                            .frame(height: 20)
                    }
                }
                HStack(spacing: 4) {
                    Text(palette.name)
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(Color.primary)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(palette.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected ? Color.accentColor : Color(.separator),
                                  lineWidth: selected ? 1.5 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("palette-\(palette.rawValue)")
    }
}
