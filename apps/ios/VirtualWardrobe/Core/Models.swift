import Foundation

// Codable DTOs mirroring the FastAPI schemas. UUIDs are handled as String.

struct MagicLinkResponse: Codable {
    let sent: Bool
    let devToken: String?
    enum CodingKeys: String, CodingKey { case sent; case devToken = "dev_token" }
}

struct AuthToken: Codable {
    let accessToken: String
    let userId: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
    }
}

struct UserDTO: Codable, Identifiable {
    let id: String
    let email: String
    let isAdult: Bool
    enum CodingKeys: String, CodingKey { case id; case email; case isAdult = "is_adult" }
}

struct ScanDTO: Codable, Identifiable {
    let id: String
    let status: String
}

struct UploadURLResponse: Codable {
    let view: String
    let url: String
    let fields: [String: String]
    let maxBytes: Int
    enum CodingKeys: String, CodingKey { case view; case url; case fields; case maxBytes = "max_bytes" }
}

struct ScanCompleteResponse: Codable {
    let scanId: String
    let jobId: String
    let status: String
    enum CodingKeys: String, CodingKey {
        case scanId = "scan_id"; case jobId = "job_id"; case status
    }
}

struct JobDTO: Codable { let id: String; let status: String; let errorCode: String?
    enum CodingKeys: String, CodingKey { case id; case status; case errorCode = "error_code" } }

struct MeasurementDTO: Codable {
    let heightCm: Double?
    let shoulderCm: Double?
    let chestCm: Double?
    let underbustCm: Double?
    let waistCm: Double?
    let hipCm: Double?
    let inseamCm: Double?
    let torsoCm: Double?
    let armCm: Double?
    let thighCm: Double?
    let calfCm: Double?
    let neckCm: Double?
    enum CodingKeys: String, CodingKey {
        case heightCm = "height_cm"
        case shoulderCm = "shoulder_cm"
        case chestCm = "chest_cm"
        case underbustCm = "underbust_cm"
        case waistCm = "waist_cm"
        case hipCm = "hip_cm"
        case inseamCm = "inseam_cm"
        case torsoCm = "torso_cm"
        case armCm = "arm_cm"
        case thighCm = "thigh_cm"
        case calfCm = "calf_cm"
        case neckCm = "neck_cm"
    }
}

/// Editable measurement payload for PATCH /avatars/{id}/measurements.
struct MeasurementPatch: Encodable {
    var heightCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var hipCm: Double?
    var inseamCm: Double?
    var shoulderCm: Double?
    var armCm: Double?
    var torsoCm: Double?
    enum CodingKeys: String, CodingKey {
        case heightCm = "height_cm"; case chestCm = "chest_cm"
        case waistCm = "waist_cm"; case hipCm = "hip_cm"; case inseamCm = "inseam_cm"
        case shoulderCm = "shoulder_cm"; case armCm = "arm_cm"; case torsoCm = "torso_cm"
    }
}

struct AvatarDTO: Codable, Identifiable {
    let id: String
    let status: String
    let confidence: Double?
    let meshUrl: String?
    let thumbUrl: String?
    let isMock: Bool
    let measurements: MeasurementDTO?
    enum CodingKeys: String, CodingKey {
        case id; case status; case confidence
        case meshUrl = "mesh_url"; case thumbUrl = "thumb_url"
        case isMock = "is_mock"; case measurements
    }
}

struct GarmentSizeDTO: Codable {
    let sizeLabel: String
    let measurements: [String: Double]?
    enum CodingKeys: String, CodingKey { case sizeLabel = "size_label"; case measurements }
}

struct GarmentDTO: Codable, Identifiable {
    let id: String
    let brand: String
    let name: String
    let category: String
    let thumbUrl: String?
    let layeringOrder: Int
    let sizes: [GarmentSizeDTO]
    let productUrl: String?
    let priceCents: Int?
    enum CodingKeys: String, CodingKey {
        case id; case brand; case name; case category
        case thumbUrl = "thumb_url"; case layeringOrder = "layering_order"; case sizes
        case productUrl = "product_url"; case priceCents = "price_cents"
    }

    var priceText: String? {
        guard let priceCents else { return nil }
        return String(format: "$%.2f", Double(priceCents) / 100)
    }
}

struct OutfitItemIn: Codable {
    let garmentId: String
    let sizeLabel: String?
    let layerIndex: Int
    enum CodingKeys: String, CodingKey {
        case garmentId = "garment_id"; case sizeLabel = "size_label"; case layerIndex = "layer_index"
    }
}

struct OutfitItemDTO: Codable {
    let garmentId: String
    let layerIndex: Int
    enum CodingKeys: String, CodingKey {
        case garmentId = "garment_id"; case layerIndex = "layer_index"
    }
}

struct OutfitDTO: Codable, Identifiable {
    let id: String
    let name: String
    let items: [OutfitItemDTO]
}

enum ScanView: String, CaseIterable, Identifiable {
    case front, left, back, right
    var id: String { rawValue }
    var instruction: String {
        switch self {
        case .front: return "Face the camera, arms slightly away from your body."
        case .left: return "Turn 90° to your left, stay relaxed."
        case .back: return "Turn to face away from the camera."
        case .right: return "Turn 90° to your right."
        }
    }
    var symbol: String {
        switch self {
        case .front: return "person.fill"
        case .left: return "person.fill.turn.left"
        case .back: return "person.fill.and.arrow.left.and.arrow.right"
        case .right: return "person.fill.turn.right"
        }
    }
}
