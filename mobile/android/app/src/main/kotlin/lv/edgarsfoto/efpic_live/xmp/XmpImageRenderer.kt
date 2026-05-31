package lv.edgarsfoto.efpic_live.xmp

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import lv.edgarsfoto.efpic_live.processing.LightroomRenderPipeline
import lv.edgarsfoto.efpic_live.processing.LinearImage
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max

/**
 * Applies [LightroomPreset] from an `.xmp` file to JPEG images via [LightroomRenderPipeline].
 */
object XmpImageRenderer {

    private val contextCache = ConcurrentHashMap<String, LightroomRenderPipeline.RenderContext>()

    @JvmStatic
    fun invalidateCache(xmpPath: String? = null) {
        if (xmpPath == null) contextCache.clear()
        else contextCache.remove(xmpPath)
    }

    @JvmStatic
    fun renderContext(xmpPath: String): LightroomRenderPipeline.RenderContext =
        contextCache.getOrPut(xmpPath) {
            val preset = XmpParser.parse(File(xmpPath).inputStream())
            LightroomRenderPipeline.createContext(preset)
        }

    /** Full-resolution render → JPEG file. */
    @JvmStatic
    fun applyXmpToFile(
        xmpPath: String,
        sourcePath: String,
        destPath: String,
        jpegQuality: Int = 92,
    ): Boolean {
        val bitmap = BitmapFactory.decodeFile(sourcePath) ?: return false
        return try {
            val rendered = renderBitmap(bitmap, xmpPath)
            writeJpeg(rendered, destPath, jpegQuality)
            true
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    /** Downscaled preview → JPEG bytes (for Flutter UI). */
    @JvmStatic
    fun renderPreviewJpeg(
        xmpPath: String,
        sourcePath: String,
        maxLongEdge: Int = 1400,
        jpegQuality: Int = 88,
    ): ByteArray? {
        var bitmap = BitmapFactory.decodeFile(sourcePath) ?: return null
        try {
            bitmap = scaleToMaxLongEdge(bitmap, maxLongEdge)
            val rendered = renderBitmap(bitmap, xmpPath)
            val stream = java.io.ByteArrayOutputStream()
            rendered.compress(Bitmap.CompressFormat.JPEG, jpegQuality, stream)
            if (rendered !== bitmap && !rendered.isRecycled) rendered.recycle()
            return stream.toByteArray()
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    @JvmStatic
    fun extractDisplayName(xmpPath: String): String {
        val file = File(xmpPath)
        if (!file.exists()) return file.nameWithoutExtension
        return try {
            val text = file.readText()
            listOf(
                """dc:title="([^"]+)"""",
                """xmp:Label="([^"]+)"""",
                """crs:Name="([^"]+)"""",
            ).firstNotNullOfOrNull { pattern ->
                Regex(pattern).find(text)?.groupValues?.getOrNull(1)?.trim()
            } ?: file.nameWithoutExtension
        } catch (_: Exception) {
            file.nameWithoutExtension
        }
    }

    private fun renderBitmap(bitmap: Bitmap, xmpPath: String): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        val rgb = bitmapToRgb(bitmap)
        val linear = LinearImage.fromSrgbBytes(rgb, w, h)
        val ctx = renderContext(xmpPath)
        LightroomRenderPipeline.render(linear, ctx, parallel = true)
        val outRgb = LinearImage.toSrgbBytes(linear)
        return rgbToBitmap(outRgb, w, h)
    }

    private fun scaleToMaxLongEdge(bitmap: Bitmap, maxLongEdge: Int): Bitmap {
        if (maxLongEdge <= 0) return bitmap
        val long = max(bitmap.width, bitmap.height)
        if (long <= maxLongEdge) return bitmap
        val scale = maxLongEdge.toFloat() / long
        val nw = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val nh = (bitmap.height * scale).toInt().coerceAtLeast(1)
        val scaled = Bitmap.createScaledBitmap(bitmap, nw, nh, true)
        if (scaled !== bitmap && !bitmap.isRecycled) bitmap.recycle()
        return scaled
    }

    private fun bitmapToRgb(bitmap: Bitmap): ByteArray {
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        val rgb = ByteArray(w * h * 3)
        var j = 0
        for (px in pixels) {
            rgb[j++] = ((px shr 16) and 0xFF).toByte()
            rgb[j++] = ((px shr 8) and 0xFF).toByte()
            rgb[j++] = (px and 0xFF).toByte()
        }
        return rgb
    }

    private fun rgbToBitmap(rgb: ByteArray, w: Int, h: Int): Bitmap {
        val pixels = IntArray(w * h)
        var j = 0
        for (i in pixels.indices) {
            val r = rgb[j++].toInt() and 0xFF
            val g = rgb[j++].toInt() and 0xFF
            val b = rgb[j++].toInt() and 0xFF
            pixels[i] = -0x1000000 or (r shl 16) or (g shl 8) or b
        }
        return Bitmap.createBitmap(pixels, w, h, Bitmap.Config.ARGB_8888)
    }

    private fun writeJpeg(bitmap: Bitmap, destPath: String, quality: Int) {
        val file = File(destPath)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
        }
        if (!bitmap.isRecycled) bitmap.recycle()
    }
}
