package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.LightroomPreset
import kotlin.math.abs

/** Luminance unsharp mask (Lightroom-style sharpening). */
object SharpenEngine {

    data class SharpenState(
        val amount: Float,
        val radius: Int,
        val detail: Float,
        val masking: Float,
        val active: Boolean,
    ) {
        companion object {
            fun fromPreset(p: LightroomPreset): SharpenState {
                val d = p.detail
                val amount = d.sharpness / 100f
                val radius = (d.sharpnessRadius * 1.5f).toInt().coerceIn(1, 4)
                val active = amount > 0.01f
                return SharpenState(
                    amount = amount,
                    radius = radius,
                    detail = d.sharpnessDetail / 100f,
                    masking = d.sharpnessEdgeMasking / 100f,
                    active = active,
                )
            }
        }
    }

    @JvmStatic
    fun apply(image: LinearImage, state: SharpenState) {
        if (!state.active) return
        val w = image.width
        val h = image.height
        val n = w * h
        val px = image.pixels
        val luma = FloatArray(n)
        for (i in 0 until n) {
            val j = i * 3
            luma[i] = ColorSpaces.linearLuma(px[j], px[j + 1], px[j + 2])
        }
        val blur = SeparableBlur.boxBlur(luma, w, h, state.radius)
        val amt = state.amount * (1f + state.detail * 0.5f)

        for (i in 0 until n) {
            val j = i * 3
            val y = luma[i]
            if (y < 1e-5f) continue
            val edge = abs(y - blur[i])
            val edgeMask = if (state.masking > 0f) {
                ColorSpaces.smoothstep(0.02f, 0.12f + state.masking * 0.2f, edge)
            } else {
                1f
            }
            val detail = (y - blur[i]) * amt * edgeMask
            val newY = (y + detail).coerceIn(0f, 1f)
            val scale = newY / y
            px[j] = (px[j] * scale).coerceIn(0f, 1f)
            px[j + 1] = (px[j + 1] * scale).coerceIn(0f, 1f)
            px[j + 2] = (px[j + 2] * scale).coerceIn(0f, 1f)
        }
    }
}
