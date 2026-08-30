import SwiftUI
import MochimonoCore

/// 中身を書く画面。プレーンテキストだけ。
struct EditView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let listID: PackingList.ID

    @State private var name = ""
    @State private var text = ""
    @State private var loaded = false
    @FocusState private var focus: Field?

    private enum Field { case name, text }

    var body: some View {
        Form {
            Section("リスト名") {
                TextField("例：野球", text: $name)
                    .focused($focus, equals: .name)
                    .accessibilityIdentifier("listName")
            }
            Section {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 260)
                    .focused($focus, equals: .text)
                    .accessibilityIdentifier("listText")
            } header: {
                Text("持ち物")
            } footer: {
                Text("""
                     ・1行 = 1つの持ち物
                     ・空行を入れると、そこでグループが分かれて色が変わります
                     ・チェックの状態は、名前が同じものは編集しても引き継がれます
                     """)
            }
        }
        .navigationTitle("編集")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    model.updateContents(of: listID, name: name, text: text)
                    dismiss()
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("save")
            }
            ToolbarItem(placement: .keyboard) {
                Spacer()
                Button("閉じる") { focus = nil }
            }
        }
        .onAppear {
            // 開くたびに読み直すと、入力中の内容が消える。最初の1回だけ。
            guard !loaded, let list = model.list(listID) else { return }
            name = list.name
            text = list.text
            loaded = true
        }
    }
}
