package lv.edgarsfoto.efpic_live.processing

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/** sRGB ↔ linear, luma, HSV/HSL helpers (Rec.709). */
object ColorSpaces {
    const val KR = 0.2126729f
    const val KG = 0.7151522f
    const val KB = 0.0721750f

    @JvmStatic
    fun srgbToLinear(c: Float): Float {
        val v = c.coerceIn(0f, 1f)
        return if (v <= 0.04045f) v / 12.92f else ((v + 0.055f) / 1.055f).pow(2.4f)
    }

    @JvmStatic
    fun linearToSrgb(c: Float): Float {
        val v = c.coerceIn(0f, 1f)
        return if (v <= 0.0031308f) v * 12.92f else 1.055f * v.pow(1f / 2.4f) - 0.055f
    }

    @JvmStatic
    fun srgbByteToLinear(v: Int): Float = srgbToLinear(v / 255f)

    @JvmStatic
    fun linearToSrgbByte(c: Float): Byte =
        (linearToSrgb(c) * 255f + 0.5f).toInt().coerceIn(0, 255).toByte()

    @JvmStatic
    fun linearLuma(r: Float, g: Float, b: Float): Float = KR * r + KG * g + KB * b

    @JvmStatic
    fun clampLinear(r: Float, g: Float, b: Float): Triple<Float, Float, Float> =
        Triple(r.coerceIn(0f, 1f), g.coerceIn(0f, 1f), b.coerceIn(0f, 1f))

    /** Hue in degrees 0…360, s/v in 0…1. */
    data class Hsv(val h: Float, val s: Float, val v: Float)

    @JvmStatic
    fun rgbToHsv(r: Float, g: Float, b: Float): Hsv {
        val maxC = max(max(r, g), b)
        val minC = min(min(r, g), b)
        val delta = maxC - minC
        if (delta < 1e-6f) return Hsv(0f, 0f, maxC)
        val s = delta / maxC
        val h = when (maxC) {
            r -> 60f * (((g - b) / delta) % 6f)
            g -> 60f * (((b - r) / delta) + 2f)
            else -> 60f * (((r - g) / delta) + 4f)
        }
        return Hsv((h + 360f) % 360f, s, maxC)
    }

    @JvmStatic
    fun hsvToRgb(h: Float, s: Float, v: Float): Triple<Float, Float, Float> {
        if (s < 1e-6f) return Triple(v, v, v)
        val hh = (h % 360f) / 60f
        val i = hh.toInt()
        val f = hh - i
        val p = v * (1f - s)
        val q = v * (1f - s * f)
        val t = v * (1f - s * (1f - f))
        return when (i % 6) {
            0 -> Triple(v, t, p)
            1 -> Triple(q, v, p)
            2 -> Triple(p, v, t)
            3 -> Triple(p, q, v)
            4 -> Triple(t, p, v)
            else -> Triple(v, p, q)
        }
    }

    /** HSL: h 0…360, s/l 0…1 */
    @JvmStatic
    fun rgbToHsl(r: Float, g: Float, b: Float): Triple<Float, Float, Float> {
        val maxC = max(max(r, g), b)
        val minC = min(min(r, g), b)
        val l = (maxC + minC) * 0.5f
        if (maxC == minC) return Triple(0f, 0f, l)
        val d = maxC - minC
        val s = if (l > 0.5f) d / (2f - maxC - minC) else d / (maxC + minC)
        val h = when (maxC) {
            r -> ((g - b) / d + (if (g < b) 6f else 0f)) / 6f
            g -> ((b - r) / d + 2f) / 6f
            else -> ((r - g) / d + 4f) / 6f
        }
        return Triple(h * 360f, s, l)
    }

    @JvmStatic
    fun hslToRgb(h: Float, s: Float, l: Float): Triple<Float, Float, Float> {
        if (s < 1e-6f) return Triple(l, l, l)
        fun hue2rgb(p: Float, q: Float, tIn: Float): Float {
            var t = tIn
            if (t < 0f) t += 1f
            if (t > 1f) t -= 1f
            return when {
                t < 1f / 6f -> p + (q - p) * 6f * t
                t < 1f / 2f -> q
                t < 2f / 3f -> p + (q - p) * (2f / 3f - t) * 6f
                else -> p
            }
        }
        val hh = (h % 360f) / 360f
        val q = if (l < 0.5f) l * (1f + s) else l + s - l * s
        val p = 2f * l - q
        return Triple(
            hue2rgb(p, q, hh + 1f / 3f),
            hue2rgb(p, q, hh),
            hue2rgb(p, q, hh - 1f / 3f),
        )
    }

    /** Hue/sat → linear RGB tint (unit vector on color wheel, sat 0…1). */
    @JvmStatic
    fun hueSatToLinearTint(hueDeg: Float, sat: Float): Triple<Float, Float, Float> {
        val rad = Math.toRadians(hueDeg.toDouble())
        val c = sat.coerceIn(0f, 1f)
        // Approximate chromaticity from hue angle (max channel = 1).
        val r = (0.5f + 0.5f * cos(rad)).toFloat() * c + (1f - c)
        val g = (0.5f + 0.5f * cos(rad - 2.094395f)).toFloat() * c + (1f - c)
        val b = (0.5f + 0.5f * cos(rad + 2.094395f)).toFloat() * c + (1f - c)
        val luma = linearLuma(r, g, b).coerceAtLeast(1e-4f)
        return Triple(r / luma, g / luma, b / luma)
    }

    @JvmStatic
    fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
        if (edge0 == edge1) return if (x >= edge1) 1f else 0f
        val t = ((x - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }
}
