import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Base URL for all kwtSMS API endpoints.
private let baseURL = "https://www.kwtsms.com/API/"

/// Default timeout for API requests (15 seconds).
private let requestTimeout: TimeInterval = 15

/// Perform a POST request to a kwtSMS API endpoint.
///
/// Always uses POST with JSON content type. Reads response bodies for 4xx/5xx errors
/// because kwtSMS returns JSON error details in 403 responses.
///
/// - Parameters:
///   - endpoint: The API endpoint name (e.g. "send", "balance").
///   - payload: The request body as a dictionary.
///   - logFile: Path to the JSONL log file. Empty string disables logging.
/// - Returns: Parsed JSON response as a dictionary.
/// - Throws: `KwtSMSError.networkError` or `KwtSMSError.invalidResponse`.
func apiRequest(
    endpoint: String,
    payload: [String: Any],
    logFile: String = ""
) async throws -> [String: Any] {
    let urlString = baseURL + endpoint + "/"
    guard let url = URL(string: urlString) else {
        throw KwtSMSError.networkError("Invalid URL: \(urlString)")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = requestTimeout

    let jsonData: Data
    do {
        jsonData = try JSONSerialization.data(withJSONObject: payload)
    } catch {
        throw KwtSMSError.networkError("Failed to serialize request: \(error.localizedDescription)")
    }
    request.httpBody = jsonData

    let data: Data
    do {
        (data, _) = try await URLSession.shared.data(for: request)
    } catch let error as URLError where error.code == .timedOut {
        writeLog(logFile: logFile, endpoint: endpoint, request: payload, responseBody: "", ok: false, errorMessage: "Request timed out after \(Int(requestTimeout))s")
        throw KwtSMSError.networkError("Request timed out after \(Int(requestTimeout)) seconds")
    } catch {
        writeLog(logFile: logFile, endpoint: endpoint, request: payload, responseBody: "", ok: false, errorMessage: error.localizedDescription)
        throw KwtSMSError.networkError(error.localizedDescription)
    }

    let responseBody = String(data: data, encoding: .utf8) ?? ""

    // Parse JSON response (read body even for 4xx/5xx, kwtSMS returns JSON in error bodies)
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        writeLog(logFile: logFile, endpoint: endpoint, request: payload, responseBody: responseBody, ok: false, errorMessage: "Invalid JSON response")
        throw KwtSMSError.invalidResponse("Could not parse response as JSON: \(responseBody.prefix(200))")
    }

    let isOK = (json["result"] as? String) == "OK"
    writeLog(logFile: logFile, endpoint: endpoint, request: payload, responseBody: responseBody, ok: isOK, errorMessage: nil)

    return json
}
