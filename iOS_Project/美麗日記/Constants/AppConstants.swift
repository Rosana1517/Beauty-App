import SwiftUI
import Foundation

enum AppTheme {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.94)
    static let card = Color.white
    static let primary = Color(red: 0.79, green: 0.55, blue: 0.48)
    static let primarySoft = Color(red: 0.97, green: 0.92, blue: 0.89)
    static let text = Color(red: 0.31, green: 0.23, blue: 0.20)
    static let subtext = Color(red: 0.71, green: 0.62, blue: 0.58)
    static let line = Color(red: 0.93, green: 0.89, blue: 0.86)
    static let shadow = Color.black.opacity(0.06)
    static let success = Color(red: 0.48, green: 0.73, blue: 0.57)
}

enum AppRuntimeConfiguration {
    static let youtubeAPIKeyEnv = "YOUTUBE_API_KEY"
    static let supabaseURLEnv = "SUPABASE_URL"
    static let supabaseAnonKeyEnv = "SUPABASE_ANON_KEY"

    static var youtubeAPIKey: String {
        ProcessInfo.processInfo.environment[youtubeAPIKeyEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var supabaseURL: String {
        ProcessInfo.processInfo.environment[supabaseURLEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var supabaseAnonKey: String {
        ProcessInfo.processInfo.environment[supabaseAnonKeyEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var hasYouTubeAPI: Bool {
        !youtubeAPIKey.isEmpty
    }

    static var hasSupabaseConfig: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }
}
