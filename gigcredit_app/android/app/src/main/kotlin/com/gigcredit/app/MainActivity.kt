package com.gigcredit.app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val channelName = "gigcredit/ai_native"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                            "ready" to true,
                            "engineVersion" to "android-prototype-0.1.0",
                            "modelsLoaded" to true,
                        ),
                    )
                }

                "ocr.extractText" -> {
                    val bytes = parseBytes(call.argument<Any>("imageBytes"))
                        ?: return respondError(result, "invalid_input", "imageBytes is required")
                    if (bytes.isEmpty()) {
                        return respondError(result, "invalid_input", "imageBytes cannot be empty")
                    }

                    val confidence = (0.62 + (bytes.average() / 255.0) * 0.33).coerceIn(0.0, 1.0)
                    val response = mapOf(
                        "rawText" to "OCR extracted text block (android native prototype).",
                        "confidence" to confidence,
                    )
                    respondSuccess(result, response)
                }

                "authenticity.detect" -> {
                    val bytes = parseBytes(call.argument<Any>("imageBytes"))
                        ?: return respondError(result, "invalid_input", "imageBytes is required")
                    if (bytes.isEmpty()) {
                        return respondError(result, "invalid_input", "imageBytes cannot be empty")
                    }

                    val changeRatio = entropyLikeScore(bytes)
                    val label = when {
                        changeRatio < 0.10 -> "edited"
                        changeRatio < 0.20 -> "suspicious"
                        else -> "real"
                    }
                    val confidence = when (label) {
                        "real" -> 0.90
                        "suspicious" -> 0.72
                        else -> 0.85
                    }
                    respondSuccess(
                        result,
                        mapOf(
                            "label" to label,
                            "confidence" to confidence,
                        ),
                    )
                }

                "face.match" -> {
                    val selfieBytes = parseBytes(call.argument<Any>("selfieBytes"))
                        ?: return respondError(result, "invalid_input", "selfieBytes is required")
                    val idBytes = parseBytes(call.argument<Any>("idBytes"))
                        ?: return respondError(result, "invalid_input", "idBytes is required")

                    if (selfieBytes.isEmpty() || idBytes.isEmpty()) {
                        return respondError(result, "invalid_input", "selfieBytes/idBytes cannot be empty")
                    }

                    val similarity = cosineSimilarity(signature(selfieBytes), signature(idBytes)).coerceIn(0.0, 1.0)
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
        } catch (ex: Exception) {
            respondError(result, "inference_failed", ex.message ?: "Native handler error")
        }
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
        worker.shutdownNow()
        super.onDestroy()
    }
}
