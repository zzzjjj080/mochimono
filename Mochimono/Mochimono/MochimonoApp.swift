import SwiftUI
import MochimonoCore

@main
struct MochimonoApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                // 明暗の指定は根に1回だけ置く。色ごとに分岐を書くと必ず破綻する。
                .preferredColorScheme(model.store.appearance.colorScheme)
                .task { Haptics.warmUp() }
        }
    }
}

extension Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
