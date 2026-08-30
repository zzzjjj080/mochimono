import SwiftUI
import MochimonoCore

/// リストの一覧。出かける前にここから選ぶ。
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let open: (PackingList.ID) -> Void
    let add: () -> Void

    /// 削除待ち。**スワイプからも設定画面からも、確認は同じ1本を通す。**
    /// 経路ごとに確認を書くと、片方だけ確認を迂回する道ができる（引き継ぎ書 4-12）。
    @State private var pendingDelete: PackingList?

    var body: some View {
        List {
            ForEach(model.store.lists) { list in     // 添字ではなく要素を回す（引き継ぎ書 4-10）
                Button { open(list.id) } label: { row(list) }
                    .buttonStyle(.plain)             // 中の文字色が青に染まるのを止める
                    .accessibilityIdentifier("list-\(list.name)")
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button("削除", role: .destructive) { pendingDelete = list }
                            .accessibilityIdentifier("swipeDelete")
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if model.store.lists.isEmpty {
                ContentUnavailableView {
                    Label("リストがありません", systemImage: "checklist")
                } description: {
                    Text("右上の「＋」から、旅行や通勤などの雛形を選んで作れます。")
                }
            }
        }
        .navigationTitle("Tilecheck")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: add) { Label("追加", systemImage: "plus") }
                    .accessibilityIdentifier("addList")
            }
        }
        .alert("このリストを削除しますか？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("削除する", role: .destructive) {
                if let target = pendingDelete { model.remove(target.id) }
                pendingDelete = nil
            }
            Button("やめる", role: .cancel) { pendingDelete = nil }
        } message: {
            if let target = pendingDelete {
                Text("「\(target.name)」と、書いた \(target.items.count)個の持ち物がすべて消えます。元に戻せません。")
            }
        }
    }

    private func row(_ list: PackingList) -> some View {
        let table = ToneTable(palette: list.palette,
                              groups: list.groups,
                              scheme: colorScheme.scheme)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(list.name)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.primary)
                HStack(spacing: 3) {
                    ForEach(list.groups.prefix(6), id: \.self) { g in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(table.tone(group: g, isPacked: true).fill.color)
                            .frame(width: 16, height: 7)
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(list.packedCount)")
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundStyle(list.isComplete ? Color.green : Color.primary)
                    Text("/\(list.items.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(list.isComplete ? "そろった" : "個")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 9))
    }
}
