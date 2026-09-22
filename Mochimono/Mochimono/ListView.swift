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
    @State private var addingItem = false
    @State private var newItem = ""

    // 文字サイズの設定に追従させる。100 を基準に、いま何倍かを取る。
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 100
    /// 「そろった」の触覚は、そろった瞬間に1回だけ。毎回の描画で鳴らさない。
    @State private var wasComplete = false
    /// そろった回数。**増えたことが合図**で、紙吹雪と帯の演出をやり直す。
    @State private var burst = 0
    @State private var celebrating = false
    /// 手ぶらで準備するための読み上げ。開いたときに作り、画面を離れたら止める
    @State private var reader: ReadAloudSession?
    @Environment(\.scenePhase) private var scenePhase

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
                if !list.items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { readAloudButton }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("設定", action: settings)
                        .accessibilityIdentifier("openSettings")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        // 祝いは**画面全体**に出す。盤面の中だけだと、そろった手応えが小さい
        .overlay { if celebrating { CompleteFlash().id(burst) } }
        .onAppear { if reader == nil { reader = ReadAloudSession(language: model.language) } }
        // 画面を離れたら読み上げも止める。別のリストの品名を読み続けない
        .onDisappear { reader?.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { reader?.stop() } }
    }

    private var isReading: Bool { reader?.isRunning == true }

    /// 読み上げの入り切り。**記号だけにする**（文字を並べると、長い言語で見出しが押し出される）。
    private var readAloudButton: some View {
        Button {
            guard let reader else { return }
            if reader.isRunning { reader.stop(); return }
            Haptics.select()
            reader.start(items: { [model, listID] in model.list(listID)?.items },
                         gap: { [model] in model.store.readAloudGap },
                         voice: { [model] in model.store.readAloudVoice })
        } label: {
            Label(isReading ? "読み上げを止める" : "読み上げ",
                  systemImage: isReading ? "speaker.wave.2.fill" : "speaker.wave.2")
                .labelStyle(.iconOnly)
                .symbolEffect(.variableColor.iterative, isActive: isReading)
        }
        .accessibilityIdentifier("readAloud")
        .accessibilityHint("まだの物を順に読み上げます")
    }

    @ViewBuilder
    private func content(_ list: PackingList) -> some View {
        let table = ToneTable(palette: list.palette,
                              groups: list.toneGroups,
                              scheme: colorScheme.scheme)
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 12) {
                if !list.items.isEmpty { gauge(list, table: table) }

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
        // 読んでいる物を画面に入れる。長いリストでも、どれを読んだか目で追える
        .onChange(of: reader?.currentID) { _, id in
            guard let id else { return }
            withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
        }
        }
        .onChange(of: list.isComplete) { _, complete in
            // **そろった瞬間だけ。** 開き直すたびに祝われると煩わしい
            if complete && !wasComplete {
                Haptics.complete()
                burst += 1
                celebrating = true
            }
            wasComplete = complete
        }
        .task(id: burst) {
            guard burst > 0 else { return }
            try? await Task.sleep(for: .seconds(0.75))   // **短く。** 長いと邪魔になる
            celebrating = false
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
                // 読み上げ中の1つ。**枠だけ**付ける。塗りを変えると、持った・まだの読み方が崩れる
                .overlay {
                    if reader?.currentID == item.id {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.primary, lineWidth: 3)
                            .padding(-2)
                    }
                }
        }
        .buttonStyle(PressableCell())
        .accessibilityIdentifier("item-\(item.text)")
        .accessibilityAddTraits(item.isPacked ? .isSelected : [])
        // 読み上げでは色が伝わらないので、状態を言葉で持たせる
        .accessibilityLabel(item.text)
        // 三項演算子に文字列を2つ書くと String 扱いになり、訳が効かない。Text ごと選ぶ
        .accessibilityValue(item.isPacked ? Text("持った") : Text("まだ"))
        .accessibilityHint(item.isPacked ? Text("ダブルタップすると外します")
                                         : Text("ダブルタップすると持った印を付けます"))
    }

    /// 盤面の上の1本。**進み具合と数と知らせを、1つにまとめてある。**
    ///
    /// 細い棒と数字と知らせを別々に積むと、そろった時に段が増えて**盤面が下へずれる。**
    /// 出かける直前に見ている場所が動くと、押すつもりのマスを押し損ねる。
    /// 高さの変わらない1本にして、中身だけを差し替える。
    ///
    /// 塗りはそのリストの配色そのもの。盤面と同じ色が伸びていくので、
    /// どのリストを見ているのかが棒だけでも分かる。
    @ViewBuilder
    private func gauge(_ list: PackingList, table: ToneTable) -> some View {
        if list.isComplete {
            Button { model.clearAllPacked(in: listID) } label: { gaugeBar(list, table: table) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("completeBanner")
                .accessibilityLabel("ヨシ！ 全部そろいました")
                .accessibilityHint("押すとチェックを全部外します")
        } else {
            gaugeBar(list, table: table)
        }
    }

    private func gaugeBar(_ list: PackingList, table: ToneTable) -> some View {
        let done = list.isComplete
        let ratio = list.items.isEmpty ? 0
            : Double(list.packedCount) / Double(list.items.count)
        // 塗りの上の文字色は、配色が測って決めた読める色をそのまま使う
        // 塗りは**そのリストの1色目の濃淡**。
        // 色相をまたぐグラデーション（青→緑など）は、混ざるあたりが濁って見える。
        let first = list.groups.first ?? 0
        let head = table.tone(group: list.toneGroup(first), isPacked: true)
        let fills = done ? Self.shade(HSL(hue: 145, saturation: 68, lightness: 42))
                         : Self.shade(head.fill)
        let onFill = done ? Color.white : head.label.color
        let words = done ? String(localized: "ヨシ！ 全部そろいました")
                         // 数字も言語の書き方に合わせる。アラビア語では配色の番号だけアラビア数字になり、
                         // 帯の数だけ 0-9 のまま混ざっていた
                         : "\(list.packedCount.formatted()) / \(list.items.count.formatted())"

        return GeometryReader { geo in
            let filled = geo.size.width * (done ? 1 : ratio)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: fills, startPoint: .top, endPoint: .bottom))
                    .frame(width: filled)
                // 文字は2枚重ねる。**塗りの上と外とで読める色が違う**ので、
                // 塗った幅ぶんだけ上の1枚を出す。1枚だと境目で必ず読めなくなる。
                gaugeWords(words, color: .primary, done: done)   // 薄い灰の上では薄い字は読めない
                gaugeWords(words, color: onFill, done: done)
                    .mask(alignment: .leading) { Rectangle().frame(width: filled) }
                    .accessibilityHidden(true)          // 読み上げは下の1枚だけでよい
            }
            .overlay {
                // そろったら、光が1度だけ斜めに走る
                if done { Sheen().id(burst) }
            }
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(done ? Color.white.opacity(0.55)
                                       : Color.primary.opacity(0.07), lineWidth: done ? 2 : 1)
            }
        }
        .frame(height: 46)
        // **高さは変えない。** 変えると盤面が下へずれて、押すつもりのマスを押し損ねる。
        // 膨らませるのは見た目だけ（scaleEffect は場所を取らない）
        .scaleEffect(done ? 1.035 : 1)
        .shadow(color: done ? Color.green.opacity(0.5) : .clear, radius: 12, y: 4)
        .animation(.snappy, value: list.packedCount)
        .animation(.bouncy, value: done)
    }

    /// 同じ色相のまま、上を少し明るく・下を少し暗くする。
    /// **明度だけを動かす。** 色相や彩度まで動かすと、配色が測って決めた文字色が合わなくなる。
    private static func shade(_ base: HSL) -> [Color] {
        [HSL(hue: base.hue, saturation: base.saturation,
             lightness: min(base.lightness + 6, 96)).color,
         HSL(hue: base.hue, saturation: base.saturation,
             lightness: max(base.lightness - 7, 6)).color]
    }

    @ViewBuilder
    private func gaugeWords(_ words: String, color: Color, done: Bool) -> some View {
        Group {
            if done {
                Label(words, systemImage: "checkmark.seal.fill")
                    .font(.system(.headline, weight: .black))
                    .symbolEffect(.bounce, options: .repeat(2), value: burst)
            } else {
                Text(words)
                    .font(.system(.subheadline, weight: .heavy))
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// カラーモード。**配色の矢印の隣に置く。**    /// カラーモード。**配色の矢印の隣に置く。** 色に関わる操作を1か所にまとめ、
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

    /// 入り切りの札。**オンは塗り、オフは線だけ。** 2つとも同じ形にして、状態の読み方を揃える。
    private func chip(title: LocalizedStringKey, symbol: String, isOn: Bool, showsTitle: Bool,
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
            // 角丸は下の段のボタンと揃える。丸すぎると四角いマスと並んだときに締まらない
            .background(isOn ? Color.accentColor.opacity(0.18) : .clear, in: .rect(cornerRadius: 7))
            .contentShape(.rect)             // 余白も押せるようにする（引き継ぎ書 4-44）
        }
        .foregroundStyle(isOn ? Color.accentColor : .secondary)
        .accessibilityValue(isOn ? Text("オン") : Text("オフ"))
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
            // 色の段。**番号だけでは何色か分からない**ので、実際の色を並べて見せる
            if let reader, reader.isRunning, let list {
                readAloudRow(reader, list: list)
            } else if let list, !list.items.isEmpty {
                ViewThatFits(in: .horizontal) {
                    colorRow(list, showsTitle: true)
                    colorRow(list, showsTitle: false)
                }
            }
            HStack(spacing: 8) {
                Button("全部外す") { askingReset = true }
                    .buttonStyle(BarButton(fill: .barSecondary))
                    .accessibilityIdentifier("clearAll")
                    // 破壊的な操作は、何が起きるかを具体的に書いて確認を通す。
                    .alert("チェックを全部外しますか？", isPresented: $askingReset) {
                        Button("全部外す", role: .destructive) { model.clearAllPacked(in: listID) }
                        Button("やめる", role: .cancel) {}
                    } message: {
                        if let list {
                            Text("\(list.items.count)個中 \(list.packedCount)個に付いているチェックが、すべて外れます。元に戻せません。")
                        }
                    }
                // 記号だけだと何が増えるのか分からない。**言葉で書く。**
                Button { addingItem = true } label: {
                    Label("1つ足す", systemImage: "plus")
                }
                .buttonStyle(BarButton(fill: .barSecondary))
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
                    .buttonStyle(BarButton(fill: .barPrimary))
                    .accessibilityIdentifier("openEdit")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    /// 読み上げ中の段。配色の段と入れ替える（読み上げ中に色は触らない）。
    /// 上の行にいま読んでいる物、下の行に声と間隔の送り。**どちらも読みながら変えて聞き比べられるよう、ここに置く。**
    /// 設定画面に置くと、止めて開いて戻って、を繰り返さないと合わせられない。
    private func readAloudRow(_ reader: ReadAloudSession, list: PackingList) -> some View {
        let current = list.items.first { $0.id == reader.currentID }?.text
        let gap = model.store.readAloudGap
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(current ?? "…")
                    .font(.system(.headline, weight: .heavy))
                    .lineLimit(1)
                    .accessibilityIdentifier("readingItem")
                Spacer(minLength: 0)
            }
            // 答えは盤面のマスを押す。「次へ」「持った」は置かない（2026-09-22 本人判断）
            HStack(spacing: 6) {
                Text("声")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
                voiceArrow(back: true)
                // 声は名前を出さず番号で（配色と同じ）。名前は端末や言語で変わり、選ぶ手がかりにならない
                Text("\((model.store.readAloudVoice + 1).formatted()) / \(VoiceMenu.count.formatted())")
                    .font(.system(.subheadline, weight: .heavy))
                    .monospacedDigit()
                    .accessibilityIdentifier("readVoice")
                voiceArrow(back: false)
                Spacer(minLength: 4)
                Text("間隔")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.secondary)
                gapButton(longer: false, disabled: ReadAloudGap.isShortest(gap))
                // 秒の書き方は言語に任せる（「0.8秒」「0.8 s」「٠٫٨ ث」）
                Text(Duration.milliseconds(Int(gap * 1000)).formatted(
                        .units(allowed: [.seconds], width: .abbreviated,
                               fractionalPart: .show(length: 1))))
                    .font(.system(.subheadline, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("readGap")
                gapButton(longer: true, disabled: ReadAloudGap.isLongest(gap))
            }
        }
        .controlSize(.small)
        .padding(.bottom, 2)
    }

    private func voiceArrow(back: Bool) -> some View {
        Button { model.setReadAloudVoice(VoiceMenu.step(model.store.readAloudVoice, forward: !back)) } label: {
            Image(systemName: back ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
                .flipsForRightToLeftLayoutDirection(true)
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 28)
                .contentShape(.rect)            // 余白も押せるようにする（引き継ぎ書 4-44）
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(back ? "readVoiceBack" : "readVoiceForward")
        .accessibilityLabel(back ? Text("前の声") : Text("次の声"))
    }

    private func gapButton(longer: Bool, disabled: Bool) -> some View {
        Button {
            model.setReadAloudGap(ReadAloudGap.step(model.store.readAloudGap, longer: longer))
        } label: {
            Image(systemName: longer ? "plus" : "minus")
                .font(.system(.footnote, weight: .bold))
                .frame(width: 30, height: 26)
                .contentShape(.rect)            // 余白も押せるようにする（引き継ぎ書 4-44）
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
        .accessibilityIdentifier(longer ? "readGapLonger" : "readGapShorter")
        .accessibilityLabel(longer ? Text("間隔を長くする") : Text("間隔を短くする"))
    }

    /// 配色の段。矢印・見本・番号・カラーの4つをこの順に並べる。
    private func colorRow(_ list: PackingList, showsTitle: Bool) -> some View {
        let table = ToneTable(palette: list.palette,
                              groups: (0..<5).map(list.toneGroup),
                              scheme: colorScheme.scheme)
        return HStack(spacing: 6) {
            paletteArrow(back: true)
            // **実際の色を見せる。** 番号だけでは、送った先が何色か分からない
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { g in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(table.tone(group: list.toneGroup(g), isPacked: true).fill.color)
                        .frame(width: 18, height: 12)
                }
            }
            .accessibilityHidden(true)          // 読み上げでは色は伝わらない。番号で言う
            paletteArrow(back: false)
            Text("\(list.palette.number) / \(Palette.count)")
                .font(.system(.caption, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("paletteNumber")
            Spacer(minLength: 0)
            colorModeToggle(list, showsTitle: showsTitle)
        }
    }

    private func paletteArrow(back: Bool) -> some View {
        Button { model.cyclePalette(forward: !back, for: listID) } label: {
            Image(systemName: back ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
                // 右から左の言語では並びが反転するので、矢印の向きも反転させる。
                // しないと ▶ 見本 ◀ と内向きになって、送る向きが分からない
                .flipsForRightToLeftLayoutDirection(true)
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 30)
                .contentShape(.rect)            // 余白も押せるようにする（引き継ぎ書 4-44）
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(back ? "paletteBack" : "paletteForward")
        .accessibilityLabel(back ? Text("前の配色") : Text("次の配色"))
    }
}

/// 下の段のボタン。**丸みは控えめに、色は濃く。**
/// 標準の押しボタンは角が丸すぎて、盤面の四角いマスと並ぶと締まらない。
private struct BarButton: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .heavy))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(fill, in: .rect(cornerRadius: 7))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

extension Color {
    /// 下の段の色。**盤面の色とぶつからないよう彩度を抑えた藍と墨。**
    /// 明るさの設定で入れ替える。暗いところで濃紺のままだと、背景に沈んで押せるものに見えない。
    static let barPrimary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.33, green: 0.42, blue: 0.68, alpha: 1)
                                      : UIColor(red: 0.16, green: 0.22, blue: 0.40, alpha: 1)
    })
    static let barSecondary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.36, green: 0.39, blue: 0.44, alpha: 1)
                                      : UIColor(red: 0.38, green: 0.41, blue: 0.47, alpha: 1)
    })
}

