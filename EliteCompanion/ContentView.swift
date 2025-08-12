import SwiftUI

// MARK: - Highlight color options
enum HighlightColor: String, CaseIterable, Identifiable {
    case orange, blue, green, purple, red, pink, teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .red: return .red
        case .pink: return .pink
        case .teal: return .teal
        }
    }
}

struct ContentView: View {
    @AppStorage("highlightColor") private var highlightColorName: String = HighlightColor.orange.rawValue

    private var highlightColor: Color {
        HighlightColor(rawValue: highlightColorName)?.color ?? .orange
    }

    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray.withAlphaComponent(0.7)
    }
    
    var body: some View {
        TabView {
            CommanderTab(highlightColor: highlightColor)
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("CMDR")
                }
            
            TradingTab(highlightColor: highlightColor)
                .tabItem {
                    Image(systemName: "globe.americas.fill")
                    Text("System")
                }
            
            ListsTab(highlightColor: highlightColor)
                .tabItem {
                    Image(systemName: "list.clipboard.fill")
                    Text("Notes")
                }
            
            SettingsTab()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .accentColor(highlightColor)  // <-- This sets the tab bar tint color!
    }
}
