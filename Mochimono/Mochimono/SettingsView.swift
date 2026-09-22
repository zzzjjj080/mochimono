import SwiftUI
import MochimonoCore

/// 見た目の設定。中身（編集）とは分ける。
/// 色を触るつもりで持ち物を書き換えてしまう事故を防ぐ。
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    let listID: PackingList.ID
    let onDeleted: () -> Void

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
                            Text(a.label(model.language)).tag(a)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("appearance")
                } header: {
                    Text("明るさ（アプリ全体）")
                } footer: {
                    Text("「自動」はiPhoneの設定に合わせます。")
                }

                // 「チェックを全部外す」はここに置かない（2026-09-16）。
                // 盤面の下に同じものがあり、**同じ操作への入口が2つあると、
                // どちらに確認が付いているのかが分からなくなる。**
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

            // 入っている版の印。実機に入れ替わったかを画面で確かめるため（引き継ぎ書 4-145）
            Section {} footer: {
                Text(verbatim: Self.buildLabel)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("buildLabel")
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 例：`1.3 (5) · b52 09/22 10:30`。Xcode から直接ビルドしたときは印が空なので、版番号だけ出す
    static let buildLabel: String = {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
        guard let stamp = info["TCBuildStamp"] as? String, !stamp.isEmpty else { return version }
        return "\(version) · \(stamp)"
    }()

}
