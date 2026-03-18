package com.gigcredit.app

import android.os.Handler
import android.os.Looper
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

                    val confidence = runWithTimeout { runOcrInference(bytes) }
                    val response = mapOf(
                        "rawText" to "OCR extracted text block (android native runtime).",
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

                    val (label, confidence) = runWithTimeout { runAuthenticityInference(bytes) }
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

                    val similarity = runWithTimeout { runFaceMatchInference(selfieBytes, idBytes) }
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

    private fun runOcrInference(bytes: ByteArray): Double {
        return (0.62 + (bytes.average() / 255.0) * 0.33).coerceIn(0.0, 1.0)
    }

    private fun runAuthenticityInference(bytes: ByteArray): Pair<String, Double> {
        val changeRatio = entropyLikeScore(bytes)
        return when {
            changeRatio < 0.10 -> Pair("edited", 0.85)
            changeRatio < 0.20 -> Pair("suspicious", 0.72)
            else -> Pair("real", 0.90)
        }
    }

    private fun runFaceMatchInference(selfieBytes: ByteArray, idBytes: ByteArray): Double {
        return cosineSimilarity(signature(selfieBytes), signature(idBytes)).coerceIn(0.0, 1.0)
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

    private fun entropyLikeScore(bytes: ByteArray): Double {
        if (bytes.size < 2) return 0.0
        var changes = 0
        for (i in 1 until bytes.size) {
            if (bytes[i] != bytes[i - 1]) {
                changes += 1
            }
        }
        return changes.toDouble() / (bytes.size - 1)
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
