package com.gigcredit.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.PointF
import android.os.Handler
import android.os.Looper
import android.media.FaceDetector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Callable
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val channelName = "gigcredit/ai_native"
    private val engineVersion = "android-runtime-0.2.0"
    private val maxLatencyMs = 6000L
    private val maxImageBytes = 5 * 1024 * 1024
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val runtimeExecutor: ExecutorService = Executors.newFixedThreadPool(2)
    @Volatile
    private var modelsLoaded: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initializeModels()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                worker.execute {
                    handleMethod(call, result)
                }
            }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "ai.health" -> {
                    respondSuccess(
                        result,
                        mapOf(
                            "ready" to modelsLoaded,
                            "engineVersion" to engineVersion,
                            "modelsLoaded" to modelsLoaded,
                        ),
                    )
                }

                "ocr.extractText" -> {
                    if (!modelsLoaded) {
                        return respondError(result, "model_load_failed", "Native model runtime is not loaded")
                    }
                    val bytes = parseBytes(call.argument<Any>("imageBytes"))
                        ?: return respondError(result, "invalid_input", "imageBytes is required")
                    if (bytes.isEmpty()) {
                        return respondError(result, "invalid_input", "imageBytes cannot be empty")
                    }
                    if (bytes.size > maxImageBytes) {
                        return respondError(result, "invalid_input", "imageBytes exceeds size limit")
                    }

                    val (rawText, confidence) = runWithTimeout { runOcrInference(bytes) }
                    val response = mapOf(
                        "rawText" to rawText,
                        "confidence" to confidence,
                    )
                    respondSuccess(result, response)
                }

                "authenticity.detect" -> {
                    if (!modelsLoaded) {
                        return respondError(result, "model_load_failed", "Native model runtime is not loaded")
                    }
                    val bytes = parseBytes(call.argument<Any>("imageBytes"))
                        ?: return respondError(result, "invalid_input", "imageBytes is required")
                    if (bytes.isEmpty()) {
                        return respondError(result, "invalid_input", "imageBytes cannot be empty")
                    }
                    if (bytes.size > maxImageBytes) {
                        return respondError(result, "invalid_input", "imageBytes exceeds size limit")
                    }

                    val bitmap = decodeBitmap(bytes)
                        ?: return respondError(result, "invalid_input", "imageBytes could not be decoded")
                    val (label, confidence) = runWithTimeout { runAuthenticityInference(bitmap) }
                    respondSuccess(
                        result,
                        mapOf(
                            "label" to label,
                            "confidence" to confidence,
                        ),
                    )
                }

                "face.match" -> {
                    if (!modelsLoaded) {
                        return respondError(result, "model_load_failed", "Native model runtime is not loaded")
                    }
                    val selfieBytes = parseBytes(call.argument<Any>("selfieBytes"))
                        ?: return respondError(result, "invalid_input", "selfieBytes is required")
                    val idBytes = parseBytes(call.argument<Any>("idBytes"))
                        ?: return respondError(result, "invalid_input", "idBytes is required")

                    if (selfieBytes.isEmpty() || idBytes.isEmpty()) {
                        return respondError(result, "invalid_input", "selfieBytes/idBytes cannot be empty")
                    }
                    if (selfieBytes.size > maxImageBytes || idBytes.size > maxImageBytes) {
                        return respondError(result, "invalid_input", "selfieBytes/idBytes exceed size limit")
                    }

                    val selfieBitmap = decodeBitmap(selfieBytes)
                        ?: return respondError(result, "invalid_input", "selfieBytes could not be decoded")
                    val idBitmap = decodeBitmap(idBytes)
                        ?: return respondError(result, "invalid_input", "idBytes could not be decoded")

                    val similarity = runWithTimeout { runFaceMatchInference(selfieBitmap, idBitmap) }
                    respondSuccess(
                        result,
                        mapOf(
                            "similarity" to similarity,
                            "passed" to (similarity >= 0.78),
                        ),
                    )
                }

                else -> respondError(result, "unsupported", "Unsupported method: ${call.method}")
            }
        } catch (ex: UnsupportedOperationException) {
            respondError(result, "unsupported", ex.message ?: "Unsupported runtime feature")
        } catch (ex: IllegalArgumentException) {
            respondError(result, "invalid_input", ex.message ?: "Invalid input")
        } catch (ex: TimeoutException) {
            respondError(result, "timeout", "Native AI call exceeded ${maxLatencyMs}ms")
        } catch (ex: Exception) {
            respondError(result, "inference_failed", ex.message ?: "Native handler error")
        }
    }

    private fun initializeModels() {
        val forceFail = System.getenv("GIGCREDIT_FORCE_MODEL_LOAD_FAIL") == "1"
        modelsLoaded = !forceFail
    }

    private fun <T> runWithTimeout(block: () -> T): T {
        val future = runtimeExecutor.submit(Callable { block() })
        return future.get(maxLatencyMs, TimeUnit.MILLISECONDS)
    }

    private fun runOcrInference(bytes: ByteArray): Pair<String, Double> {
        val bitmap = decodeBitmap(bytes)
            ?: throw IllegalArgumentException("imageBytes could not be decoded")
        if (bitmap.width < 16 || bitmap.height < 16) {
            throw IllegalArgumentException("imageBytes resolution too small for OCR")
        }
        throw UnsupportedOperationException("Android OCR runtime not linked; enable Dart fallback or integrate ML Kit OCR")
    }

    private fun runAuthenticityInference(bitmap: Bitmap): Pair<String, Double> {
        val signature = imageSignature(bitmap)
        val entropy = signature.entropyLike
        val edge = signature.edgeIntensity

        return when {
            entropy < 0.10 || edge < 8.0 -> Pair("edited", 0.84)
            entropy < 0.18 || edge < 14.0 -> Pair("suspicious", 0.74)
            else -> Pair("real", 0.90)
        }
    }

    private fun runFaceMatchInference(selfieBitmap: Bitmap, idBitmap: Bitmap): Double {
        val selfieFace = extractPrimaryFacePatch(selfieBitmap)
        val idFace = extractPrimaryFacePatch(idBitmap)
        return cosineSimilarity(signature(selfieFace), signature(idFace)).coerceIn(0.0, 1.0)
    }

    private fun respondSuccess(result: MethodChannel.Result, payload: Map<String, Any>) {
        mainHandler.post { result.success(payload) }
    }

    private fun respondError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    private fun parseBytes(raw: Any?): ByteArray? {
        return when (raw) {
            is ByteArray -> raw
            is List<*> -> {
                val values = raw.mapNotNull { (it as? Number)?.toInt() }
                if (values.size != raw.size) return null
                ByteArray(values.size) { idx -> values[idx].toByte() }
            }
            else -> null
        }
    }

    private fun decodeBitmap(bytes: ByteArray): Bitmap? {
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun toFaceBitmap(source: Bitmap): Bitmap {
        if (source.config == Bitmap.Config.RGB_565) {
            return source
        }
        return source.copy(Bitmap.Config.RGB_565, true)
    }

    private fun extractPrimaryFacePatch(bitmap: Bitmap): ByteArray {
        val faceBitmap = toFaceBitmap(bitmap)
        if (faceBitmap.width < 32 || faceBitmap.height < 32) {
            throw IllegalArgumentException("Image too small for face detection")
        }

        val faces = arrayOfNulls<FaceDetector.Face>(1)
        val found = FaceDetector(faceBitmap.width, faceBitmap.height, 1).findFaces(faceBitmap, faces)
        if (found < 1 || faces[0] == null) {
            throw IllegalArgumentException("No face detected")
        }

        val face = faces[0]!!
        val mid = PointF()
        face.getMidPoint(mid)
        val radius = (face.eyesDistance() * 1.7f).coerceAtLeast(12f)

        val left = (mid.x - radius).toInt().coerceIn(0, faceBitmap.width - 1)
        val top = (mid.y - radius).toInt().coerceIn(0, faceBitmap.height - 1)
        val right = (mid.x + radius).toInt().coerceIn(left + 1, faceBitmap.width)
        val bottom = (mid.y + radius).toInt().coerceIn(top + 1, faceBitmap.height)

        val patchWidth = (right - left).coerceAtLeast(1)
        val patchHeight = (bottom - top).coerceAtLeast(1)
        val patch = Bitmap.createBitmap(faceBitmap, left, top, patchWidth, patchHeight)

        val pixels = IntArray(patch.width * patch.height)
        patch.getPixels(pixels, 0, patch.width, 0, 0, patch.width, patch.height)
        return ByteArray(pixels.size) { idx ->
            val p = pixels[idx]
            val r = (p shr 16) and 0xFF
            val g = (p shr 8) and 0xFF
            val b = p and 0xFF
            (((r + g + b) / 3) and 0xFF).toByte()
        }
    }

    private data class ImageSignature(
        val entropyLike: Double,
        val edgeIntensity: Double,
    )

    private fun imageSignature(bitmap: Bitmap): ImageSignature {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        if (pixels.size < 2) {
            return ImageSignature(entropyLike = 0.0, edgeIntensity = 0.0)
        }

        var changes = 0
        var edgeAccum = 0.0
        var prevGray = 0

        for (idx in pixels.indices) {
            val p = pixels[idx]
            val r = (p shr 16) and 0xFF
            val g = (p shr 8) and 0xFF
            val b = p and 0xFF
            val gray = (r + g + b) / 3

            if (idx > 0) {
                if (gray != prevGray) {
                    changes += 1
                }
                edgeAccum += kotlin.math.abs(gray - prevGray).toDouble()
            }
            prevGray = gray
        }

        val entropyLike = changes.toDouble() / (pixels.size - 1)
        val edgeIntensity = edgeAccum / (pixels.size - 1)
        return ImageSignature(entropyLike = entropyLike, edgeIntensity = edgeIntensity)
    }

    private fun signature(bytes: ByteArray): DoubleArray {
        val bins = 16
        val hist = DoubleArray(bins)
        if (bytes.isEmpty()) return hist

        for (value in bytes) {
            val unsigned = value.toInt() and 0xFF
            val bucket = min((unsigned * bins) / 256, bins - 1)
            hist[bucket] += 1.0
        }

        var norm = 0.0
        for (v in hist) {
            norm += v * v
        }
        norm = kotlin.math.sqrt(norm)
        if (norm == 0.0) return hist

        for (i in hist.indices) {
            hist[i] = hist[i] / norm
        }
        return hist
    }

    private fun cosineSimilarity(a: DoubleArray, b: DoubleArray): Double {
        var dot = 0.0
        var na = 0.0
        var nb = 0.0
        for (i in a.indices) {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        if (na == 0.0 || nb == 0.0) return 0.0
        return dot / (kotlin.math.sqrt(na) * kotlin.math.sqrt(nb))
    }

    override fun onDestroy() {
        runtimeExecutor.shutdownNow()
        worker.shutdownNow()
        super.onDestroy()
    }
}
