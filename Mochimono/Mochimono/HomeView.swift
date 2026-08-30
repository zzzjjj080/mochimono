import SwiftUI
import MochimonoCore

/// リストの一覧。出かける前にここから選ぶ。
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let open: (PackingList.ID) -> Void
    let addAndEdit: (PackingList.ID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(model.store.lists) { list in     // 添字ではなく要素を回す（引き継ぎ書 4-10）
                    Button { open(list.id) } label: { row(list) }
                        .buttonStyle(.plain)             // 中の文字色が青に染まるのを止める
                        .accessibilityIdentifier("list-\(list.name)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if model.store.lists.isEmpty {
                Text("リストがありません。\n右上の「＋」から作れます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 60)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("モチモノ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addAndEdit(model.addList())
                } label: {
                    Label("追加", systemImage: "plus")
                }
                .accessibilityIdentifier("addList")
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
