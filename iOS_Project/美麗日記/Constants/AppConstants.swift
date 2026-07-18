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
    static let supabaseAuthRedirectURLEnv = "SUPABASE_AUTH_REDIRECT_URL"
    static let resourceSyncUserIDEnv = "RESOURCE_SYNC_USER_ID"
    static let resourceImportFunctionEnv = "SUPABASE_RESOURCE_IMPORT_FUNCTION"
    static let resourceReparseFunctionEnv = "SUPABASE_RESOURCE_REPARSE_FUNCTION"
    static let resourceRecommendationFunctionEnv = "SUPABASE_RESOURCE_RECOMMENDATION_FUNCTION"
    static let resourceMediaCleanupFunctionEnv = "SUPABASE_RESOURCE_MEDIA_CLEANUP_FUNCTION"
    static let aiAdviceFunctionEnv = "SUPABASE_AI_ADVICE_FUNCTION"
    static let videoTranscribeFunctionEnv = "SUPABASE_VIDEO_TRANSCRIBE_FUNCTION"
    static let dietAnalyzeFunctionEnv = "SUPABASE_DIET_ANALYZE_FUNCTION"
    static let instagramAppIDEnv = "INSTAGRAM_APP_ID"
    static let instagramRedirectURIEnv = "INSTAGRAM_REDIRECT_URI"
    static let xiaohongshuClientIDEnv = "XIAOHONGSHU_CLIENT_ID"
    static let xiaohongshuRedirectURIEnv = "XIAOHONGSHU_REDIRECT_URI"

    static var youtubeAPIKey: String {
        ProcessInfo.processInfo.environment[youtubeAPIKeyEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Environment variables (set via the Xcode scheme) only exist when
    /// Xcode itself launches the app - debug runs, or XCUITest's
    /// app.launchEnvironment. A normally-launched app (tap the home screen
    /// icon, including a sideloaded AltStore build) gets none of that, so
    /// real distribution falls back to values baked into Info.plist at
    /// compile time via $(SUPABASE_URL_VALUE)-style build setting macros.
    private static func configValue(env: String, infoPlistKey: String) -> String {
        if let fromEnv = ProcessInfo.processInfo.environment[env]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fromEnv.isEmpty {
            return fromEnv
        }
        return (Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var supabaseURL: String {
        configValue(env: supabaseURLEnv, infoPlistKey: "SupabaseURL")
    }

    static var supabaseAnonKey: String {
        configValue(env: supabaseAnonKeyEnv, infoPlistKey: "SupabaseAnonKey")
    }

    static var supabaseAuthRedirectURL: String {
        let configured = ProcessInfo.processInfo.environment[supabaseAuthRedirectURLEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return configured.isEmpty ? "beautydiary://auth/callback" : configured
    }

    static var resourceSyncUserID: String {
        let override = ProcessInfo.processInfo.environment[resourceSyncUserIDEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty {
            return override
        }
        return SupabaseSessionStore.currentSession()?.userID ?? ""
    }

    static var resourceImportFunction: String {
        ProcessInfo.processInfo.environment[resourceImportFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "resource-import"
    }

    static var resourceReparseFunction: String {
        ProcessInfo.processInfo.environment[resourceReparseFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "resource-reparse"
    }

    static var resourceRecommendationFunction: String {
        ProcessInfo.processInfo.environment[resourceRecommendationFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "resource-recommendation"
    }

    static var resourceMediaCleanupFunction: String {
        ProcessInfo.processInfo.environment[resourceMediaCleanupFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "resource-media-cleanup"
    }

    static var aiAdviceFunction: String {
        ProcessInfo.processInfo.environment[aiAdviceFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "ai-advice"
    }

    static var videoTranscribeFunction: String {
        ProcessInfo.processInfo.environment[videoTranscribeFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "video-transcribe"
    }

    static var dietAnalyzeFunction: String {
        ProcessInfo.processInfo.environment[dietAnalyzeFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "diet-analyze"
    }

    static let productLookupFunctionEnv = "SUPABASE_PRODUCT_LOOKUP_FUNCTION"

    static var productLookupFunction: String {
        ProcessInfo.processInfo.environment[productLookupFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "product-lookup"
    }

    static let exerciseMatchFunctionEnv = "SUPABASE_EXERCISE_MATCH_FUNCTION"

    static var exerciseMatchFunction: String {
        ProcessInfo.processInfo.environment[exerciseMatchFunctionEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "exercise-match"
    }

    static var instagramAppID: String {
        ProcessInfo.processInfo.environment[instagramAppIDEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var instagramRedirectURI: String {
        ProcessInfo.processInfo.environment[instagramRedirectURIEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var xiaohongshuClientID: String {
        ProcessInfo.processInfo.environment[xiaohongshuClientIDEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var xiaohongshuRedirectURI: String {
        ProcessInfo.processInfo.environment[xiaohongshuRedirectURIEnv]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var hasYouTubeAPI: Bool {
        !youtubeAPIKey.isEmpty
    }

    static var hasSupabaseConfig: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }

    static var hasSupabaseAuthRedirectURL: Bool {
        !supabaseAuthRedirectURL.isEmpty
    }

    static var hasInstagramOAuthConfig: Bool {
        !instagramAppID.isEmpty && !instagramRedirectURI.isEmpty
    }

    static var hasXiaohongshuOAuthConfig: Bool {
        !xiaohongshuClientID.isEmpty && !xiaohongshuRedirectURI.isEmpty
    }
}
