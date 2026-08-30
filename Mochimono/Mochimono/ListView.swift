import SwiftUI
import MochimonoCore

/// 出かける直前に触る画面。
/// グループでは行を改めず、上から詰めて並べる。区別は色だけに任せる。
struct ListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    let listID: PackingList.ID
    let edit: () -> Void
    let settings: () -> Void

    @State private var askingReset = false
    /// 「そろった」の触覚は、そろった瞬間に1回だけ。毎回の描画で鳴らさない。
    @State private var wasComplete = false

    private var list: PackingList? { model.list(listID) }

    var body: some View {
        Group {
            if let list {
                content(list)
            } else {
                Color(.systemGroupedBackground)   // 削除直後など
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(list?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let list {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(list.packedCount)/\(list.items.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("設定", action: settings)
                        .accessibilityIdentifier("openSettings")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        // 破壊的な操作は、何が起きるかを具体的に書いて確認を通す。
        // **confirmationDialog は使わない。** iOS 26 では画面の真ん中にポップオーバーで出て、
        // しかも「やめる」が落ちる（取り消せない確認になる）。alert は必ず両方出る。
        .alert("チェックを全部外しますか？", isPresented: $askingReset) {
            Button("全部外す", role: .destructive) {
                model.clearAllPacked(in: listID)
            }
            Button("やめる", role: .cancel) {}
        } message: {
            if let list {
                Text("\(list.items.count)個中 \(list.packedCount)個に付いているチェックが、すべて外れます。元に戻せません。")
            }
        }
    }

    @ViewBuilder
    private func content(_ list: PackingList) -> some View {
        let table = ToneTable(palette: list.palette,
                              groups: list.groups,
                              scheme: colorScheme.scheme)
        ScrollView {
            VStack(spacing: 12) {
                ProgressView(value: list.items.isEmpty ? 0
                                  : Double(list.packedCount) / Double(list.items.count))
                    .tint(list.isComplete ? .green : .accentColor)

                if list.isComplete {
                    Text("ヨシ！ 全部そろいました")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green, in: .rect(cornerRadius: 8))
                }

                if list.items.isEmpty {
                    Text("まだ何も入っていません。\n下の「編集」から書けます。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 50)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3),
                                             count: list.columns.rawValue),
                              spacing: 3) {
                        ForEach(list.items) { item in     // 添字ではなく要素を回す
                            cell(item, list: list, table: table)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .onChange(of: list.isComplete) { _, complete in
            if complete && !wasComplete { Haptics.complete() }
            wasComplete = complete
        }
        .onAppear { wasComplete = list.isComplete }
    }

    private func cell(_ item: Item, list: PackingList, table: ToneTable) -> some View {
        let tone = table.tone(group: item.group, isPacked: item.isPacked)
        return Button {
            model.toggle(item.id, in: listID)
        } label: {
            Text(item.text)
                .font(.system(size: baseFontSize(list.columns), weight: .heavy))
                .foregroundStyle(tone.label.color)
                .lineLimit(2)
                .minimumScaleFactor(0.45)      // 長い名前は自動で縮める
                .allowsTightening(true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 5)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tone.fill.color, in: .rect(cornerRadius: 5))
                .overlay(alignment: .topTrailing) {
                    if item.isPacked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(tone.label.color)
                            .padding(4)
                    }
                }
                .aspectRatio(list.columns.aspectRatio, contentMode: .fit)
        }
        .buttonStyle(PressableCell())
        .accessibilityIdentifier("item-\(item.text)")
        .accessibilityAddTraits(item.isPacked ? .isSelected : [])
    }

    private func baseFontSize(_ columns: Columns) -> CGFloat {
        switch columns {
        case .two: 21
        case .three: 18
        case .four: 15.5
        case .five: 13.5
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button("全部外す") { askingReset = true }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("clearAll")
            Button("編集", action: edit)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("openEdit")
        }
        .controlSize(.large)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// 押した瞬間に縮める。触覚と合わせて「押した」を返す。
private struct PressableCell: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}
