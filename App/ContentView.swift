import SwiftUI
import UIKit
import CoreLocation
import AVFoundation

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2")
                }

            SteamSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.blue)
    }
}
