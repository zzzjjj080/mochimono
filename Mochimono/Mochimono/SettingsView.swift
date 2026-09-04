import SwiftUI
import MochimonoCore

/// 見た目の設定。中身（編集）とは分ける。
/// 色を触るつもりで持ち物を書き換えてしまう事故を防ぐ。
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    let listID: PackingList.ID
    let onDeleted: () -> Void

    @State private var askingReset = false
    @State private var askingDelete = false
    @State private var tipJar = TipJar(productID: TipJar.productID)

    private var list: PackingList? { model.list(listID) }

    var body: some View {
        Form {
            if let list {
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
                // **同じビューに .alert を2つ重ねると、片方が出なくなる。**
                // 出ないほうは「押しても無反応」に見えるだけで、警告もエラーも出ない。
                // それぞれの押しボタンに付ける。
                // 書き出したものが、そのまま読み戻せること。独自の書式は足さない。
                Section {
                    ShareLink(item: list.text,
                              subject: Text(list.name),
                              message: Text(list.name)) {
                        Label("テキストで書き出す", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("exportText")
                } header: {
                    Text("盤面をテキストに戻す")
                } footer: {
                    Text("そのまま貼り付けられる普通のテキストとして渡します。受け取った側は「リストを追加」から貼るだけで、同じ盤面になります。")
                }

                Section("このリスト") {
                    Button("チェックを全部外す") { askingReset = true }
                        .accessibilityIdentifier("clearAllFromSettings")
                        .alert("チェックを全部外しますか？", isPresented: $askingReset) {
                            Button("全部外す", role: .destructive) { model.clearAllPacked(in: listID) }
                            Button("やめる", role: .cancel) {}
                        } message: {
                            Text("\(list.items.count)個中 \(list.packedCount)個に付いているチェックが、すべて外れます。元に戻せません。")
                        }
                }
                Section {
                    Button("リストを削除", role: .destructive) { askingDelete = true }
                        .accessibilityIdentifier("deleteList")
                        .alert("このリストを削除しますか？", isPresented: $askingDelete) {
                            Button("削除する", role: .destructive) {
                                model.remove(listID)
                                onDeleted()
                            }
                            Button("やめる", role: .cancel) {}
                        } message: {
                            Text("「\(list.name)」と、書いた \(list.items.count)個の持ち物がすべて消えます。元に戻せません。")
                        }
                }
            }

            // リストが1つも無いときでも出す（if let list の外）
            FeedbackSection()
            if AppFeature.showsTipJar { CoffeeTipSection(tipJar: tipJar) }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }

}
