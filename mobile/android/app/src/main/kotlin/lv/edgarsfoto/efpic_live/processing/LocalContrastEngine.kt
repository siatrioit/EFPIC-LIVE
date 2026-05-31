package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.LightroomPreset
import kotlin.math.max
import kotlin.math.min

/** Separable box blur on float buffers — O(n) per axis pass. */
object SeparableBlur {

    @JvmStatic
    fun boxBlur(src: FloatArray, width: Int, height: Int, radius: Int): FloatArray {
        if (radius <= 0) return src.copyOf()
        val tmp = FloatArray(src.size)
        val out = FloatArray(src.size)

        // Horizontal pass → tmp
        for (y in 0 until height) {
            val row = y * width
            var sum = 0f
            var count = 0
            for (x in 0 until width) {
                if (x == 0) {
                    sum = 0f
                    count = 0
                    for (k in 0..min(radius, width - 1)) {
                        sum += src[row + k]
                        count++
                    }
                } else {
                    val addX = x + radius
                    val remX = x - radius - 1
                    if (addX < width) {
                        sum += src[row + addX]
                        count++
                    }
                    if (remX >= 0) {
                        sum -= src[row + remX]
                        count--
                    }
                }
                tmp[row + x] = sum / count.coerceAtLeast(1)
            }
        }

        // Vertical pass → out
        for (x in 0 until width) {
            var sum = 0f
            var count = 0
            for (y in 0 until height) {
                if (y == 0) {
                    sum = 0f
                    count = 0
                    for (k in 0..min(radius, height - 1)) {
                        sum += tmp[k * width + x]
                        count++
                    }
                } else {
                    val addY = y + radius
                    val remY = y - radius - 1
                    if (addY < height) {
                        sum += tmp[addY * width + x]
                        count++
                    }
                    if (remY >= 0) {
                        sum -= tmp[remY * width + x]
                        count--
                    }
                }
                out[y * width + x] = sum / count.coerceAtLeast(1)
            }
        }
        return out
    }
}

/**
 * Clarity, Texture, Dehaze via large-radius luminance unsharp mask (local contrast).
 */
object LocalContrastEngine {

    data class LocalContrastState(
        val clarity: Float,
        val texture: Float,
        val dehaze: Float,
        val clarityRadius: Int,
        val textureRadius: Int,
        val active: Boolean,
    ) {
        companion object {
            fun fromPreset(p: LightroomPreset): LocalContrastState {
                val clarity = (if (p.clarity2012 != 0) p.clarity2012 else p.clarity) / 100f
                val texture = p.texture / 100f
                val dehaze = p.dehaze / 100f
                val active = clarity != 0f || texture != 0f || dehaze != 0f
                return LocalContrastState(
                    clarity = clarity,
                    texture = texture,
                    dehaze = dehaze,
                    clarityRadius = 12,
                    textureRadius = 3,
                    active = active,
                )
            }
        }
    }

    @JvmStatic
    fun apply(image: LinearImage, state: LocalContrastState) {
        if (!state.active) return
        val w = image.width
        val h = image.height
        val n = w * h
        val luma = FloatArray(n)
        val px = image.pixels
        for (i in 0 until n) {
            val j = i * 3
            luma[i] = ColorSpaces.linearLuma(px[j], px[j + 1], px[j + 2])
        }

        if (state.dehaze != 0f) {
            applyDehaze(px, luma, w, h, state.dehaze)
        }
        if (state.clarity != 0f) {
            applyUnsharpOnLuma(px, luma, w, h, state.clarity * 0.65f, state.clarityRadius)
        }
        if (state.texture != 0f) {
            applyUnsharpOnLuma(px, luma, w, h, state.texture * 0.45f, state.textureRadius)
        }
    }

    private fun applyUnsharpOnLuma(
        px: FloatArray,
        luma: FloatArray,
        w: Int,
        h: Int,
        amount: Float,
        radius: Int,
    ) {
        if (amount == 0f) return
        val blur = SeparableBlur.boxBlur(luma, w, h, radius)
        val n = w * h
        for (i in 0 until n) {
            val j = i * 3
            val y = luma[i]
            if (y < 1e-5f) continue
            val detail = y - blur[i]
            val newY = (y + amount * detail).coerceIn(0f, 1f)
            val scale = newY / y
            px[j] = (px[j] * scale).coerceIn(0f, 1f)
            px[j + 1] = (px[j + 1] * scale).coerceIn(0f, 1f)
            px[j + 2] = (px[j + 2] * scale).coerceIn(0f, 1f)
        }
    }

    private fun applyDehaze(
        px: FloatArray,
        luma: FloatArray,
        w: Int,
        h: Int,
        amount: Float,
    ) {
        if (amount == 0f) return
        val blur = SeparableBlur.boxBlur(luma, w, h, 8)
        val n = w * h
        val strength = amount * 0.55f
        for (i in 0 until n) {
            val j = i * 3
            var r = px[j]
            var g = px[j + 1]
            var b = px[j + 2]
            val y = luma[i]
            val localContrast = (y - blur[i]) * strength * 1.2f
            val lift = strength * 0.08f * (1f - y)
            val newY = (y + localContrast + lift).coerceIn(0f, 1f)
            if (y > 1e-5f) {
                val scale = newY / y
                r = (r * scale).coerceIn(0f, 1f)
                g = (g * scale).coerceIn(0f, 1f)
                b = (b * scale).coerceIn(0f, 1f)
            }
            if (amount > 0f) {
                val hsv = ColorSpaces.rgbToHsv(r, g, b)
                val satBoost = 1f + strength * 0.15f * (1f - hsv.s)
                val (nr, ng, nb) = ColorSpaces.hsvToRgb(
                    hsv.h,
                    (hsv.s * satBoost).coerceIn(0f, 1f),
                    hsv.v,
                )
                px[j] = nr; px[j + 1] = ng; px[j + 2] = nb
            } else {
                px[j] = r; px[j + 1] = g; px[j + 2] = b
            }
        }
    }
}
