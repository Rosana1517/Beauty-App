import Foundation

/// 查詢 Supabase `face_exercise_library` 公開唯讀表(匿名 key 即可讀)。
/// AI 匹配沿用 exercise-match Edge Function,帶 library="face" 參數。
struct FaceExerciseLibraryService {
    let client: SupabaseRESTClient

    static func makeDefault() -> FaceExerciseLibraryService {
        FaceExerciseLibraryService(
            client: SupabaseRESTClient(
                baseURL: AppRuntimeConfiguration.supabaseURL,
                anonKey: AppRuntimeConfiguration.supabaseAnonKey
            )
        )
    }

    var isConfigured: Bool {
        !client.baseURL.isEmpty && !client.anonKey.isEmpty
    }

    /// 全庫僅數十筆,一次取回;可選類型過濾與名稱搜尋。
    func fetchItems(
        typeFilter: FaceExerciseTypeFilter,
        search: String
    ) async throws -> [FaceExerciseItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "order", value: "item_type.asc,name_en.asc"),
            URLQueryItem(name: "limit", value: "100")
        ]

        if let itemType = typeFilter.itemTypeValue {
            queryItems.append(URLQueryItem(name: "item_type", value: "eq.\(itemType)"))
        }

        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            let escaped = keyword
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "(", with: " ")
                .replacingOccurrences(of: ")", with: " ")
                .trimmingCharacters(in: .whitespaces)
            if !escaped.isEmpty {
                queryItems.append(
                    URLQueryItem(name: "or", value: "(name_zh.ilike.*\(escaped)*,name_en.ilike.*\(escaped)*)")
                )
            }
        }

        return try await client.select(
            table: "face_exercise_library",
            queryItems: queryItems,
            responseType: [FaceExerciseItem].self
        )
    }

    /// 呼叫 exercise-match Edge Function(library=face):
    /// 臉部困擾文字 → AI 從面部動作庫挑選動作 + 理由。需要已登入。
    func matchExercises(need: String) async throws -> [FaceExerciseMatchResult] {
        struct Payload: Encodable {
            let need: String
            let library: String
        }
        let response = try await client.invokeFunction(
            named: AppRuntimeConfiguration.exerciseMatchFunction,
            payload: Payload(need: need, library: "face"),
            responseType: FaceExerciseMatchResponse.self
        )
        return response.matches
    }
}
