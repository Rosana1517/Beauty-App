import Foundation

struct SupabaseAppUserRow: Decodable {
    let id: String
    let email: String?
    let nickname: String?
    let streakDays: Int?
    let signature: String?
    let bodyFocus: String?
    let skincareFocus: String?
    let themeName: String?
    let notificationTime: String?

    var profile: UserProfileRecord {
        UserProfileRecord(
            nickname: nickname ?? "",
            streakDays: streakDays ?? 0,
            signature: signature ?? "",
            bodyFocus: bodyFocus ?? "",
            skincareFocus: skincareFocus ?? "",
            themeName: themeName ?? "",
            notificationTime: notificationTime ?? ""
        )
    }
}

struct SupabaseAIProviderSettingsPayload: Encodable {
    let userID: String
    let provider: String
    let apiKey: String
    let baseURL: String?
    let model: String?

    init(userID: String, settings: AIProviderSettings) {
        self.userID = userID
        provider = settings.provider.rawValue
        apiKey = settings.apiKey
        baseURL = settings.baseURL.nilIfEmpty
        model = settings.model.nilIfEmpty
    }
}

struct SupabaseAIProviderSettingsRow: Decodable {
    // `user_id` is intentionally omitted: JSONDecoder's `.convertFromSnakeCase`
    // can't reconstruct the "ID" acronym (it produces "userId", not "userID"),
    // and the field isn't needed here since the query already filters by
    // user_id.
    let provider: String
    let apiKey: String
    let baseURL: String?
    let model: String?

    var settings: AIProviderSettings {
        AIProviderSettings(
            provider: AIProviderKind(rawValue: provider) ?? .openai,
            apiKey: apiKey,
            baseURL: baseURL ?? "",
            model: model ?? ""
        )
    }
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case dictionary([String: JSONValue])
    case array([JSONValue])
    case null

    static func jsonString(_ value: String) -> JSONValue {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return .string(value)
        }
        return JSONValue.from(any: object)
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .dictionary(let value):
            let object = value.mapValues(\.foundationObject)
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                  let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        case .array(let value):
            let object = value.map(\.foundationObject)
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                  let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        case .null:
            return ""
        }
    }

    private var foundationObject: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .dictionary(let value):
            return value.mapValues(\.foundationObject)
        case .array(let value):
            return value.map(\.foundationObject)
        case .null:
            return NSNull()
        }
    }

    private static func from(any value: Any) -> JSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            let objCType = String(cString: number.objCType)
            return objCType == "c" ? .bool(number.boolValue) : .number(number.doubleValue)
        case let array as [Any]:
            return .array(array.map(from(any:)))
        case let dictionary as [String: Any]:
            return .dictionary(dictionary.mapValues { JSONValue.from(any: $0) })
        default:
            return .null
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .dictionary(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
