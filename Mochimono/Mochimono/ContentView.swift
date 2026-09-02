import SwiftUI
import MochimonoCore

enum Route: Hashable {
    case add
    case list(PackingList.ID)
    case edit(PackingList.ID)
    case settings(PackingList.ID)
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [Route] = []

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            HomeView(open: { path.append(.list($0)) },
                     add: { path.append(.add) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .add:
                        AddListView(
                            pickPreset: { preset in
                                // 追加の画面には戻らない。作ったリストをそのまま開く。
                                path = [.list(model.addList(from: preset))]
                            },
                            startBlank: {
                                let id = model.addBlankList()
                                path = [.list(id), .edit(id)]
                            },
                            paste: { text in
                                // 中身が無ければ何もしない。空のリストが増えるだけなので
                                if let id = model.addList(fromPastedText: text) {
                                    path = [.list(id)]
                                }
                            })
                    case .list(let id):
                        ListView(listID: id,
                                 edit: { path.append(.edit(id)) },
                                 settings: { path.append(.settings(id)) })
                    case .edit(let id):
                        EditView(listID: id)
                    case .settings(let id):
                        SettingsView(listID: id, onDeleted: {
                            path.removeAll()
                        })
                    }
                }
        }
        // 保存できないのは黙って進めてはいけない状態なので、必ず出す。
        .overlay(alignment: .bottom) {
            if let message = model.saveError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red, in: .rect(cornerRadius: 6))
                    .padding(10)
                    .onTapGesture { model.dismissSaveError() }
            }
        }
    }
}
