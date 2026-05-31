package lv.edgarsfoto.efpic_live.raw.develop

import android.graphics.Bitmap
import lv.edgarsfoto.efpic_live.processing.ColorSpaces
import lv.edgarsfoto.efpic_live.processing.LinearImage
import java.io.ByteArrayOutputStream

/** Bitmap ↔ scene-linear RGB for develop engines. */
object DevelopBitmapUtils {

    fun linearFromBitmap(bitmap: Bitmap): LinearImage {
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

    fun bitmapFromLinear(linear: LinearImage): Bitmap {
        val w = linear.width
        val h = linear.height
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
        return bitmap
    }

    fun encodeJpegFromBitmap(bitmap: Bitmap, quality: Int): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(70, 98), stream)
        return stream.toByteArray()
    }

    fun encodeJpeg(linear: LinearImage, w: Int, h: Int, quality: Int): ByteArray {
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
}
