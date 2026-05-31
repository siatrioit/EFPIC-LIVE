package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.ColorGradeZone
import lv.edgarsfoto.efpic_live.xmp.ColorGradingSettings
import lv.edgarsfoto.efpic_live.xmp.LightroomPreset

/**
 * Split toning + three-way color grading (shadows / midtones / highlights).
 * Lift-gamma-gain style tinting in scene-linear space.
 */
object ColorGradingEngine {

    data class GradingState(
        val shadowTint: Triple<Float, Float, Float>,
        val midTint: Triple<Float, Float, Float>,
        val highlightTint: Triple<Float, Float, Float>,
        val globalTint: Triple<Float, Float, Float>,
        val balance: Float,
        val blending: Float,
        val active: Boolean,
    ) {
        companion object {
            fun fromPreset(p: LightroomPreset): GradingState {
                val cg = p.colorGrading
                val sh = zoneTint(cg.shadows, cg.splitToning.shadowHue, cg.splitToning.shadowSaturation)
                val hi = zoneTint(cg.highlights, cg.splitToning.highlightHue, cg.splitToning.highlightSaturation)
                val mid = zoneTint(cg.midtones, 0, 0)
                val glob = zoneTint(cg.global, 0, 0)
                val active = sh != neutralTint || hi != neutralTint || mid != neutralTint || glob != neutralTint
                return GradingState(
                    shadowTint = sh,
                    midTint = mid,
                    highlightTint = hi,
                    globalTint = glob,
                    balance = cg.balance / 100f,
                    blending = cg.blending / 100f,
                    active = active,
                )
            }

            private val neutralTint = Triple(1f, 1f, 1f)

            private fun zoneTint(zone: ColorGradeZone, fallbackHue: Int, fallbackSat: Int): Triple<Float, Float, Float> {
                val hue = if (zone.hue != 0) zone.hue else fallbackHue
                val sat = if (zone.saturation != 0) zone.saturation else fallbackSat
                if (hue == 0 && sat == 0 && zone.luminance == 0) return neutralTint
                val s = (sat / 100f).coerceIn(0f, 1f) * 0.65f
                val (tr, tg, tb) = ColorSpaces.hueSatToLinearTint(hue.toFloat(), s)
                val lum = 1f + zone.luminance / 200f
                return Triple(tr * lum, tg * lum, tb * lum)
            }
        }
    }

    @JvmStatic
    fun apply(r: Float, g: Float, b: Float, state: GradingState): Triple<Float, Float, Float> {
        if (!state.active) return Triple(r, g, b)

        val y = ColorSpaces.linearLuma(r, g, b)
        val balance = state.balance.coerceIn(-1f, 1f)
        val blend = state.blending.coerceIn(0f, 1f)

        // Shadow / highlight split with balance offset.
        val shadowEnd = (0.35f - balance * 0.15f).coerceIn(0.1f, 0.5f)
        val highlightStart = (0.65f - balance * 0.15f).coerceIn(0.5f, 0.9f)

        val wSh = (1f - ColorSpaces.smoothstep(shadowEnd * 0.5f, shadowEnd, y)) * blend
        val wHi = ColorSpaces.smoothstep(highlightStart, (highlightStart + 0.25f).coerceAtMost(1f), y) * blend
        val wMid = (1f - wSh - wHi).coerceAtLeast(0f)

        fun tint(
            rr: Float, gg: Float, bb: Float,
            tint: Triple<Float, Float, Float>,
            weight: Float,
        ): Triple<Float, Float, Float> {
            if (weight < 1e-5f) return Triple(rr, gg, bb)
            val mix = weight * 0.45f
            return ColorSpaces.clampLinear(
                rr * (1f - mix) + rr * tint.first * mix,
                gg * (1f - mix) + gg * tint.second * mix,
                bb * (1f - mix) + bb * tint.third * mix,
            )
        }

        var c = Triple(r, g, b)
        c = tint(c.first, c.second, c.third, state.globalTint, 0.25f)
        c = tint(c.first, c.second, c.third, state.shadowTint, wSh)
        c = tint(c.first, c.second, c.third, state.midTint, wMid)
        c = tint(c.first, c.second, c.third, state.highlightTint, wHi)
        return c
    }
}
