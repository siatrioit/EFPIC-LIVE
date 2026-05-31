package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.HslChannel
import lv.edgarsfoto.efpic_live.xmp.LightroomPreset
import kotlin.math.abs
import kotlin.math.exp

/**
 * 8-channel HSL color mixer with smooth hue-band weights (Lightroom-style).
 */
object HslColorMixerEngine {

    private const val BAND_WIDTH = 35f // degrees half-width

    /** Precomputed band centers in degrees. */
    private val CENTERS = floatArrayOf(
        0f, 30f, 60f, 120f, 180f, 240f, 270f, 300f,
    )

    data class MixerState(
        val channels: Array<HslChannel>,
        val active: Boolean,
    ) {
        companion object {
            fun fromPreset(p: LightroomPreset): MixerState {
                val hsl = p.hsl
                val channels = arrayOf(
                    hsl.red, hsl.orange, hsl.yellow, hsl.green,
                    hsl.aqua, hsl.blue, hsl.purple, hsl.magenta,
                )
                val active = channels.any { it.hue != 0 || it.saturation != 0 || it.luminance != 0 }
                return MixerState(channels, active)
            }
        }
    }

    @JvmStatic
    fun apply(r: Float, g: Float, b: Float, state: MixerState): Triple<Float, Float, Float> {
        if (!state.active) return Triple(r, g, b)

        val (h, s, l) = ColorSpaces.rgbToHsl(r, g, b)
        if (s < 1e-4f) return Triple(r, g, b)

        var dh = 0f
        var ds = 0f
        var dl = 0f
        var wSum = 0f

        for (i in CENTERS.indices) {
            val w = hueWeight(h, CENTERS[i])
            if (w < 1e-4f) continue
            val ch = state.channels[i]
            dh += w * ch.hue
            ds += w * (ch.saturation / 100f)
            dl += w * (ch.luminance / 100f)
            wSum += w
        }
        if (wSum < 1e-4f) return Triple(r, g, b)
        dh /= wSum
        ds /= wSum
        dl /= wSum

        var nh = (h + dh) % 360f
        if (nh < 0f) nh += 360f
        var ns = (s * (1f + ds)).coerceIn(0f, 1f)
        var nl = (l + dl * 0.25f).coerceIn(0f, 1f)

        return ColorSpaces.hslToRgb(nh, ns, nl)
    }

    /** Gaussian-ish weight on circular hue distance. */
    private fun hueWeight(hue: Float, center: Float): Float {
        var d = abs(hue - center)
        if (d > 180f) d = 360f - d
        val t = d / BAND_WIDTH
        return exp(-t * t * 2f)
    }
}
