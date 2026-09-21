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
                    // 複製は左から。削除と同じ側に並べると、押し間違いが消去になる。
                    .swipeActions(edge: .leading) {
                        Button("複製") { model.duplicate(list.id) }
                            .tint(.indigo)
                            .accessibilityIdentifier("swipeDuplicate")
                    }
            }
            // 並べ替えは編集モードの中だけ。ふだんは行のタップを邪魔しない
            .onMove { model.moveLists(from: $0, to: $1) }
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
            if model.store.lists.count > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton().accessibilityIdentifier("reorder")
                }
            }
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

    /// 「今日」「昨日」だけ言葉にする。日付だけだと、直近かどうかが一目で分からない。
    ///
    /// 日付の書き方は**書式の地域に任せる**（`formatted`）。「9月5日」を直書きすると、
    /// 英語の端末でも日本式の日付が出る。
    static func completedLabel(_ date: Date, now: Date = Date(),
                               calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "今日そろった") }
        if calendar.isDateInYesterday(date) { return String(localized: "昨日そろった") }
        // 年をまたいだら年も出す。「1/4」だけでは去年のものと区別が付かない。
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let day = sameYear ? date.formatted(.dateTime.month().day())
                           : date.formatted(.dateTime.year().month().day())
        return String(localized: "\(day)にそろった")
    }

    private func row(_ list: PackingList) -> some View {
        let table = ToneTable(palette: list.palette,
                              groups: list.toneGroups,
                              scheme: colorScheme.scheme)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(list.name)
                    .font(.system(.headline, weight: .heavy))
                    .foregroundStyle(Color.primary)
                HStack(spacing: 3) {
                    ForEach(list.groups.prefix(6), id: \.self) { g in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(table.tone(group: list.toneGroup(g), isPacked: true).fill.color)
                            .frame(width: 16, height: 7)
                    }
                }
                // 使い回すリストは、前に使ったのがいつかが次の判断材料になる。
                if let last = list.lastCompletedAt {
                    Text("前回 \(Self.completedLabel(last))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("lastCompleted-\(list.name)")
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(list.packedCount)")
                        .font(.system(.title2, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(list.isComplete ? Color.green : Color.primary)
                    Text("/\(list.items.count)")
                        .font(.system(.footnote, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                // 三項演算子に文字列を2つ書くと String 扱いになり、訳が効かない。Text ごと選ぶ
                (list.isComplete ? Text("そろった") : Text("個"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 9))
    }
}
