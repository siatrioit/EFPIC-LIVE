package lv.edgarsfoto.efpic_live.raw

import android.util.Log
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.pow

/**
 * Extracts "As Shot" camera settings from RAW files (Nikon NEF focus, Z8 tested patterns).
 * Runs off the UI thread — call from [RawEditSessionManager].
 */
object RawCameraBaselineExtractor {
    private const val TAG = "RawCameraBaseline"
    private const val MAX_READ = 32 * 1024 * 1024

    fun extract(rawPath: String): CameraBaseline {
        val file = File(rawPath)
        if (!file.exists()) {
            Log.w(TAG, "RAW missing: $rawPath")
            return CameraBaseline()
        }

        val sources = mutableListOf<String>()
        var exposureEv = 0f
        var kelvin = 6500f
        var tint = 0f
        var rGain = 1f
        var gGain = 1f
        var bGain = 1f
        var contrast = 0f
        var shadows = 0f
        var sharpness = 0f
        var cameraModel: String? = null
        var rawW = 0
        var rawH = 0
        var colorSpace = CameraBaseline.ColorSpace.SRGB
        var pictureControl: String? = null

        // --- 1) Android ExifInterface (fast path on many NEF/CR2) -----------------
        try {
            val exif = ExifInterface(rawPath)
            cameraModel = exif.getAttribute(ExifInterface.TAG_MODEL)

            parseExposureBias(exif.getAttribute(ExifInterface.TAG_EXPOSURE_BIAS_VALUE))?.let {
                exposureEv = it
                sources.add("exif:ExposureBiasValue")
            }

            exif.getAttribute(ExifInterface.TAG_COLOR_SPACE)?.let { cs ->
                colorSpace = when {
                    cs.contains("65535", ignoreCase = true) ||
                        cs.contains("Uncalibrated", ignoreCase = true) ->
                        CameraBaseline.ColorSpace.ADOBE_RGB
                    else -> CameraBaseline.ColorSpace.SRGB
                }
                sources.add("exif:ColorSpace")
            }

            val w = exif.getAttribute(ExifInterface.TAG_IMAGE_WIDTH)
            val h = exif.getAttribute(ExifInterface.TAG_IMAGE_LENGTH)
            rawW = w?.toIntOrNull() ?: 0
            rawH = h?.toIntOrNull() ?: 0
            if (rawW > 0 && rawH > 0) sources.add("exif:ImageDimensions")
        } catch (e: Exception) {
            Log.d(TAG, "ExifInterface partial: ${e.message}")
        }

        // --- 2) Binary TIFF / Nikon MakerNote ------------------------------------
        val bytes = readHead(file)
        if (bytes.isNotEmpty()) {
            val exifOff = findExifTiffOffset(bytes)
            if (exifOff >= 0) {
                val tiff = TiffReader(bytes, exifOff)
                if (tiff.valid) {
                    if (!sources.contains("exif:ExposureBiasValue")) {
                        tiff.sRationalExif(0x9204)?.let {
                            exposureEv = it.coerceIn(-5f, 5f)
                            sources.add("tiff:ExposureBiasValue")
                        }
                    }

                    tiff.uint16Exif(0x9214)?.let { k ->
                        if (k in 2000..50000) {
                            kelvin = k.toFloat()
                            sources.add("tiff:ColorTemperature")
                        }
                    }

                    if (rawW <= 0) {
                        tiff.uint16Exif(0xa002)?.let { rawW = it; sources.add("tiff:ExifImageWidth") }
                        tiff.uint16Exif(0xa003)?.let { rawH = it; sources.add("tiff:ExifImageLength") }
                    }

                    tiff.byteBlockExif(0x927c)?.let { maker ->
                        val nikon = NikonMakerNoteParser.parse(maker)
                        nikon.kelvin?.let {
                            kelvin = it
                            sources.add("nikon:ColorBalance|ColorTemperature")
                        }
                        nikon.tint?.let {
                            tint = it
                            sources.add("nikon:WhiteBalanceFineTune")
                        }
                        nikon.redGain?.let { rGain = it }
                        nikon.greenGain?.let { gGain = it }
                        nikon.blueGain?.let { bGain = it }
                        if (nikon.redGain != null) sources.add("nikon:WbMultipliers")

                        nikon.pictureControl?.let { pc ->
                            pictureControl = pc.name
                            contrast = pc.contrast
                            shadows = pc.shadows
                            sharpness = pc.sharpness
                            sources.add("nikon:PictureControl(0x0023)")
                        }
                    }
                }
            }
        }

        if (sources.isEmpty()) {
            Log.w(TAG, "No metadata from RAW, using neutral baseline: $rawPath")
        } else {
            Log.d(TAG, "Baseline $rawPath EV=$exposureEv K=$kelvin tint=$tint sources=$sources")
        }

        return CameraBaseline(
            exposureEv = exposureEv,
            kelvin = kelvin,
            tint = tint,
            redGain = rGain,
            greenGain = gGain,
            blueGain = bGain,
            contrast = contrast,
            shadows = shadows,
            sharpness = sharpness,
            colorSpace = colorSpace,
            pictureControl = pictureControl,
            cameraModel = cameraModel,
            rawWidth = rawW,
            rawHeight = rawH,
            sources = sources,
        )
    }

