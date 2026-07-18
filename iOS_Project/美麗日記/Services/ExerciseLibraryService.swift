import Foundation

/// 查詢 Supabase `exercise_library` 公開唯讀表(匿名 key 即可讀)。
struct ExerciseLibraryService {
    let client: SupabaseRESTClient

    static func makeDefault() -> ExerciseLibraryService {
        ExerciseLibraryService(
            client: SupabaseRESTClient(
                baseURL: AppRuntimeConfiguration.supabaseURL,
                anonKey: AppRuntimeConfiguration.supabaseAnonKey
            )
        )
    }

    var isConfigured: Bool {
        !client.baseURL.isEmpty && !client.anonKey.isEmpty
    }

    /// 依條件分頁查詢。所有條件皆為可選;search 同時比對中英文名稱。
    func fetchItems(
        typeFilter: ExerciseLibraryTypeFilter,
        bodyPartZh: String?,
        difficultyZh: String?,
        search: String,
        page: Int,
        pageSize: Int = ExerciseLibraryConstants.pageSize
    ) async throws -> [ExerciseLibraryItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "order", value: "name_en.asc"),
            URLQueryItem(name: "limit", value: "\(pageSize)"),
            URLQueryItem(name: "offset", value: "\(page * pageSize)")
        ]

        if let itemType = typeFilter.itemTypeValue {
            queryItems.append(URLQueryItem(name: "item_type", value: "eq.\(itemType)"))
        }
        if let bodyPartZh, !bodyPartZh.isEmpty {
            queryItems.append(URLQueryItem(name: "body_part_zh", value: "eq.\(bodyPartZh)"))
        }
        if let difficultyZh, !difficultyZh.isEmpty {
            queryItems.append(URLQueryItem(name: "difficulty_zh", value: "eq.\(difficultyZh)"))
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
            table: "exercise_library",
            queryItems: queryItems,
            responseType: [ExerciseLibraryItem].self
        )
    }

    /// 呼叫 exercise-match Edge Function:需求文字 → AI 挑選的動作 + 理由。
    /// 需要已登入(函式以 bearer token 解析使用者,讀取其 AI 供應商設定)。
    func matchExercises(need: String) async throws -> [ExerciseMatchResult] {
        struct Payload: Encodable {
            let need: String
        }
        let response = try await client.invokeFunction(
            named: AppRuntimeConfiguration.exerciseMatchFunction,
            payload: Payload(need: need),
            responseType: ExerciseMatchResponse.self
        )
        return response.matches
    }
}
