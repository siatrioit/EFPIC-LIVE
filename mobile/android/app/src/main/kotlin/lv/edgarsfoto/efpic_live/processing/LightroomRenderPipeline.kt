package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.LightroomPreset

/**
 * Black-box Lightroom rendering pipeline for scene-linear RGB.
 *
 * **Sequence:**
 * 1. White balance
 * 2. Exposure / basic tones (contrast, highlights, shadows, **whites**, **blacks**)
 * 3. Tone curves (parametric + RGB splines)
 * 4. HSL 8-channel mixer
 * 5. Color grading / split toning
 * 6. Local contrast (clarity, texture, dehaze)
 * 7. Sharpening
 *
 * All preset values come from [LightroomPreset] (XMP). No UI sliders required.
 */
object LightroomRenderPipeline {

    /** Precomputed render state — build once per preset, reuse across frames/tiles. */
    class RenderContext(preset: LightroomPreset) {
        val tone = BasicToneEngine.ToneState.fromPreset(preset)
        val curves = ToneCurveEngine.CurveState.fromPreset(preset)
        val hsl = HslColorMixerEngine.MixerState.fromPreset(preset)
        val grading = ColorGradingEngine.GradingState.fromPreset(preset)
        val localContrast = LocalContrastEngine.LocalContrastState.fromPreset(preset)
        val sharpen = SharpenEngine.SharpenState.fromPreset(preset)
        val convertToGrayscale = preset.convertToGrayscale
    }

    @JvmStatic
    fun createContext(preset: LightroomPreset): RenderContext = RenderContext(preset)

    /**
     * Renders [input] in-place (or use [renderCopy] to preserve source).
     * Input must be scene-linear RGB 0…1.
     */
    @JvmStatic
    fun render(image: LinearImage, context: RenderContext, parallel: Boolean = true) {
        val processPixel: (Float, Float, Float) -> Triple<Float, Float, Float> = { r, g, b ->
            var c = BasicToneEngine.applyWhiteBalance(r, g, b, context.tone)
            c = BasicToneEngine.applyBasicTones(c.first, c.second, c.third, context.tone)
            c = ToneCurveEngine.apply(c.first, c.second, c.third, context.curves)
            c = HslColorMixerEngine.apply(c.first, c.second, c.third, context.hsl)
            c = ColorGradingEngine.apply(c.first, c.second, c.third, context.grading)
            if (context.convertToGrayscale) {
                val y = ColorSpaces.linearLuma(c.first, c.second, c.third)
                c = Triple(y, y, y)
            }
            c
        }

        if (parallel) image.mapPixelsParallel(processPixel)
        else image.mapPixels(processPixel)

        // Full-frame operators (need blur).
        LocalContrastEngine.apply(image, context.localContrast)
        SharpenEngine.apply(image, context.sharpen)
    }

    @JvmStatic
    fun renderCopy(input: LinearImage, context: RenderContext, parallel: Boolean = true): LinearImage {
        val copy = input.copy()
        render(copy, context, parallel)
        return copy
    }

    /** Convenience: sRGB bytes → linear render → sRGB bytes. */
    @JvmStatic
    fun renderSrgbBytes(
        rgb: ByteArray,
        width: Int,
        height: Int,
        preset: LightroomPreset,
        parallel: Boolean = true,
    ): ByteArray {
        val image = LinearImage.fromSrgbBytes(rgb, width, height)
        val ctx = createContext(preset)
        render(image, ctx, parallel)
        return LinearImage.toSrgbBytes(image)
    }
}
