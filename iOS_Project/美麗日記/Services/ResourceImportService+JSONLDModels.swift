import Foundation

struct JSONLDNode: Decodable {
    let type: String?
    let headline: String?
    let name: String?
    let description: String?
    let keywords: String?
    let datePublished: String?
    let uploadDate: String?
    let identifier: String?
    let creator: StringOrObject?
    let author: StringOrObject?
    let image: StringOrArrayOrObject?

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case headline
        case name
        case description
        case keywords
        case datePublished
        case uploadDate
        case identifier
        case creator
        case author
        case image
    }

    func flattened() -> [String: String] {
        [
            "@type": type ?? "",
            "headline": headline ?? "",
            "name": name ?? "",
            "description": description ?? "",
            "keywords": keywords ?? "",
            "datePublished": datePublished ?? "",
            "uploadDate": uploadDate ?? "",
            "identifier": identifier ?? "",
            "creator": creator?.stringValue ?? "",
            "authorName": author?.stringValue ?? "",
            "image": image?.stringValue ?? ""
        ]
    }
}

enum StringOrObject: Decodable {
    case string(String)
    case object(NameValue)
    case objects([NameValue])

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .object(let value):
            return value.name ?? value.value ?? ""
        case .objects(let values):
            return values.compactMap { $0.name ?? $0.value }.first ?? ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(NameValue.self) {
            self = .object(value)
            return
        }
        self = .objects((try? container.decode([NameValue].self)) ?? [])
    }
}

enum StringOrArrayOrObject: Decodable {
    case string(String)
    case array([String])
    case object(NameValue)

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .array(let values):
            return values.first ?? ""
        case .object(let value):
            return value.url ?? value.name ?? value.value ?? ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let values = try? container.decode([String].self) {
            self = .array(values)
            return
        }
        self = .object((try? container.decode(NameValue.self)) ?? NameValue(name: nil, value: nil, url: nil, id: nil))
    }
}

struct NameValue: Decodable {
    let name: String?
    let value: String?
    let url: String?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case url
        case id = "@id"
    }
}


