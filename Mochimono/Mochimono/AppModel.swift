import Foundation
import Observation
import MochimonoCore

/// 画面が見る唯一の状態。**書き換えは必ずここを通す。**
/// 経路を増やすと、保存を忘れる道や確認を迂回する道ができる（引き継ぎ書 4-12）。
@Observable
@MainActor
final class AppModel {
    private(set) var store: Store

    /// 保存できなかった理由。握り潰さず画面に出す（引き継ぎ書 4-1）。
    private(set) var saveError: String?

    private let defaults: UserDefaults
    private static let key = "mochimono.store.v1"

    init(defaults: UserDefaults = .standard) {
        #if DEBUG
        // 掲載用スクリーンショットのための状態。実際に触って作ると毎回ずれる。
        // **リリース構成には残らないこと**を strings で確認すること（引き継ぎ書 4-7）。
        if CommandLine.arguments.contains("-screenshot-demo") {
            let suite = UserDefaults(suiteName: "mochimono.demo")!
            suite.removePersistentDomain(forName: "mochimono.demo")
            self.defaults = suite
            store = Self.demoStore()
            return
        }
        // UIテストは毎回まっさらから始める。前回の状態が残ると結果が変わる。
        if CommandLine.arguments.contains("-ui-testing") {
            let suite = UserDefaults(suiteName: "mochimono.uitest")!
            suite.removePersistentDomain(forName: "mochimono.uitest")
            self.defaults = suite
            store = .starter
            return
        }
        #endif
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                store = try JSONDecoder().decode(Store.self, from: data)
            } catch {
                // 読めなかったことを黙って初期化で覆い隠さない。
                store = .starter
                saveError = "保存の読み込みに失敗しました：\(error.localizedDescription)"
            }
        } else {
            store = .starter
        }
    }

    // MARK: - 参照

    func list(_ id: PackingList.ID) -> PackingList? { store[id] }

    // MARK: - 書き換え

    func toggle(_ item: Item.ID, in listID: PackingList.ID) {
        guard var l = store[listID] else { return }
        l.toggle(item)
        let packed = l.items.first { $0.id == item }?.isPacked ?? false
        store[listID] = l
        Haptics.check(on: packed)
        save()
    }

    /// チェックを全部外す。**破壊的な操作はこの1本だけ。** 呼ぶ前に必ず確認を通す。
    func clearAllPacked(in listID: PackingList.ID) {
        guard var l = store[listID] else { return }
        l.clearAllPacked()
        store[listID] = l
        Haptics.done()
        save()
    }

    /// 編集画面を開かずに1つ足す。
    func append(_ line: String, to listID: PackingList.ID) {
        guard var l = store[listID] else { return }
        let before = l.items.count
        l.append(line)
        guard l.items.count != before else { return }   // 空白だけなら何もしない
        store[listID] = l
        Haptics.done()
        save()
    }

    /// リストの並べ替え。使う順に並べられないと、増えたときに探すことになる。
    func moveLists(from source: IndexSet, to destination: Int) {
        store.moveLists(fromOffsets: source, toOffset: destination)
        Haptics.select()
        save()
    }

    func updateContents(of listID: PackingList.ID, name: String, text: String) {
        guard var l = store[listID] else { return }
        l.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "名前のないリスト"
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        l.updateText(text)
        store[listID] = l
        Haptics.done()
        save()
    }

    /// 配色を1つ送る。設定画面を開かせず、リストを見ながら決められるようにするため、
    /// 出入り口はこの1本だけにする。
    func cyclePalette(forward: Bool, for listID: PackingList.ID) {
        guard var l = store[listID] else { return }
        l.palette = forward ? l.palette.next() : l.palette.previous()
        store[listID] = l
        Haptics.select()
        save()
    }

    func setColumns(_ columns: Columns, for listID: PackingList.ID) {
        guard var l = store[listID], l.columns != columns else { return }
        l.columns = columns
        store[listID] = l
        Haptics.select()
        save()
    }

    func setAppearance(_ appearance: Appearance) {
        guard store.appearance != appearance else { return }
        store.appearance = appearance
        Haptics.select()
        save()
    }

    /// 雛形から作る。以後は雛形と関係なく編集できる。
    @discardableResult
    func addList(from preset: Preset) -> PackingList.ID {
        let l = preset.makeList()
        store.lists.append(l)
        Haptics.done()
        save()
        return l.id
    }

    @discardableResult
    func addBlankList() -> PackingList.ID {
        let l = PackingList(name: "新しいリスト", text: "")
        store.lists.append(l)
        Haptics.select()
        save()
        return l.id
    }

    func remove(_ listID: PackingList.ID) {
        store.remove(id: listID)
        Haptics.warn()
        save()
    }

    // MARK: - 保存

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(store), forKey: Self.key)
            saveError = nil
        } catch {
            saveError = "保存できませんでした：\(error.localizedDescription)"
        }
    }

    func dismissSaveError() { saveError = nil }

    #if DEBUG
    /// 掲載用の見本。進み具合が全部同じだと、画面が説明にならない。
    private static func demoStore() -> Store {
        var lists: [PackingList] = ["trip-domestic", "commute", "camp", "town", "gym"]
            .compactMap { Preset.preset(id: $0)?.makeList() }
        lists[0].palette = Palette(1)
        lists[1].palette = Palette(4)
        lists[2].palette = Palette(7)
        lists[3].palette = Palette(10)
        lists[4].palette = Palette(12)
        // 名前で指してチェックする。添字だと雛形を直したときに別のものが付く。
        let packed: [Int: [String]] = [
            0: ["財布", "スマホ", "鍵", "免許証", "着替え", "下着", "歯ブラシ", "充電器", "常備薬"],
            1: ["財布", "スマホ", "鍵", "社員証", "定期券"],
            2: ["テント", "ペグ", "寝袋", "ランタン", "炭"],
            3: ["財布", "スマホ"],
            4: ["ウェア", "シューズ", "タオル", "水筒"],
        ]
        for (index, names) in packed {
            for name in names {
                if let item = lists[index].items.first(where: { $0.text == name }) {
                    lists[index].toggle(item.id)
                }
            }
        }
        return Store(appearance: .system, lists: lists)
    }
    #endif
}
