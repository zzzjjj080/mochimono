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
    /// 残りだけを見る。**保存しない。** 出かける直前だけの見かたなので、
    /// 次に開いたときは全部見えているほうが、書いた内容を確かめられる。
    @State private var showsRemainingOnly = false
    @State private var addingItem = false
    @State private var newItem = ""

    // 文字サイズの設定に追従させる。100 を基準に、いま何倍かを取る。
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 100
    /// 「そろった」の触覚は、そろった瞬間に1回だけ。毎回の描画で鳴らさない。
    @State private var wasComplete = false
    /// そろったボタンが出たときに跳ねさせるための札。**中身に意味は無く、変わることだけが合図。**
    @State private var celebrate = false

    private var list: PackingList? { model.list(listID) }

    /// 文字の倍率。伸ばしすぎると1マスが画面を覆うので上限を付ける。
    private var scale: CGFloat { min(max(typeScale / 100, 0.85), 1.9) }

    /// 実際に並べる列数。
    /// **文字を大きくする設定のときは列を減らす。** 減らさないと、
    /// 幅が足りずに自動縮小がかかって、結局もとの大きさに戻る（設定が効かない）。
    private func columns(_ list: PackingList) -> Columns {
        guard typeSize.isAccessibilitySize else { return list.columns }
        return list.columns.rawValue > 2 ? .two : list.columns
    }

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
                        .font(.system(.footnote, weight: .semibold))
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
        // 戻せるのはこの画面にいる間だけ。離れたあとに帯が生き返ると、何が戻るのか分からない
        .onDisappear { model.dismissClearUndo() }
    }

    @ViewBuilder
    private func content(_ list: PackingList) -> some View {
        let table = ToneTable(palette: list.palette,
                              groups: list.toneGroups,
                              scheme: colorScheme.scheme)
        ScrollView {
            VStack(spacing: 12) {
                ProgressView(value: list.items.isEmpty ? 0
                                  : Double(list.packedCount) / Double(list.items.count))
                    .tint(list.isComplete ? .green : .accentColor)

                if !list.items.isEmpty {
                    // 文字を大きくする設定では1行に収まらないので、記号だけの並びに切り替える
                    ViewThatFits(in: .horizontal) {
                        controlRow(list, showsTitles: true)
                        controlRow(list, showsTitles: false)
                    }
                }

                if list.isComplete {
                    Text("ヨシ！ 全部そろいました")
                        .font(.system(.subheadline, weight: .heavy))
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
                                             count: columns(list).rawValue),
                              spacing: 3) {
                        ForEach(shown(list)) { item in     // 添字ではなく要素を回す
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
        let tone = table.tone(group: list.toneGroup(item.group), isPacked: item.isPacked)
        let cols = columns(list)
        return Button {
            model.toggle(item.id, in: listID)
        } label: {
            Text(item.text)
                .font(.system(size: baseFontSize(cols) * scale, weight: .heavy))
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
                            .font(.system(size: 9 * scale, weight: .black))
                            .foregroundStyle(tone.label.color)
                            .padding(4)
                    }
                }
                // 文字が大きくなったぶんマスも縦に伸ばす。伸ばさないと縮小されて意味がない
                .aspectRatio(cols.aspectRatio / scale, contentMode: .fit)
        }
        .buttonStyle(PressableCell())
        .accessibilityIdentifier("item-\(item.text)")
        .accessibilityAddTraits(item.isPacked ? .isSelected : [])
        // 読み上げでは色が伝わらないので、状態を言葉で持たせる
        .accessibilityLabel(item.text)
        .accessibilityValue(item.isPacked ? "持った" : "まだ")
        .accessibilityHint(item.isPacked ? "二本指でダブルタップすると外します"
                                         : "二本指でダブルタップすると持った印を付けます")
    }

    /// いま並べるもの。残りだけの表示は、持った瞬間にその1つが消える。
    private func shown(_ list: PackingList) -> [Item] {
        showsRemainingOnly ? list.remainingItems : list.items
    }

    private func controlRow(_ list: PackingList, showsTitles: Bool) -> some View {
        HStack(spacing: 6) {
            paletteStepper(list)
            colorModeToggle(list, showsTitle: showsTitles)
            Spacer(minLength: 0)
            remainingToggle(showsTitle: showsTitles)
        }
    }

    /// カラーモード。**配色の矢印の隣に置く。** 色に関わる操作を1か所にまとめ、
    /// 設定画面を開かずに、盤面を見たまま切り替えて比べられるようにする。
    private func colorModeToggle(_ list: PackingList, showsTitle: Bool) -> some View {
        chip(title: "カラー",
             symbol: list.isColorful ? "paintpalette.fill" : "paintpalette",
             isOn: list.isColorful, showsTitle: showsTitle) {
            model.toggleColorMode(for: listID)
        }
        .accessibilityLabel("カラーモード")
        .accessibilityIdentifier("colorMode")
        .accessibilityHint("オンはグループごとに色が変わり、オフは全部が同じ色になります")
    }

    /// 「残りだけ」の入り切り。出かける直前は、まだ持っていないものしか見ない。
    private func remainingToggle(showsTitle: Bool) -> some View {
        chip(title: "残りだけ",
             symbol: showsRemainingOnly ? "line.3.horizontal.decrease.circle.fill"
                                        : "line.3.horizontal.decrease.circle",
             isOn: showsRemainingOnly, showsTitle: showsTitle) {
            showsRemainingOnly.toggle()
            Haptics.select()
        }
        .accessibilityLabel("残りだけ")
        .accessibilityIdentifier("remainingOnly")
        .accessibilityHint("まだ持っていないものだけを並べます")
    }

    /// 入り切りの札。**オンは塗り、オフは線だけ。** 2つとも同じ形にして、状態の読み方を揃える。
    private func chip(title: String, symbol: String, isOn: Bool, showsTitle: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if showsTitle {
                    Label(title, systemImage: symbol).labelStyle(.titleAndIcon)
                } else {
                    Image(systemName: symbol)
                }
            }
            .lineLimit(1)
            // 窮屈でも文字を「…」に潰させない。収まらなければ ViewThatFits が記号だけの並びに落とす
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, showsTitle ? 10 : 8)
            .frame(minWidth: 32, minHeight: 32)
            .background(isOn ? Color.accentColor.opacity(0.18) : .clear, in: .capsule)
            .contentShape(.capsule)          // 余白も押せるようにする（引き継ぎ書 4-44）
        }
        .foregroundStyle(isOn ? Color.accentColor : .secondary)
        .accessibilityValue(isOn ? "オン" : "オフ")
    }

    /// 配色を送る矢印。**設定画面を開かせない。**
    /// リストを見たまま送れないと、どの色が合うかを比べられない。
    private func paletteStepper(_ list: PackingList) -> some View {
        HStack(spacing: 0) {
            Button { model.cyclePalette(forward: false, for: listID) } label: {
                Image(systemName: "arrowtriangle.left.fill")
                    .frame(width: 44, height: 32)
                    .contentShape(.rect)          // 余白も押せるようにする（引き継ぎ書 4-44）
            }
            .accessibilityIdentifier("paletteBack")
            .accessibilityLabel("前の配色")
            Text("\(list.palette.number) / \(Palette.count)")
                .monospacedDigit()
                .accessibilityIdentifier("paletteNumber")
            Button { model.cyclePalette(forward: true, for: listID) } label: {
                Image(systemName: "arrowtriangle.right.fill")
                    .frame(width: 44, height: 32)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("paletteForward")
            .accessibilityLabel("次の配色")
        }
        .font(.system(.footnote, weight: .bold))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
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
        VStack(spacing: 8) {
            if let undo = model.clearUndo, undo.listID == listID { undoBar(undo) }
            HStack(spacing: 8) {
                clearButton
                Button { addingItem = true } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("持ち物を足す")
                .accessibilityIdentifier("quickAdd")
                // 1つ足すために全文の編集画面を開かせない。最後のグループの末尾に入る。
                .alert("持ち物を足す", isPresented: $addingItem) {
                    TextField("例：充電器", text: $newItem)
                    Button("足す") { model.append(newItem, to: listID); newItem = "" }
                    Button("やめる", role: .cancel) { newItem = "" }
                } message: {
                    Text("いちばん最後のグループに入ります。")
                }
                Button("編集", action: edit)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("openEdit")
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.snappy, value: model.clearUndo?.id)
    }

    /// そろったかどうかで見た目と手数が変わるボタン。
    ///
    /// **そろったら、押すべき一手はこれしかない。** 目立たせて、確認も省く。
    /// 途中で押したときは、いままでどおり件数つきの確認を通す。
    @ViewBuilder
    private var clearButton: some View {
        let done = list?.isComplete ?? false
        Group {
            if done {
                Button { model.clearAllPacked(in: listID) } label: {
                    Label("全部外す", systemImage: "arrow.counterclockwise.circle.fill")
                        .symbolEffect(.bounce, value: celebrate)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .onAppear { celebrate.toggle() }
                .accessibilityHint("確認なしですぐ外します。あとから元に戻せます")
            } else {
                Button("全部外す") { askingReset = true }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("clearAll")
        .animation(.snappy, value: done)
        // 途中で押したときだけ、何が起きるかを具体的に書いて確認を通す。
        .alert("チェックを全部外しますか？", isPresented: $askingReset) {
            Button("全部外す", role: .destructive) { model.clearAllPacked(in: listID) }
            Button("やめる", role: .cancel) {}
        } message: {
            if let list {
                Text("\(list.items.count)個中 \(list.packedCount)個に付いているチェックが、すべて外れます。")
            }
        }
    }

    /// 戻せる時間。盤面タスクの取り消しと同じく、**残りが目に見える**ようにする。
    static let undoSeconds = 6.0

    /// 外した直後だけ出る、戻すための帯。**数秒で引っ込める。**
    /// 出しっぱなしにすると盤面が隠れるうえ、いつまで戻せるのかが分からなくなる。
    private func undoBar(_ undo: AppModel.ClearUndo) -> some View {
        HStack(spacing: 10) {
            Text("チェックを外しました")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            UndoCountdownRing(seconds: Self.undoSeconds)
                .id(undo.id)                 // 外すたびに数え直す
            Button("元に戻す") { model.undoClearAllPacked() }
                .font(.system(.footnote, weight: .heavy))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("undoClear")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground), in: .capsule)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: undo.id) {
            try? await Task.sleep(for: .seconds(Self.undoSeconds))
            model.dismissClearUndo()
        }
    }
}

/// 戻せる時間が減っていくのを見せるリング。数字ではなく減り方で伝える。
private struct UndoCountdownRing: View {
    let seconds: Double
    @State private var drained = false

    var body: some View {
        Circle()
            .trim(from: 0, to: drained ? 0 : 1)
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 15, height: 15)
            .accessibilityHidden(true)          // 読み上げでは時間より「元に戻す」が先
            .onAppear {
                // **出たあとに動かす。** 最初から drained だと、描き終わる前に消える
                withAnimation(.linear(duration: seconds)) { drained = true }
            }
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
