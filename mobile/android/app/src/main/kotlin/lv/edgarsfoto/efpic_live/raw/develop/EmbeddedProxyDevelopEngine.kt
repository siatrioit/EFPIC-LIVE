package lv.edgarsfoto.efpic_live.raw.develop

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import lv.edgarsfoto.efpic_live.processing.ColorSpaces
import lv.edgarsfoto.efpic_live.processing.LinearImage
import lv.edgarsfoto.efpic_live.raw.EditSessionState
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Fāze 1: develop from extracted embedded JPEG (same pixels for preview and export).
 * Replaced by [LibRawDevelopEngine] when NDK demosaic is available.
 */
class EmbeddedProxyDevelopEngine : RawDevelopEngine {

    override fun develop(
        session: EditSessionState,
        maxLongEdge: Int,
        jpegQuality: Int,
    ): RawDevelopEngine.DevelopResult {
        val path = session.previewPath
        val file = File(path)
        if (!file.exists()) {
            throw IllegalStateException("Preview file missing: $path")
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var w = bounds.outWidth
        var h = bounds.outHeight
        if (w <= 0 || h <= 0) {
            throw IllegalStateException("Cannot decode: $path")
        }

        val sample = if (maxLongEdge > 0) {
            val long = max(w, h)
            var s = 1
            while (long / s > maxLongEdge * 1.2) s *= 2
            s
        } else {
            1
        }

        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = BitmapFactory.decodeFile(path, opts)
            ?: throw IllegalStateException("Bitmap decode failed: $path")

        val linear = linearFromBitmap(bitmap)

        w = linear.width
        h = linear.height

        EditDevelopPipeline.apply(linear, session, useEmbeddedProxyMode = true)

        val jpeg = encodeJpeg(linear, w, h, jpegQuality)
        Log.d(
            TAG,
            "develop proxy ${session.rawPath} ${w}x$h sample=$sample q=$jpegQuality",
        )
        return RawDevelopEngine.DevelopResult(
            jpegBytes = jpeg,
            width = w,
            height = h,
            sourceLabel = "embedded_jpeg_proxy",
        )
    }

    private fun linearFromBitmap(bitmap: Bitmap): LinearImage {
        val w = bitmap.width
        val h = bitmap.height
        val out = LinearImage(w, h)
        val px = out.pixels
        val row = IntArray(w)
        var di = 0
        for (y in 0 until h) {
            bitmap.getPixels(row, 0, w, 0, y, w, 1)
            for (x in 0 until w) {
                val c = row[x]
                px[di] = ColorSpaces.srgbByteToLinear((c shr 16) and 0xFF)
                px[di + 1] = ColorSpaces.srgbByteToLinear((c shr 8) and 0xFF)
                px[di + 2] = ColorSpaces.srgbByteToLinear(c and 0xFF)
                di += 3
            }
        }
        bitmap.recycle()
        return out
    }

    private fun encodeJpeg(linear: LinearImage, w: Int, h: Int, quality: Int): ByteArray {
        val rgb = LinearImage.toSrgbBytes(linear)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val row = IntArray(w)
        var si = 0
        for (y in 0 until h) {
            for (x in 0 until w) {
                val r = rgb[si].toInt() and 0xFF
                val g = rgb[si + 1].toInt() and 0xFF
                val b = rgb[si + 2].toInt() and 0xFF
                row[x] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
                si += 3
            }
            bitmap.setPixels(row, 0, w, 0, y, w, 1)
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(70, 98), stream)
        bitmap.recycle()
        return stream.toByteArray()
    }

    companion object {
        private const val TAG = "EmbeddedProxyDevelop"
    }
}
