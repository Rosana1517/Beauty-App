import UIKit
import Vision

/// 以 Vision 臉部特徵點推估臉型
enum FaceShapeDetector {
    struct Result {
        let shape: String
        let confidenceNote: String
        let lengthWidthRatio: Double
        let jawCheekRatio: Double
        let foreheadJawRatio: Double
    }

    enum DetectionError: LocalizedError {
        case noFace
        case multipleFaces
        case landmarksUnavailable

        var errorDescription: String? {
            switch self {
            case .noFace:
                return "照片中偵測不到臉部，請使用光線充足的正面照。"
            case .multipleFaces:
                return "照片中偵測到多張臉，請使用單人正面照。"
            case .landmarksUnavailable:
                return "無法解析臉部輪廓，請換一張更清晰的正面照。"
            }
        }
    }

    static func detect(from image: UIImage, completion: @escaping (Swift.Result<Result, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(DetectionError.landmarksUnavailable))
            return
        }

        let request = VNDetectFaceLandmarksRequest { request, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let faces = (request.results as? [VNFaceObservation]) ?? []
            guard !faces.isEmpty else {
                DispatchQueue.main.async { completion(.failure(DetectionError.noFace)) }
                return
            }
            guard faces.count == 1, let face = faces.first else {
                DispatchQueue.main.async { completion(.failure(DetectionError.multipleFaces)) }
                return
            }
            guard let landmarks = face.landmarks, let contour = landmarks.faceContour else {
                DispatchQueue.main.async { completion(.failure(DetectionError.landmarksUnavailable)) }
                return
            }

            let result = classify(face: face, contour: contour, landmarks: landmarks)
            DispatchQueue.main.async { completion(.success(result)) }
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// 由特徵點計算臉部比例並分類
    private static func classify(face: VNFaceObservation, contour: VNFaceLandmarkRegion2D, landmarks: VNFaceLandmarks2D) -> Result {
        let points = contour.normalizedPoints
        // faceContour 由左耳際沿下顎到右耳際；臉框比例以 boundingBox 估算
        let box = face.boundingBox
        let lengthWidthRatio = Double(box.height / max(box.width, 0.0001))

        // 臉頰寬：輪廓最左與最右點距離（上半段）
        let xs = points.map { Double($0.x) }
        let cheekWidth = (xs.max() ?? 1) - (xs.min() ?? 0)

        // 下顎寬：輪廓下三分之一區段的寬度
        let sorted = points.sorted { $0.y < $1.y }
        let lowerThird = Array(sorted.prefix(max(3, sorted.count / 3)))
        let lowXs = lowerThird.map { Double($0.x) }
        let jawWidth = (lowXs.max() ?? 0.5) - (lowXs.min() ?? 0.5)

        // 額頭寬：以左右眉毛外側點距離估算
        var foreheadWidth = cheekWidth * 0.9
        if let leftBrow = landmarks.leftEyebrow?.normalizedPoints, let rightBrow = landmarks.rightEyebrow?.normalizedPoints,
           let leftOuter = leftBrow.map({ Double($0.x) }).min(), let rightOuter = rightBrow.map({ Double($0.x) }).max() {
            foreheadWidth = rightOuter - leftOuter
        }

        let jawCheekRatio = jawWidth / max(cheekWidth, 0.0001)
        let foreheadJawRatio = foreheadWidth / max(jawWidth, 0.0001)

        let shape: String
        let note: String
        if lengthWidthRatio > 1.45 {
            shape = "長臉"
            note = "臉長明顯大於臉寬"
        } else if foreheadJawRatio > 1.35 {
            shape = "心形臉"
            note = "額頭明顯寬於下顎"
        } else if jawCheekRatio > 0.92 && lengthWidthRatio < 1.25 {
            shape = "方臉"
            note = "下顎與臉頰同寬、輪廓線條平直"
        } else if jawCheekRatio < 0.72 && foreheadJawRatio < 1.2 {
            shape = "菱形臉"
            note = "顴骨最寬、額頭與下顎收窄"
        } else if lengthWidthRatio < 1.2 {
            shape = "圓臉"
            note = "臉長臉寬接近、線條圓潤"
        } else {
            shape = "鵜蛋臉"
            note = "比例均衡"
        }

        return Result(
            shape: shape,
            confidenceNote: note,
            lengthWidthRatio: lengthWidthRatio,
            jawCheekRatio: jawCheekRatio,
            foreheadJawRatio: foreheadJawRatio
        )
    }
}

/// 各臉型的髮型建議（依台灣常見髮型語彙整理）
enum HairstyleRecommendation {
    static let byFaceShape: [String: [(style: String, reason: String)]] = [
        "圓臉": [
            ("長瀏海側分中長髮", "縱向線條拉長臉型，側分斜瀏海修飾圓潤感"),
            ("八字瀏海鎖骨髮", "八字瀏海遮住臉頰最寬處，視覺變窄"),
            ("高層次長捲髮", "頂部蓬鬆增加臉部縱向比例"),
        ],
        "長臉": [
            ("空氣瀏海及肩髮", "橫向瀏海縮短臉長，及肩長度增加橫向份量"),
            ("法式劉海波浪捲", "眉上或齊眉瀏海平衡臉部比例"),
            ("耳下短髮 Bob", "重心落在耳下，讓臉看起來更短"),
        ],
        "方臉": [
            ("側分大波浪長髮", "波浪弧度柔化下顎角度"),
            ("羽毛剪中長髮", "層次碎髮修飾腮幫線條"),
            ("八字瀏海微捲髮", "曲線瀏海弱化方正輪廓"),
        ],
        "心形臉": [
            ("下重心齊肩髮", "髮尾外翹或內彎補足下顎窄度"),
            ("法式劉海中長捲", "瀏海遮蓋較寬的額頭"),
            ("低馬尾配碎瀏海", "碎瀏海修飾額角，低馬尾平衡重心"),
        ],
        "菱形臉": [
            ("側瀏海鎖骨髮", "側瀏海柔化顴骨稜角"),
            ("蓬鬆羊毛捲", "整體蓬鬆度平衡顴骨最寬點"),
            ("耳邊碎髮中分長髮", "耳邊髮絲修飾顴骨線條"),
        ],
        "鵜蛋臉": [
            ("幾乎所有髮型都適合", "鵜蛋臉比例均衡，可依風格自由嘗試"),
            ("大膽嘗試短髮或超長髮", "比例優勢適合挑戰極端長度"),
            ("依髮質選擇直順或捲度", "以髮量髮質為主要考量即可"),
        ],
    ]
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
