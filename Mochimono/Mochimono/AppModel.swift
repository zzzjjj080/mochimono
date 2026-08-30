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

    func setPalette(_ palette: Palette, for listID: PackingList.ID) {
        guard var l = store[listID], l.palette != palette else { return }
        l.palette = palette
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

    @discardableResult
    func addList() -> PackingList.ID {
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
}
