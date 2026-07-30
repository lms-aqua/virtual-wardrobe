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
    let chestCm: Double?
    let waistCm: Double?
    let hipCm: Double?
    enum CodingKeys: String, CodingKey {
        case heightCm = "height_cm"; case chestCm = "chest_cm"
        case waistCm = "waist_cm"; case hipCm = "hip_cm"
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

struct GarmentDTO: Codable, Identifiable {
    let id: String
    let brand: String
    let name: String
    let category: String
    let thumbUrl: String?
    enum CodingKeys: String, CodingKey {
        case id; case brand; case name; case category; case thumbUrl = "thumb_url"
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

struct OutfitDTO: Codable, Identifiable {
    let id: String
    let name: String
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
