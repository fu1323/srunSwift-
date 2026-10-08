
import SwiftUI

@main
struct SrunPortalApp: App {
    @StateObject private var model = PortalViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