    private fun parseExposureBias(raw: String?): Float? {
        if (raw.isNullOrBlank()) return null
        val frac = Regex("""([+-]?\d+)\s*/\s*(\d+)""").find(raw)
        if (frac != null) {
            val n = frac.groupValues[1].toFloatOrNull() ?: return null
            val d = frac.groupValues[2].toFloatOrNull() ?: return null
            if (d != 0f) return (n / d).coerceIn(-5f, 5f)
        }
        val m = Regex("""([+-]?\d+(?:\.\d+)?)""").find(raw) ?: return null
        return m.groupValues[1].toFloatOrNull()?.coerceIn(-5f, 5f)
    }

    private fun readHead(file: File): ByteArray {
        val len = minOf(file.length(), MAX_READ.toLong()).toInt()
        if (len <= 0) return ByteArray(0)
        return RandomAccessFile(file, "r").use { raf ->
            val buf = ByteArray(len)
            raf.readFully(buf)
            buf
        }
    }

    private fun findExifTiffOffset(bytes: ByteArray): Int {
        val sig = byteArrayOf(0x45, 0x78, 0x69, 0x66, 0, 0)
        for (i in 0 until bytes.size - sig.size) {
            var ok = true
            for (j in sig.indices) {
                if (bytes[i + j] != sig[j]) {
                    ok = false
                    break
                }
            }
            if (ok) return i + 6
        }
        return -1
    }
}

/** Minimal TIFF IFD reader for EXIF/MakerNote inside RAW header. */
internal class TiffReader(
    private val data: ByteArray,
    private val base: Int,
) {
    val valid: Boolean
    private val le: Boolean

    init {
        var ok = data.size > base + 8
        var little = true
        if (ok) {
            little = when {
                data[base] == 0x49.toByte() && data[base + 1] == 0x49.toByte() -> true
                data[base] == 0x4d.toByte() && data[base + 1] == 0x4d.toByte() -> false
                else -> {
                    ok = false
                    true
                }
            }
            if (ok && u16(base + 2, little) != 0x002a) ok = false
        }
        le = little
        valid = ok
    }

    fun rationalExif(tag: Int): Float? = sRationalExif(tag)

    fun uint16Exif(tag: Int): Int? {
        val ent = findInExif(tag) ?: return null
        if (ent.type != 3) return null
        return u16(dataOffset(ent), le)
    }

    fun byteBlockExif(tag: Int): ByteArray? {
        val ent = findInExif(tag) ?: return null
        return bytesFromEntry(ent)
    }

    private fun exifSubIfdOffset(ifd0: Int): Int? {
        val ent = findEntry(ifd0, 0x8769) ?: return null
        return readOffset(ent)
    }

    private fun findInExif(tag: Int): IfdEntry? {
        val ifd0 = u32(base + 4)
        val exifOff = exifSubIfdOffset(ifd0) ?: return null
        return findEntry(exifOff, tag)
    }

    fun sRationalExif(tag: Int): Float? {
        val ent = findInExif(tag) ?: return null
        val off = dataOffset(ent)
        if (off + 8 > data.size) return null
        return when (ent.type) {
            10 -> {
                val n = s32(off)
                val d = s32(off + 4)
                if (d == 0) null else n.toFloat() / d
            }
            5 -> {
                val n = u32(off, le)
                val d = u32(off + 4, le)
                if (d == 0) null else n.toFloat() / d
            }
            else -> null
        }
    }

    private fun dataOffset(ent: IfdEntry): Int =
        if (ent.count * typeSize(ent.type) <= 4) ent.dataOffset else ent.valueOrOffset

    private fun bytesFromEntry(ent: IfdEntry): ByteArray? {
        if (ent.type != 7 && ent.type != 1) return null
        val start = dataOffset(ent)
        if (start < 0 || start + ent.count > data.size) return null
        return data.copyOfRange(start, start + ent.count)
    }

    private fun readOffset(ent: IfdEntry): Int {
        val off = ent.dataOffset
        return u32(off, le)
    }

    private fun typeSize(type: Int): Int = when (type) {
        1, 2, 6, 7 -> 1
        3, 8 -> 2
        4, 9, 11 -> 4
        5, 10, 12 -> 8
        else -> 1
    }

    private fun s32(off: Int): Int {
        val u = u32(off, le)
        return if (u and 0x80000000.toInt() != 0) (u.inv() + 1) * -1 else u
    }

    private fun uint16AtIfd(ifdOff: Int, tag: Int): Int? {
        val ent = findEntry(ifdOff, tag) ?: return null
        return when (ent.type) {
            3 -> ent.valueOrOffset and 0xffff
            else -> null
        }
    }

    private fun bytesAtIfd(ifdOff: Int, tag: Int): ByteArray? {
        val ent = findEntry(ifdOff, tag) ?: return null
        if (ent.type != 7 && ent.type != 1) return null
        val count = ent.count
        val start = if (count <= 4) ent.dataOffset else ent.valueOrOffset
        if (start < 0 || start + count > data.size) return null
        return data.copyOfRange(start, start + count)
    }

    private fun findEntry(ifdOff: Int, tag: Int): IfdEntry? {
        if (ifdOff + 2 > data.size) return null
        val n = u16(ifdOff, le)
        var p = ifdOff + 2
        for (_i in 0 until n) {
            if (p + 12 > data.size) break
            val t = u16(p, le)
            val type = u16(p + 2, le)
            val count = u32(p + 4, le)
            val vo = u32(p + 8, le)
            if (t == tag) {
                return IfdEntry(type, count, vo, p + 8)
            }
            p += 12
        }
        return null
    }

    private data class IfdEntry(
        val type: Int,
        val count: Int,
        val valueOrOffset: Int,
        val dataOffset: Int,
    )

    private fun u16(o: Int, little: Boolean = le): Int {
        if (o + 1 >= data.size) return 0
        return if (little) {
            data[o].toInt() and 0xff or ((data[o + 1].toInt() and 0xff) shl 8)
        } else {
            (data[o].toInt() and 0xff shl 8) or (data[o + 1].toInt() and 0xff)
        }
    }

    private fun u32(o: Int, little: Boolean = le): Int {
        if (o + 3 >= data.size) return 0
        return if (little) {
            (data[o].toInt() and 0xff) or
                ((data[o + 1].toInt() and 0xff) shl 8) or
                ((data[o + 2].toInt() and 0xff) shl 16) or
                ((data[o + 3].toInt() and 0xff) shl 24)
        } else {
            ((data[o].toInt() and 0xff) shl 24) or
                ((data[o + 1].toInt() and 0xff) shl 16) or
                ((data[o + 2].toInt() and 0xff) shl 8) or
                (data[o + 3].toInt() and 0xff)
        }
    }
}

