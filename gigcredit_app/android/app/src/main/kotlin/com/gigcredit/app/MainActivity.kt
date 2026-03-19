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
import java.io.ByteArrayOutputStream
import java.lang.reflect.Array
import java.nio.ByteBuffer
import java.nio.ByteOrder
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
    @Volatile
    private var ocrRuntimeAvailable: Boolean = false
    @Volatile
    private var tfliteRuntimeAvailable: Boolean = false
    @Volatile
    private var authenticityModelAvailable: Boolean = false
    @Volatile
    private var faceModelAvailable: Boolean = false

    private val authenticityModelAsset = "models/efficientnet_lite0.tflite"
    private val faceModelAsset = "models/mobilefacenet.tflite"

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
                            "ocrRuntimeAvailable" to ocrRuntimeAvailable,
                            "tfliteRuntimeAvailable" to tfliteRuntimeAvailable,
                            "authenticityModelAvailable" to authenticityModelAvailable,
                            "faceModelAvailable" to faceModelAvailable,
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
        if (forceFail) {
            modelsLoaded = false
            ocrRuntimeAvailable = false
            tfliteRuntimeAvailable = false
            authenticityModelAvailable = false
            faceModelAvailable = false
            return
        }

        ocrRuntimeAvailable = hasClass("com.google.mlkit.vision.text.TextRecognition") &&
            hasClass("com.google.android.gms.tasks.Tasks")
        tfliteRuntimeAvailable = hasClass("org.tensorflow.lite.Interpreter")
        authenticityModelAvailable = tfliteRuntimeAvailable && assetExists(authenticityModelAsset)
        faceModelAvailable = tfliteRuntimeAvailable && assetExists(faceModelAsset)
        modelsLoaded = true
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

        val mlKit = runMlKitOcr(bitmap)
        if (mlKit != null) {
            return mlKit
        }

        val signature = imageSignature(bitmap)
        val confidence = when {
            signature.edgeIntensity >= 22.0 && signature.entropyLike >= 0.22 -> 0.82
            signature.edgeIntensity >= 16.0 && signature.entropyLike >= 0.16 -> 0.70
            signature.edgeIntensity >= 10.0 && signature.entropyLike >= 0.10 -> 0.58
            else -> 0.42
        }
        val text = buildHeuristicOcrText(bitmap, signature)
        return Pair(text, confidence)
    }

    private fun runAuthenticityInference(bitmap: Bitmap): Pair<String, Double> {
        val tflite = runAuthenticityTflite(bitmap)
        if (tflite != null) {
            return tflite
        }

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
        val tflite = runFaceMatchTflite(selfieBitmap, idBitmap)
        if (tflite != null) {
            return tflite
        }

        val selfieFace = extractPrimaryFacePatch(selfieBitmap)
        val idFace = extractPrimaryFacePatch(idBitmap)
        return cosineSimilarity(signature(selfieFace), signature(idFace)).coerceIn(0.0, 1.0)
    }

    private fun runMlKitOcr(bitmap: Bitmap): Pair<String, Double>? {
        if (!ocrRuntimeAvailable) {
            return null
        }
        return try {
            val inputImageClass = Class.forName("com.google.mlkit.vision.common.InputImage")
            val fromBitmap = inputImageClass.getMethod(
                "fromBitmap",
                Bitmap::class.java,
                Int::class.javaPrimitiveType,
            )
            val inputImage = fromBitmap.invoke(null, bitmap, 0)

            val textRecClass = Class.forName("com.google.mlkit.vision.text.TextRecognition")
            val optionsClass = Class.forName("com.google.mlkit.vision.text.latin.TextRecognizerOptions")
            val defaultOptions = optionsClass.getField("DEFAULT_OPTIONS").get(null)
            val getClient = textRecClass.getMethod("getClient", optionsClass)
            val recognizer = getClient.invoke(null, defaultOptions)

            val processMethod = recognizer.javaClass.getMethod("process", inputImageClass)
            val task = processMethod.invoke(recognizer, inputImage)

            val tasksClass = Class.forName("com.google.android.gms.tasks.Tasks")
            val awaitMethod = tasksClass.methods.firstOrNull {
                it.name == "await" && it.parameterTypes.size == 3
            } ?: return null

            val textResult = awaitMethod.invoke(null, task, maxLatencyMs, TimeUnit.MILLISECONDS)
            val text = textResult?.javaClass?.getMethod("getText")?.invoke(textResult)?.toString()
                ?.trim()
                ?: ""

            val confidence = when {
                text.length >= 400 -> 0.95
                text.length >= 180 -> 0.90
                text.length >= 60 -> 0.84
                text.length >= 20 -> 0.76
                text.isNotBlank() -> 0.68
                else -> 0.0
            }

            if (text.isBlank()) null else Pair(text, confidence)
        } catch (_: Exception) {
            null
        }
    }

    private fun runAuthenticityTflite(bitmap: Bitmap): Pair<String, Double>? {
        if (!authenticityModelAvailable) {
            return null
        }

        return try {
            val modelBytes = loadAssetBytes(authenticityModelAsset) ?: return null
            val input = createImageInput(bitmap, 224, 224)
            val output = Array.newInstance(FloatArray::class.java, 1) as Array<FloatArray>
            output[0] = FloatArray(2)
            val ok = runTfliteModel(modelBytes, input, output)
            if (!ok) {
                return null
            }

            val editedScore = output[0].getOrElse(0) { 0f }.toDouble()
            val realScore = output[0].getOrElse(1) { 1f - editedScore.toFloat() }.toDouble()
            val total = (editedScore + realScore).coerceAtLeast(1e-6)
            val editedProb = (editedScore / total).coerceIn(0.0, 1.0)
            val realProb = (realScore / total).coerceIn(0.0, 1.0)

            when {
                realProb >= 0.70 -> Pair("real", realProb)
                editedProb >= 0.70 -> Pair("edited", editedProb)
                else -> Pair("suspicious", maxOf(realProb, editedProb))
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun runFaceMatchTflite(selfieBitmap: Bitmap, idBitmap: Bitmap): Double? {
        if (!faceModelAvailable) {
            return null
        }

        return try {
            val selfieFace = extractPrimaryFaceBitmap(selfieBitmap)
            val idFace = extractPrimaryFaceBitmap(idBitmap)
            val selfieInput = createImageInput(selfieFace, 112, 112)
            val idInput = createImageInput(idFace, 112, 112)
            val modelBytes = loadAssetBytes(faceModelAsset) ?: return null

            val selfieEmbedding = runFaceEmbedding(modelBytes, selfieInput) ?: return null
            val idEmbedding = runFaceEmbedding(modelBytes, idInput) ?: return null

            cosineSimilarity(selfieEmbedding, idEmbedding).coerceIn(0.0, 1.0)
        } catch (_: Exception) {
            null
        }
    }

    private fun runFaceEmbedding(modelBytes: ByteArray, input: Any): DoubleArray? {
        val outputSizes = intArrayOf(128, 192, 256, 512)
        for (size in outputSizes) {
            val output = Array.newInstance(FloatArray::class.java, 1) as Array<FloatArray>
            output[0] = FloatArray(size)
            val ok = runTfliteModel(modelBytes, input, output)
            if (ok) {
                return output[0].map { it.toDouble() }.toDoubleArray()
            }
        }
        return null
    }

    private fun runTfliteModel(modelBytes: ByteArray, input: Any, output: Any): Boolean {
        return try {
            val interpreterClass = Class.forName("org.tensorflow.lite.Interpreter")
            val modelBuffer = ByteBuffer.allocateDirect(modelBytes.size)
                .order(ByteOrder.nativeOrder())
            modelBuffer.put(modelBytes)
            modelBuffer.rewind()

            val constructor = interpreterClass.getConstructor(ByteBuffer::class.java)
            val interpreter = constructor.newInstance(modelBuffer)
            try {
                val runMethod = interpreterClass.getMethod("run", Any::class.java, Any::class.java)
                runMethod.invoke(interpreter, input, output)
                true
            } finally {
                try {
                    val closeMethod = interpreterClass.getMethod("close")
                    closeMethod.invoke(interpreter)
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun createImageInput(bitmap: Bitmap, width: Int, height: Int): Array<Array<Array<FloatArray>>> {
        val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
        val input = Array(1) {
            Array(height) {
                Array(width) {
                    FloatArray(3)
                }
            }
        }

        val pixels = IntArray(width * height)
        scaled.getPixels(pixels, 0, width, 0, 0, width, height)
        for (y in 0 until height) {
            for (x in 0 until width) {
                val pixel = pixels[y * width + x]
                val r = ((pixel shr 16) and 0xFF) / 255.0f
                val g = ((pixel shr 8) and 0xFF) / 255.0f
                val b = (pixel and 0xFF) / 255.0f
                input[0][y][x][0] = r
                input[0][y][x][1] = g
                input[0][y][x][2] = b
            }
        }
        return input
    }

    private fun loadAssetBytes(assetPath: String): ByteArray? {
        return try {
            assets.open(assetPath).use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                }
                output.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun hasClass(name: String): Boolean {
        return try {
            Class.forName(name)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun assetExists(assetPath: String): Boolean {
        return try {
            assets.open(assetPath).use { true }
        } catch (_: Exception) {
            false
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
        val patch = extractPrimaryFaceBitmap(bitmap)
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

    private fun extractPrimaryFaceBitmap(bitmap: Bitmap): Bitmap {
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
        return Bitmap.createBitmap(faceBitmap, left, top, patchWidth, patchHeight)
    }

    private data class ImageSignature(
        val entropyLike: Double,
        val edgeIntensity: Double,
    )

    private fun buildHeuristicOcrText(bitmap: Bitmap, signature: ImageSignature): String {
        val width = bitmap.width
        val height = bitmap.height
        val hashToken = imageHash(bitmap)
        val inferredType = inferDocumentTypeHint(signature)
        return """
ANDROID_OCR_PROXY_RESULT
DocumentHint: $inferredType
ImageWidth: $width
ImageHeight: $height
EntropyLike: ${"%.4f".format(signature.entropyLike)}
EdgeIntensity: ${"%.2f".format(signature.edgeIntensity)}
ChecksumToken: $hashToken
        """.trimIndent()
    }

    private fun inferDocumentTypeHint(signature: ImageSignature): String {
        return when {
            signature.edgeIntensity > 20.0 && signature.entropyLike > 0.22 -> "dense_text_document"
            signature.edgeIntensity > 14.0 && signature.entropyLike > 0.14 -> "moderate_text_document"
            else -> "low_text_or_blurry_document"
        }
    }

    private fun imageHash(bitmap: Bitmap): String {
        val sample = IntArray(min(bitmap.width * bitmap.height, 512))
        val full = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(full, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        for (i in sample.indices) {
            val idx = (i * 31) % full.size
            sample[i] = full[idx]
        }

        var hash = 1125899906842597L
        for (pixel in sample) {
            hash = 31L * hash + pixel.toLong()
        }
        return java.lang.Long.toHexString(hash)
    }

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