/// そろった帯の上を1度だけ走る光。
private struct Sheen: View {
    @State private var swept = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.65), .white.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: geo.size.width * 0.28)
                .rotationEffect(.degrees(22))
                .offset(x: swept ? geo.size.width * 1.1 : -geo.size.width * 0.4)
                .onAppear {
                    // **出てから動かす。** 最初から動いた状態だと、走らずに終わる
                    withAnimation(.easeInOut(duration: 0.9).delay(0.15)) { swept = true }
                }
        }
        .allowsHitTesting(false)
    }
}

/// そろったときの祝い。**画面ぜんぶを一瞬だけ光らせる。**
///
/// 紙吹雪も試したが、盤面の中で小さく散るだけで手応えが薄かった。
/// **短く（0.5秒）、画面いっぱいに。** 長引くと次の操作の邪魔になる。
private struct CompleteFlash: View {
    @State private var on = false

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height)
            let from = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.13)   // 帯のあたり
            ZStack {
                // 画面ぜんぶが、ひと呼吸だけ緑に染まる
                Color.green.opacity(on ? 0 : 0.24)

                // 帯から光の玉がふくらむ
                Circle()
                    .fill(RadialGradient(
                        colors: [.white.opacity(0.9), Color.green.opacity(0.55), .green.opacity(0)],
                        center: .center, startRadius: 0, endRadius: side * 0.35))
                    .frame(width: side * 0.7, height: side * 0.7)
                    .scaleEffect(on ? 2.6 : 0.15)
                    .opacity(on ? 0 : 1)
                    .position(from)

                // 輪が広がって消える
                Circle()
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: on ? 1.5 : 26)
                    .frame(width: on ? side * 2.4 : 60, height: on ? side * 2.4 : 60)
                    .opacity(on ? 0 : 0.95)
                    .position(from)
            }
            .onAppear {
                // **出てから動かす。** 最初から on だと、広がらずに終わる
                withAnimation(.easeOut(duration: 0.5)) { on = true }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