internal object NikonMakerNoteParser {
    data class PictureControl(
        val name: String?,
        val sharpness: Float,
        val contrast: Float,
        val shadows: Float,
    )

    data class Parsed(
        val kelvin: Float? = null,
        val tint: Float? = null,
        val redGain: Float? = null,
        val greenGain: Float? = null,
        val blueGain: Float? = null,
        val pictureControl: PictureControl? = null,
    )

    fun parse(mn: ByteArray): Parsed {
        if (mn.size < 18) return Parsed()
        if (String(mn, 0, 6, Charsets.US_ASCII) != "Nikon\u0000") return Parsed()

        val le = mn[6] == 0x49.toByte()
        fun u16(o: Int) = readU16(mn, o, le)
        fun u32(o: Int) = readU32(mn, o, le)

        if (u16(10) != 0x002a) return Parsed()
        val ifd0 = u32(12)

        var kelvin: Float? = null
        var tint: Float? = null
        var rGain: Float? = null
        var gGain: Float? = null
        var bGain: Float? = null
        var pc: PictureControl? = null

        bytesAtIfd(mn, ifd0, 0x0023, le)?.let { blob ->
            pc = parsePictureControl(blob)
        }

        sRationalPairAtIfd(mn, ifd0, 0x003f, le)?.let { (a, _) ->
            tint = (a * 40f).coerceIn(-150f, 150f)
        }

        bytesAtIfd(mn, ifd0, 0x0097, le)?.let { balance ->
            if (balance.size >= 10) {
                val r = readU16(balance, 4, true)
                val g = readU16(balance, 6, true)
                val b = readU16(balance, 8, true)
                if (r > 0 && g > 0 && b > 0) {
                    rGain = r.toFloat() / g
                    gGain = 1f
                    bGain = b.toFloat() / g
                    val rb = (r.toFloat() / b).coerceIn(0.4f, 2.5f)
                    kelvin = (6500f * rb.toDouble().pow(0.38)).toFloat().coerceIn(2000f, 50000f)
                }
            }
        }

        uint16AtIfd(mn, ifd0, 0x004f, le)?.let { t ->
            if (kelvin == null && t in 2000..50000) kelvin = t.toFloat()
        }

        return Parsed(kelvin, tint, rGain, gGain, bGain, pc)
    }

