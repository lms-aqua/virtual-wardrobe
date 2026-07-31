import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    case decoding
    case network(String)
    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "Server error \(code): \(body)"
        case .decoding: return "Could not read the server response."
        case .network(let m): return m
        }
    }
}

/// Async/await networking layer. Native clients authenticate with the bearer
/// token (Authorization header), not cookies. All calls hit `AppConfig.baseURL`.
struct APIClient {
    var token: String?

    private func request(
        _ method: String, _ path: String, json: [String: Any]? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        if let json { req.httpBody = try JSONSerialization.data(withJSONObject: json) }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.network("No response") }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            }
            return data
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decoding }
    }

    // MARK: Auth
    func requestMagicLink(email: String, isAdult: Bool) async throws -> MagicLinkResponse {
        try decode(await request("POST", "auth/magic-link",
                                 json: ["email": email, "is_adult": isAdult]))
    }
    func verifyMagicLink(token: String) async throws -> AuthToken {
        try decode(await request("POST", "auth/magic-link/verify", json: ["token": token]))
    }
    func me() async throws -> UserDTO { try decode(await request("GET", "me")) }
    func deleteAccount() async throws {
        _ = try await request("POST", "account/deletion-request", json: ["scope": "full_account"])
    }

    // MARK: Consent
    func grantScanConsent() async throws {
        _ = try await request("POST", "consents", json: ["kind": "scan", "version": "1.0"])
    }

    // MARK: Scans
    func createScan(heightCm: Double?) async throws -> ScanDTO {
        var body: [String: Any] = ["capture_mode": "camera"]
        if let heightCm { body["height_cm"] = heightCm }
        return try decode(await request("POST", "scans", json: body))
    }
    func uploadURL(scanId: String, view: String, contentType: String) async throws -> UploadURLResponse {
        try decode(await request("POST", "scans/\(scanId)/upload-url",
                                 json: ["view": view, "content_type": contentType]))
    }
    func completeScan(scanId: String) async throws -> ScanCompleteResponse {
        try decode(await request("POST", "scans/\(scanId)/complete",
                                 extraHeaders: ["Idempotency-Key": UUID().uuidString]))
    }
    func job(_ id: String) async throws -> JobDTO { try decode(await request("GET", "jobs/\(id)")) }

    // MARK: Avatars / wardrobe
    func avatars() async throws -> [AvatarDTO] { try decode(await request("GET", "avatars")) }
    func patchMeasurements(avatarId: String, _ patch: MeasurementPatch) async throws -> AvatarDTO {
        let data = try JSONEncoder().encode(patch)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try decode(await request("PATCH", "avatars/\(avatarId)/measurements", json: json))
    }
    func garments() async throws -> [GarmentDTO] { try decode(await request("GET", "garments")) }
    func outfits() async throws -> [OutfitDTO] { try decode(await request("GET", "outfits")) }
    func deleteOutfit(_ id: String) async throws { _ = try await request("DELETE", "outfits/\(id)") }
    func createOutfit(name: String, avatarId: String?, items: [OutfitItemIn]) async throws -> OutfitDTO {
        let encodedItems = items.map { item -> [String: Any] in
            var d: [String: Any] = ["garment_id": item.garmentId, "layer_index": item.layerIndex]
            if let s = item.sizeLabel { d["size_label"] = s }
            return d
        }
        var body: [String: Any] = ["name": name, "items": encodedItems]
        if let avatarId { body["avatar_id"] = avatarId }
        return try decode(await request("POST", "outfits", json: body))
    }

    // MARK: Presigned upload (multipart/form-data — standard S3/MinIO POST)
    func uploadToPresigned(_ presigned: UploadURLResponse, imageData: Data) async throws {
        guard let url = URL(string: presigned.url) else { throw APIError.network("bad upload url") }
        let boundary = "vw-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        for (k, v) in presigned.fields { field(k, v) }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(presigned.view).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, resp) = try await URLSession.shared.upload(for: req, from: body)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
