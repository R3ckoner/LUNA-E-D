import SwiftUI

// MARK: - Highlight color options
enum HighlightColor: String, CaseIterable, Identifiable {
    case luna      // New default color
    case orange
    case blue
    case green
    case purple
    case red
    case pink
    case teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .luna: return Color(red: 229/255, green: 72/255, blue: 47/255)  // #e5482f
        case .orange: return .orange
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .red: return .red
        case .pink: return .pink
        case .teal: return .teal
        }
    }
    
    var displayName: String {
        switch self {
        case .luna: return "LUNA"
        case .orange: return "Orange"
        case .blue: return "Blue"
        case .green: return "Green"
        case .purple: return "Purple"
        case .red: return "Red"
        case .pink: return "Pink"
        case .teal: return "Teal"
        }
    }
}

struct ContentView: View {
    // Default changed to "luna"
    @AppStorage("highlightColor") private var highlightColorName: String = HighlightColor.luna.rawValue

    private var highlightColor: Color {
        HighlightColor(rawValue: highlightColorName)?.color ?? HighlightColor.luna.color
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
            
            TradeTab(highlightColor: highlightColor)
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
