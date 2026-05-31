package lv.edgarsfoto.efpic_live.raw.develop

import lv.edgarsfoto.efpic_live.processing.BasicToneEngine
import lv.edgarsfoto.efpic_live.processing.LinearImage
import lv.edgarsfoto.efpic_live.processing.SharpenEngine
import lv.edgarsfoto.efpic_live.processing.WhiteBalanceMath
import lv.edgarsfoto.efpic_live.processing.WhiteBalanceProcessor
import lv.edgarsfoto.efpic_live.raw.ColorProfileMatrix
import lv.edgarsfoto.efpic_live.raw.EditSessionState
import lv.edgarsfoto.efpic_live.raw.WhiteBalanceController
import kotlin.math.pow

/**
 * Applies [EditSessionState] to scene-linear [LinearImage].
 *
 * **Embedded proxy (Fāze 1):** only [UserAdjustments] offsets — camera look already in JPG.
 * **True RAW (Fāze 2):** absolute [effective] values on demosaiced data.
 */
object EditDevelopPipeline {

    @JvmStatic
    fun apply(
        image: LinearImage,
        session: EditSessionState,
        useEmbeddedProxyMode: Boolean = true,
        parallel: Boolean = true,
    ) {
        val b = session.cameraBaseline
        val u = session.userAdjustments
        val e = session.effective()
        val wbCtrl = WhiteBalanceController(b)

        if (useEmbeddedProxyMode) {
            val delta = wbCtrl.previewDeltaGains(e.kelvin, e.tint)
            WhiteBalanceProcessor.applyDelta(image, delta)

            val expMul = 2f.pow(u.exposureOffset)
            val contrastGain = 1f + u.contrastOffset / 100f
            val pivot = 0.18f
            val block: (Float, Float, Float) -> Triple<Float, Float, Float> = { r, g, b ->
                var c = BasicToneEngine.applyExposure(r, g, b, expMul)
                c = BasicToneEngine.applyContrast(c.first, c.second, c.third, contrastGain, pivot)
                c = BasicToneEngine.applyShadows(c.first, c.second, c.third, u.shadowsOffset / 100f)
                c = BasicToneEngine.applyHighlights(c.first, c.second, c.third, u.highlightsOffset / 100f)
                c
            }
            if (parallel) image.mapPixelsParallel(block) else image.mapPixels(block)
            if (u.sharpnessOffset > 0.5f) {
                SharpenEngine.apply(
                    image,
                    SharpenEngine.SharpenState(
                        amount = (u.sharpnessOffset / 100f).coerceIn(0f, 1f),
                        radius = 1,
                        detail = 0.5f,
                        masking = 0f,
                        active = true,
                    ),
                )
            }
        } else {
            val profileMatrix = ColorProfileMatrix.forProfile(
                e.colorSpace,
                e.pictureControl,
            )
            ColorProfileMatrix.applyToLinear(image, profileMatrix)

            val gains = WhiteBalanceMath.vonKriesGains(
                e.kelvin,
                e.tint,
                WhiteBalanceMath.RgbGains(e.redGain, e.greenGain, e.blueGain),
            )
            image.mapPixelsParallel { r, g, b ->
                WhiteBalanceMath.applyDiagonalGains(r, g, b, gains)
            }
            val expMul = 2f.pow(e.exposureEv)
            val contrastGain = 1f + e.contrast / 100f
            val pivot = 0.18f
            val block: (Float, Float, Float) -> Triple<Float, Float, Float> = { r, g, b ->
                var c = BasicToneEngine.applyExposure(r, g, b, expMul)
                c = BasicToneEngine.applyContrast(c.first, c.second, c.third, contrastGain, pivot)
                c = BasicToneEngine.applyShadows(c.first, c.second, c.third, e.shadows / 100f)
                c = BasicToneEngine.applyHighlights(c.first, c.second, c.third, e.highlights / 100f)
                c
            }
            if (parallel) image.mapPixelsParallel(block) else image.mapPixels(block)
            if (e.sharpness > 0.5f) {
                SharpenEngine.apply(
                    image,
                    SharpenEngine.SharpenState(
                        amount = (e.sharpness / 100f).coerceIn(0f, 1f),
                        radius = 1,
                        detail = 0.5f,
                        masking = 0f,
                        active = true,
                    ),
                )
            }
        }
    }
}
