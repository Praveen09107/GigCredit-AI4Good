import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "gigcredit/ai_native"
  private let workerQueue = DispatchQueue(label: "com.gigcredit.ai_native", qos: .userInitiated)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    guard
      let controller = window?.rootViewController as? FlutterViewController
    else {
      return ok
    }

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "inference_failed", message: "Handler deallocated", details: nil))
        return
      }
      self.workerQueue.async {
        self.handleMethod(call: call, result: result)
      }
    }

    return ok
  }

  private func handleMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "ai.health":
        respond(result, payload: [
          "ready": true,
          "engineVersion": "ios-prototype-0.1.0",
          "modelsLoaded": true
        ])

      case "ocr.extractText":
        guard
          let args = call.arguments as? [String: Any],
          let imageBytes = parseBytes(args["imageBytes"]),
          !imageBytes.isEmpty
        else {
          return respondError(result, code: "invalid_input", message: "imageBytes is required and must be non-empty")
        }

        let mean = imageBytes.map(Double.init).reduce(0.0, +) / Double(imageBytes.count)
        let confidence = min(max(0.62 + (mean / 255.0) * 0.33, 0.0), 1.0)

        respond(result, payload: [
          "rawText": "OCR extracted text block (ios native prototype).",
          "confidence": confidence
        ])

      case "authenticity.detect":
        guard
          let args = call.arguments as? [String: Any],
          let imageBytes = parseBytes(args["imageBytes"]),
          !imageBytes.isEmpty
        else {
          return respondError(result, code: "invalid_input", message: "imageBytes is required and must be non-empty")
        }

        let changeRatio = entropyLikeScore(imageBytes)
        let label: String
        let confidence: Double
        if changeRatio < 0.10 {
          label = "edited"
          confidence = 0.85
        } else if changeRatio < 0.20 {
          label = "suspicious"
          confidence = 0.72
        } else {
          label = "real"
          confidence = 0.90
        }

        respond(result, payload: [
          "label": label,
          "confidence": confidence
        ])

      case "face.match":
        guard
          let args = call.arguments as? [String: Any],
          let selfieBytes = parseBytes(args["selfieBytes"]),
          let idBytes = parseBytes(args["idBytes"]),
          !selfieBytes.isEmpty,
          !idBytes.isEmpty
        else {
          return respondError(result, code: "invalid_input", message: "selfieBytes/idBytes are required and must be non-empty")
        }

        let similarity = min(max(cosineSimilarity(signature(selfieBytes), signature(idBytes)), 0.0), 1.0)
        respond(result, payload: [
          "similarity": similarity,
          "passed": similarity >= 0.78
        ])

      default:
        respondError(result, code: "unsupported", message: "Unsupported method: \(call.method)")
      }
    } catch {
      respondError(result, code: "inference_failed", message: error.localizedDescription)
    }
  }

  private func respond(_ result: @escaping FlutterResult, payload: [String: Any]) {
    DispatchQueue.main.async {
      result(payload)
    }
  }

  private func respondError(_ result: @escaping FlutterResult, code: String, message: String) {
    DispatchQueue.main.async {
      result(FlutterError(code: code, message: message, details: nil))
    }
  }

  private func parseBytes(_ raw: Any?) -> [UInt8]? {
    if let data = raw as? FlutterStandardTypedData {
      return [UInt8](data.data)
    }
    if let values = raw as? [NSNumber] {
      return values.map { UInt8(truncating: $0) }
    }
    return nil
  }

  private func entropyLikeScore(_ bytes: [UInt8]) -> Double {
    if bytes.count < 2 {
      return 0.0
    }
    var changes = 0
    for idx in 1..<bytes.count {
      if bytes[idx] != bytes[idx - 1] {
        changes += 1
      }
    }
    return Double(changes) / Double(bytes.count - 1)
  }

  private func signature(_ bytes: [UInt8]) -> [Double] {
    let bins = 16
    var hist = Array(repeating: 0.0, count: bins)
    if bytes.isEmpty {
      return hist
    }

    for value in bytes {
      let bucket = min((Int(value) * bins) / 256, bins - 1)
      hist[bucket] += 1.0
    }

    let norm = sqrt(hist.reduce(0.0) { $0 + $1 * $1 })
    if norm == 0.0 {
      return hist
    }

    return hist.map { $0 / norm }
  }

  private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    if a.count != b.count || a.isEmpty {
      return 0.0
    }
    var dot = 0.0
    var na = 0.0
    var nb = 0.0

    for idx in 0..<a.count {
      dot += a[idx] * b[idx]
      na += a[idx] * a[idx]
      nb += b[idx] * b[idx]
    }

    if na == 0.0 || nb == 0.0 {
      return 0.0
    }

    return dot / (sqrt(na) * sqrt(nb))
  }
}