    private fun parsePictureControl(blob: ByteArray): PictureControl? {
        if (blob.size < 58) return null
        val name = String(blob, 4, 20, Charsets.US_ASCII)
            .trim().replace("\u0000", "").ifEmpty { null }
        val layouts = listOf(
            Triple(50, 51, 52),
            Triple(57, 55, 57),
            Triple(57, 63, 65),
        )
        for ((si, ci, bi) in layouts) {
            if (si >= blob.size || ci >= blob.size || bi >= blob.size) continue
            val s = blob[si].toInt() and 0xff
            val c = blob[ci].toInt() and 0xff
            val b = blob[bi].toInt() and 0xff
            if (s > 9 || c > 9 || b > 9) continue
            return PictureControl(
                name = name,
                sharpness = ((s - 4) * 12.5f).coerceIn(0f, 100f),
                contrast = ((c - 4) * 25f).coerceIn(-100f, 100f),
                shadows = ((b - 4) * 25f).coerceIn(-100f, 100f),
            )
        }
        return null
    }

    private fun bytesAtIfd(data: ByteArray, ifd: Int, tag: Int, le: Boolean): ByteArray? {
        if (ifd + 2 > data.size) return null
        val n = readU16(data, ifd, le)
        var p = ifd + 2
        for (_i in 0 until n) {
            if (p + 12 > data.size) break
            if (readU16(data, p, le) == tag) {
                val type = readU16(data, p + 2, le)
                val count = readU32(data, p + 4, le)
                val vo = readU32(data, p + 8, le)
                val start = if (count <= 4) p + 8 else vo
                if (start + count <= data.size) return data.copyOfRange(start, start + count)
            }
            p += 12
        }
        return null
    }

    private fun uint16AtIfd(data: ByteArray, ifd: Int, tag: Int, le: Boolean): Int? {
        if (ifd + 2 > data.size) return null
        val n = readU16(data, ifd, le)
        var p = ifd + 2
        for (_i in 0 until n) {
            if (p + 12 > data.size) break
            if (readU16(data, p, le) == tag) {
                val type = readU16(data, p + 2, le)
                if (type == 3) return readU16(data, p + 8, le)
            }
            p += 12
        }
        return null
    }

    private fun sRationalPairAtIfd(
        data: ByteArray,
        ifd: Int,
        tag: Int,
        le: Boolean,
    ): Pair<Float, Float>? {
        if (ifd + 2 > data.size) return null
        val n = readU16(data, ifd, le)
        var p = ifd + 2
        for (_i in 0 until n) {
            if (p + 12 > data.size) break
            if (readU16(data, p, le) == tag) {
                val count = readU32(data, p + 4, le)
                val vo = readU32(data, p + 8, le)
                if (count >= 2 && vo + 16 <= data.size) {
                    val a = readSRational(data, vo, le)
                    val b = readSRational(data, vo + 8, le)
                    return a to b
                }
            }
            p += 12
        }
        return null
    }

    private fun readSRational(data: ByteArray, o: Int, le: Boolean): Float {
        val num = readS32(data, o, le)
        val den = readS32(data, o + 4, le)
        if (den == 0) return 0f
        return num.toFloat() / den
    }

    private fun readS32(data: ByteArray, o: Int, le: Boolean): Int {
        val u = readU32(data, o, le)
        return if (u and 0x80000000.toInt() != 0) (u.inv() + 1) * -1 else u
    }

    private fun readU16(data: ByteArray, o: Int, le: Boolean): Int {
        if (o + 1 >= data.size) return 0
        return if (le) {
            data[o].toInt() and 0xff or ((data[o + 1].toInt() and 0xff) shl 8)
        } else {
            (data[o].toInt() and 0xff shl 8) or (data[o + 1].toInt() and 0xff)
        }
    }

    private fun readU32(data: ByteArray, o: Int, le: Boolean): Int {
        if (o + 3 >= data.size) return 0
        return if (le) {
            (data[o].toInt() and 0xff) or
                ((data[o + 1].toInt() and 0xff) shl 8) or
                ((data[o + 2].toInt() and 0xff) shl 16) or
                ((data[o + 3].toInt() and 0xff) shl 24)
        } else {
            ((data[o].toInt() and 0xff) shl 24) or
                ((data[o + 1].toInt() and 0xff) shl 16) or
                ((data[o + 2].toInt() and 0xff) shl 8) or
                (data[o + 3].toInt() and 0xff)
        }
    }
}
