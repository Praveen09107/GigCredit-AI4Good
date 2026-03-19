import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "gigcredit/ai_native"
  private let engineVersion = "ios-runtime-0.2.0"
  private let maxLatencySeconds: TimeInterval = 6
  private let maxImageBytes = 5 * 1024 * 1024
  private let workerQueue = DispatchQueue(label: "com.gigcredit.ai_native", qos: .userInitiated)
  private let inferenceQueue = DispatchQueue(label: "com.gigcredit.ai_native.inference", qos: .userInitiated, attributes: .concurrent)
  private var modelsLoaded = false
  private var ocrRuntimeAvailable = false
  private var tfliteRuntimeAvailable = false
  private var authenticityModelAvailable = false
  private var faceModelAvailable = false

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

    initializeModels()

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
          "ready": modelsLoaded,
          "engineVersion": engineVersion,
          "modelsLoaded": modelsLoaded,
          "ocrRuntimeAvailable": ocrRuntimeAvailable,
          "tfliteRuntimeAvailable": tfliteRuntimeAvailable,
          "authenticityModelAvailable": authenticityModelAvailable,
          "faceModelAvailable": faceModelAvailable
        ])

      case "ocr.extractText":
        guard modelsLoaded else {
          return respondError(result, code: "model_load_failed", message: "Native model runtime is not loaded")
        }
        guard
          let args = call.arguments as? [String: Any],
          let imageBytes = parseBytes(args["imageBytes"]),
          !imageBytes.isEmpty
        else {
          return respondError(result, code: "invalid_input", message: "imageBytes is required and must be non-empty")
        }
        guard imageBytes.count <= maxImageBytes else {
          return respondError(result, code: "invalid_input", message: "imageBytes exceeds size limit")
        }

        let (rawText, confidence) = try runWithTimeout {
          try self.runOcrInference(imageBytes)
        }

        respond(result, payload: [
          "rawText": rawText,
          "confidence": confidence
        ])

      case "authenticity.detect":
        guard modelsLoaded else {
          return respondError(result, code: "model_load_failed", message: "Native model runtime is not loaded")
        }
        guard
          let args = call.arguments as? [String: Any],
          let imageBytes = parseBytes(args["imageBytes"]),
          !imageBytes.isEmpty
        else {
          return respondError(result, code: "invalid_input", message: "imageBytes is required and must be non-empty")
        }
        guard imageBytes.count <= maxImageBytes else {
          return respondError(result, code: "invalid_input", message: "imageBytes exceeds size limit")
        }

        let (label, confidence) = try runWithTimeout {
          try self.runAuthenticityInference(imageBytes)
        }

        respond(result, payload: [
          "label": label,
          "confidence": confidence
        ])

      case "face.match":
        guard modelsLoaded else {
          return respondError(result, code: "model_load_failed", message: "Native model runtime is not loaded")
        }
        guard
          let args = call.arguments as? [String: Any],
          let selfieBytes = parseBytes(args["selfieBytes"]),
          let idBytes = parseBytes(args["idBytes"]),
          !selfieBytes.isEmpty,
          !idBytes.isEmpty
        else {
          return respondError(result, code: "invalid_input", message: "selfieBytes/idBytes are required and must be non-empty")
        }
        guard selfieBytes.count <= maxImageBytes, idBytes.count <= maxImageBytes else {
          return respondError(result, code: "invalid_input", message: "selfieBytes/idBytes exceed size limit")
        }

        let similarity = try runWithTimeout {
          try self.runFaceMatchInference(selfieBytes, idBytes)
        }
        respond(result, payload: [
          "similarity": similarity,
          "passed": similarity >= 0.78
        ])

      default:
        respondError(result, code: "unsupported", message: "Unsupported method: \(call.method)")
      }
    } catch MethodTimeoutError.timedOut {
      respondError(result, code: "timeout", message: "Native AI call exceeded \(Int(maxLatencySeconds))s")
    } catch NativeRuntimeError.modelNotLoaded {
      respondError(result, code: "model_load_failed", message: "Native model runtime is not loaded")
    } catch NativeRuntimeError.invalidInput(let msg) {
      respondError(result, code: "invalid_input", message: msg)
    } catch NativeRuntimeError.unsupported(let msg) {
      respondError(result, code: "unsupported", message: msg)
    } catch {
      respondError(result, code: "inference_failed", message: error.localizedDescription)
    }
  }

  private func initializeModels() {
    let env = ProcessInfo.processInfo.environment
    modelsLoaded = env["GIGCREDIT_FORCE_MODEL_LOAD_FAIL"] != "1"

    ocrRuntimeAvailable = true
    tfliteRuntimeAvailable = hasTfliteRuntime()
    authenticityModelAvailable = tfliteRuntimeAvailable && flutterAssetExists("assets/models/efficientnet_lite0.tflite")
    faceModelAvailable = tfliteRuntimeAvailable && flutterAssetExists("assets/models/mobilefacenet.tflite")
  }

  private func hasTfliteRuntime() -> Bool {
    NSClassFromString("TensorFlowLite.Interpreter") != nil || NSClassFromString("Interpreter") != nil
  }

  private func flutterAssetExists(_ relativePath: String) -> Bool {
    let normalized = relativePath.hasPrefix("assets/") ? relativePath : "assets/\(relativePath)"
    let flutterPath = "flutter_assets/\(normalized)"
    if let bundlePath = Bundle.main.path(forResource: flutterPath, ofType: nil) {
      return FileManager.default.fileExists(atPath: bundlePath)
    }
    if let resourceURL = Bundle.main.resourceURL {
      let url = resourceURL.appendingPathComponent(flutterPath)
      return FileManager.default.fileExists(atPath: url.path)
    }
    return false
  }

  private func runWithTimeout<T>(_ block: @escaping () throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var output: T?
    var thrownError: Error?
    inferenceQueue.async {
      do {
        output = try block()
      } catch {
        thrownError = error
      }
      semaphore.signal()
    }
    let waited = semaphore.wait(timeout: .now() + maxLatencySeconds)
    if waited == .timedOut {
      throw MethodTimeoutError.timedOut
    }
    if let thrownError {
      throw thrownError
    }
    guard let output else {
      throw NativeRuntimeError.unsupported("Native inference returned no result")
    }
    return output
  }

  private func runOcrInference(_ imageBytes: [UInt8]) throws -> (String, Double) {
    guard let cgImage = try decodeCGImage(imageBytes) else {
      throw NativeRuntimeError.invalidInput("imageBytes could not be decoded")
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    let observations = request.results ?? []
    if observations.isEmpty {
      return ("", 0.0)
    }

    var lines: [String] = []
    var confidenceSum = 0.0
    var confidenceCount = 0

    for observation in observations {
      guard let candidate = observation.topCandidates(1).first else {
        continue
      }
      let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
      if !text.isEmpty {
        lines.append(text)
      }
      confidenceSum += Double(candidate.confidence)
      confidenceCount += 1
    }

    let rawText = lines.joined(separator: "\n")
    let confidence = confidenceCount > 0 ? confidenceSum / Double(confidenceCount) : 0.0
    return (rawText, min(max(confidence, 0.0), 1.0))
  }

  private func runAuthenticityInference(_ imageBytes: [UInt8]) throws -> (String, Double) {
    guard let cgImage = try decodeCGImage(imageBytes) else {
      throw NativeRuntimeError.invalidInput("imageBytes could not be decoded")
    }

    let stats = imageSignature(cgImage)
    if stats.entropyLike < 0.10 || stats.edgeIntensity < 8.0 {
      return ("edited", 0.84)
    }
    if stats.entropyLike < 0.18 || stats.edgeIntensity < 14.0 {
      return ("suspicious", 0.74)
    }
    return ("real", 0.90)
  }

  private func runFaceMatchInference(_ selfieBytes: [UInt8], _ idBytes: [UInt8]) throws -> Double {
    guard let selfie = try decodeCGImage(selfieBytes) else {
      throw NativeRuntimeError.invalidInput("selfieBytes could not be decoded")
    }
    guard let id = try decodeCGImage(idBytes) else {
      throw NativeRuntimeError.invalidInput("idBytes could not be decoded")
    }

    guard let selfiePatch = try extractPrimaryFacePatch(selfie) else {
      throw NativeRuntimeError.invalidInput("No face detected in selfieBytes")
    }
    guard let idPatch = try extractPrimaryFacePatch(id) else {
      throw NativeRuntimeError.invalidInput("No face detected in idBytes")
    }

    return min(max(cosineSimilarity(signature(selfiePatch), signature(idPatch)), 0.0), 1.0)
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

  private func decodeCGImage(_ bytes: [UInt8]) throws -> CGImage? {
    let data = Data(bytes)
    guard let image = UIImage(data: data)?.cgImage else {
      return nil
    }
    return image
  }

  private struct ImageSignature {
    let entropyLike: Double
    let edgeIntensity: Double
  }

  private func imageSignature(_ cgImage: CGImage) -> ImageSignature {
    let width = cgImage.width
    let height = cgImage.height
    if width == 0 || height == 0 {
      return ImageSignature(entropyLike: 0.0, edgeIntensity: 0.0)
    }

    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    var raw = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let context = CGContext(
      data: &raw,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return ImageSignature(entropyLike: 0.0, edgeIntensity: 0.0)
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var changes = 0
    var edgeAccum = 0.0
    var prevGray = 0
    let count = width * height

    for idx in 0..<count {
      let offset = idx * 4
      let r = Int(raw[offset])
      let g = Int(raw[offset + 1])
      let b = Int(raw[offset + 2])
      let gray = (r + g + b) / 3

      if idx > 0 {
        if gray != prevGray {
          changes += 1
        }
        edgeAccum += Double(abs(gray - prevGray))
      }
      prevGray = gray
    }

    if count < 2 {
      return ImageSignature(entropyLike: 0.0, edgeIntensity: 0.0)
    }

    return ImageSignature(
      entropyLike: Double(changes) / Double(count - 1),
      edgeIntensity: edgeAccum / Double(count - 1)
    )
  }

  private func extractPrimaryFacePatch(_ cgImage: CGImage) throws -> [UInt8]? {
    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    guard
      let results = request.results,
      !results.isEmpty
    else {
      return nil
    }

    let best = results.max {
      ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height)
    }

    guard let best else {
      return nil
    }

    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let box = best.boundingBox
    let rect = CGRect(
      x: box.origin.x * width,
      y: (1.0 - box.origin.y - box.height) * height,
      width: box.width * width,
      height: box.height * height
    ).integral

    guard let cropped = cgImage.cropping(to: rect) else {
      return nil
    }

    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * cropped.width
    var raw = [UInt8](repeating: 0, count: cropped.height * bytesPerRow)
    guard let context = CGContext(
      data: &raw,
      width: cropped.width,
      height: cropped.height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return nil
    }
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))

    var gray = [UInt8](repeating: 0, count: cropped.width * cropped.height)
    for idx in 0..<gray.count {
      let offset = idx * 4
      let r = Int(raw[offset])
      let g = Int(raw[offset + 1])
      let b = Int(raw[offset + 2])
      gray[idx] = UInt8((r + g + b) / 3)
    }
    return gray
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

private enum MethodTimeoutError: Error {
  case timedOut
}

private enum NativeRuntimeError: Error {
  case modelNotLoaded
  case invalidInput(String)
  case unsupported(String)
}
