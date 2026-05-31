package lv.edgarsfoto.efpic_live.raw.develop

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import lv.edgarsfoto.efpic_live.processing.LinearImage
import lv.edgarsfoto.efpic_live.raw.EditSessionState
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

        val linear = DevelopBitmapUtils.linearFromBitmap(bitmap)

        w = linear.width
        h = linear.height

        EditDevelopPipeline.apply(linear, session, useEmbeddedProxyMode = true)

        val jpeg = DevelopBitmapUtils.encodeJpeg(linear, w, h, jpegQuality)
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

    companion object {
        private const val TAG = "EmbeddedProxyDevelop"
    }
}
