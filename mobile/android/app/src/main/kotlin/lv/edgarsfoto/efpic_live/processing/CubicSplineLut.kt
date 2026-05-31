package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.TonePoint
import kotlin.math.max
import kotlin.math.min

/**
 * Natural cubic spline through Lightroom tone-curve control points (0…255),
 * sampled into a 256-entry LUT for fast per-pixel lookup.
 */
object CubicSplineLut {

    /** Identity LUT (no change). */
    @JvmStatic
    fun identity(): FloatArray = FloatArray(256) { it / 255f }

    /**
     * Builds a monotone-friendly cubic spline LUT from [points].
     * Input/output domain: 0…1 (maps Adobe 0…255 curve space).
     */
    @JvmStatic
    fun fromTonePoints(points: List<TonePoint>): FloatArray {
        if (points.isEmpty()) return identity()
        val sorted = points.sortedBy { it.x }
        if (sorted.size == 1) {
            val y = sorted[0].y / 255f
            return FloatArray(256) { y }
        }

        val xs = sorted.map { it.x.toFloat() }.toFloatArray()
        val ys = sorted.map { it.y.toFloat() }.toFloatArray()
        val n = xs.size
        val m = FloatArray(n)
        val a = FloatArray(n - 1)
        val b = FloatArray(n - 1)
        val c = FloatArray(n)
        val d = FloatArray(n - 1)

        for (i in 0 until n - 1) {
            val h = xs[i + 1] - xs[i]
            a[i] = ys[i]
            b[i] = h
        }

        // Natural cubic spline second derivatives.
        val alpha = FloatArray(n)
        for (i in 1 until n - 1) {
            val h0 = xs[i] - xs[i - 1]
            val h1 = xs[i + 1] - xs[i]
            alpha[i] = (3f / h1) * (ys[i + 1] - ys[i]) - (3f / h0) * (ys[i] - ys[i - 1])
        }

        val l = FloatArray(n)
        val mu = FloatArray(n)
        val z = FloatArray(n)
        l[0] = 1f
        for (i in 1 until n - 1) {
            val h0 = xs[i] - xs[i - 1]
            val h1 = xs[i + 1] - xs[i]
            l[i] = 2f * (xs[i + 1] - xs[i - 1]) - h0 * mu[i - 1]
            mu[i] = h1 / l[i]
            z[i] = (alpha[i] - h0 * z[i - 1]) / l[i]
        }
        l[n - 1] = 1f
        z[n - 1] = 0f
        c[n - 1] = 0f
        for (j in n - 2 downTo 0) {
            c[j] = z[j] - mu[j] * c[j + 1]
            d[j] = (c[j + 1] - c[j]) / (xs[j + 1] - xs[j])
            m[j] = (ys[j + 1] - ys[j]) / b[j] - b[j] * (c[j + 1] + 2f * c[j]) / 3f
        }

        val lut = FloatArray(256)
        for (xi in 0 until 256) {
            val x = xi.toFloat()
            var seg = 0
            while (seg < n - 2 && x > xs[seg + 1]) seg++
            seg = seg.coerceIn(0, n - 2)
            val dx = x - xs[seg]
            val h = xs[seg + 1] - xs[seg]
            val y = a[seg] + m[seg] * dx + c[seg] * dx * dx + d[seg] * dx * dx * dx
            lut[xi] = (y / 255f).coerceIn(0f, 1f)
        }
        return lut
    }

    /** Applies [lut] in Adobe curve space: linear → sRGB → LUT → linear. */
    @JvmStatic
    fun applyLutToLinear(r: Float, g: Float, b: Float, lut: FloatArray): Triple<Float, Float, Float> {
        fun map(c: Float): Float {
            val encoded = (ColorSpaces.linearToSrgb(c) * 255f + 0.5f).toInt().coerceIn(0, 255)
            return ColorSpaces.srgbToLinear(lut[encoded])
        }
        return Triple(map(r), map(g), map(b))
    }

    /** Per-channel RGB curve LUTs. */
    @JvmStatic
    fun applyRgbLuts(
        r: Float, g: Float, b: Float,
        lutR: FloatArray, lutG: FloatArray, lutB: FloatArray,
        masterLut: FloatArray? = null,
    ): Triple<Float, Float, Float> {
        var nr = r
        var ng = g
        var nb = b
        if (masterLut != null && !CubicSplineLut.isIdentity(masterLut)) {
            val t = applyLutToLinear(nr, ng, nb, masterLut)
            nr = t.first; ng = t.second; nb = t.third
        }
        fun ch(c: Float, lut: FloatArray): Float {
            val enc = (ColorSpaces.linearToSrgb(c) * 255f + 0.5f).toInt().coerceIn(0, 255)
            return ColorSpaces.srgbToLinear(lut[enc])
        }
        if (!CubicSplineLut.isIdentity(lutR)) nr = ch(nr, lutR)
        if (!CubicSplineLut.isIdentity(lutG)) ng = ch(ng, lutG)
        if (!CubicSplineLut.isIdentity(lutB)) nb = ch(nb, lutB)
        return Triple(nr, ng, nb)
    }

    @JvmStatic
    fun isIdentity(lut: FloatArray): Boolean {
        if (lut.size != 256) return false
        for (i in 0 until 256) if (kotlin.math.abs(lut[i] - i / 255f) > 1e-4f) return false
        return true
    }

    /** Merge parametric sliders into a single master LUT (PV2012 approximation). */
    @JvmStatic
    fun parametricLut(
        shadows: Int,
        darks: Int,
        lights: Int,
        highlights: Int,
        shadowSplit: Int = 25,
        midtoneSplit: Int = 50,
        highlightSplit: Int = 75,
    ): FloatArray {
        if (shadows == 0 && darks == 0 && lights == 0 && highlights == 0) return identity()
        val sSplit = shadowSplit / 100f
        val mSplit = midtoneSplit / 100f
        val hSplit = highlightSplit / 100f
        val sh = shadows / 100f
        val dk = darks / 100f
        val lt = lights / 100f
        val hi = highlights / 100f

        return FloatArray(256) { xi ->
            val x = xi / 255f
            var y = x
            val wSh = bellWeight(x, 0f, sSplit)
            val wDk = bellWeight(x, sSplit, mSplit)
            val wLt = bellWeight(x, mSplit, hSplit)
            val wHi = bellWeight(x, hSplit, 1f)
            y += wSh * sh * 0.35f
            y += wDk * dk * 0.25f
            y += wLt * lt * 0.25f
            y += wHi * hi * 0.35f
            y.coerceIn(0f, 1f)
        }
    }

    private fun bellWeight(x: Float, lo: Float, hi: Float): Float {
        if (x < lo || x > hi) return 0f
        val mid = (lo + hi) * 0.5f
        val half = (hi - lo) * 0.5f
        if (half < 1e-4f) return 1f
        val t = ((x - mid) / half).coerceIn(-1f, 1f)
        return 1f - t * t
    }
}
