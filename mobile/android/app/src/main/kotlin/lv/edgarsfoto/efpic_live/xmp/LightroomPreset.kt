package lv.edgarsfoto.efpic_live.xmp

/**
 * Complete Adobe Camera Raw / Lightroom development settings extracted from an `.xmp` sidecar
 * or preset file (`xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"`).
 *
 * Missing tags resolve to photographic neutrals: **0** for adjustments, **1.0** for multipliers,
 * empty tone curves, and centered HSL / color grading.
 */
data class LightroomPreset(
    // --- Metadata ---
    val version: String = "",
    val processVersion: String = "",
    val cameraProfile: String = "",
    val cameraProfileDigest: String = "",
    val whiteBalance: String = "",
    val alreadyApplied: Boolean = false,
    val hasSettings: Boolean = true,
    val convertToGrayscale: Boolean = false,

    // --- Basic exposure & tone (Process 2012) ---
    val exposure2012: Float = 0f,
    val contrast2012: Int = 0,
    val highlights2012: Int = 0,
    val shadows2012: Int = 0,
    val whites2012: Int = 0,
    val blacks2012: Int = 0,

    // --- Legacy tone (Process 2010 and earlier) ---
    val exposure: Float = 0f,
    val contrast: Int = 0,
    val shadows: Int = 0,
    val brightness: Int = 0,
    val fillLight: Int = 0,
    val highlightRecovery: Int = 0,

    // --- White balance & global color ---
    val temperature: Int = 0,
    val tint: Int = 0,
    val incrementalTemperature: Int = 0,
    val incrementalTint: Int = 0,
    val vibrance: Int = 0,
    val saturation: Int = 0,

    // --- Presence / texture ---
    val clarity2012: Int = 0,
    val clarity: Int = 0,
    val dehaze: Int = 0,
    val texture: Int = 0,

    // --- Detail ---
    val detail: DetailSettings = DetailSettings(),

    // --- Parametric tone curve (sliders) ---
    val parametric: ParametricTone = ParametricTone(),

    // --- Point-based tone curves ---
    val toneCurves: ToneCurveSettings = ToneCurveSettings(),

    // --- HSL / Color mixer (8 colors) ---
    val hsl: HslColorMixer = HslColorMixer(),

    // --- B&W mixer (optional) ---
    val grayMixer: GrayMixer = GrayMixer(),

    // --- Color grading / split toning ---
    val colorGrading: ColorGradingSettings = ColorGradingSettings(),

    // --- Lens corrections, vignette, perspective ---
    val lens: LensCorrectionSettings = LensCorrectionSettings(),

    // --- Crop (when embedded in preset) ---
    val crop: CropSettings = CropSettings(),

    // --- Auto-tone flags ---
    val autoExposure: Boolean = false,
    val autoContrast: Boolean = false,
    val autoBrightness: Boolean = false,
    val autoShadows: Boolean = false,

    /**
     * Any `crs:*` attribute or simple leaf value not mapped above.
     * Keeps the parser forward-compatible with newer Lightroom versions.
     */
    val extraCrsAttributes: Map<String, String> = emptyMap(),
) {
    companion object {
        val DEFAULT = LightroomPreset()
    }
}

/** Tone curve control point in 0…255 space (Lightroom convention). */
data class TonePoint(
    val x: Int,
    val y: Int,
) {
    init {
        require(x in 0..255 && y in 0..255) { "TonePoint must be in 0..255, got ($x, $y)" }
    }
}

data class DetailSettings(
    val sharpness: Int = 0,
    /** XMP tag: `SharpenRadius` */
    val sharpnessRadius: Float = 1f,
    /** XMP tag: `SharpenDetail` */
    val sharpnessDetail: Int = 0,
    /** XMP tag: `SharpenEdgeMasking` */
    val sharpnessEdgeMasking: Int = 0,
    /** XMP tag: `LuminanceSmoothing` */
    val luminanceSmoothing: Int = 0,
    val luminanceNoiseReductionDetail: Int = 0,
    val luminanceNoiseReductionContrast: Int = 0,
    val colorNoiseReduction: Int = 0,
    val colorNoiseReductionDetail: Int = 0,
    val colorNoiseReductionSmoothness: Int = 0,
)

data class ParametricTone(
    val shadows: Int = 0,
    val darks: Int = 0,
    val lights: Int = 0,
    val highlights: Int = 0,
    val shadowSplit: Int = 25,
    val midtoneSplit: Int = 50,
    val highlightSplit: Int = 75,
)

data class ToneCurveSettings(
    val toneCurveName: String = "",
    val toneCurveName2012: String = "",
    /** Legacy combined curve. */
    val toneCurve: List<TonePoint> = emptyList(),
    val toneCurveRed: List<TonePoint> = emptyList(),
    val toneCurveGreen: List<TonePoint> = emptyList(),
    val toneCurveBlue: List<TonePoint> = emptyList(),
    /** Process Version 2012 luma curve. */
    val toneCurvePv2012: List<TonePoint> = emptyList(),
    val toneCurvePv2012Red: List<TonePoint> = emptyList(),
    val toneCurvePv2012Green: List<TonePoint> = emptyList(),
    val toneCurvePv2012Blue: List<TonePoint> = emptyList(),
)

enum class HslColor {
    Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta,
}

data class HslChannel(
    val hue: Int = 0,
    val saturation: Int = 0,
    val luminance: Int = 0,
)

data class HslColorMixer(
    val red: HslChannel = HslChannel(),
    val orange: HslChannel = HslChannel(),
    val yellow: HslChannel = HslChannel(),
    val green: HslChannel = HslChannel(),
    val aqua: HslChannel = HslChannel(),
    val blue: HslChannel = HslChannel(),
    val purple: HslChannel = HslChannel(),
    val magenta: HslChannel = HslChannel(),
) {
    fun channel(color: HslColor): HslChannel = when (color) {
        HslColor.Red -> red
        HslColor.Orange -> orange
        HslColor.Yellow -> yellow
        HslColor.Green -> green
        HslColor.Aqua -> aqua
        HslColor.Blue -> blue
        HslColor.Purple -> purple
        HslColor.Magenta -> magenta
    }
}

data class GrayMixer(
    val red: Int = 0,
    val orange: Int = 0,
    val yellow: Int = 0,
    val green: Int = 0,
    val aqua: Int = 0,
    val blue: Int = 0,
    val purple: Int = 0,
    val magenta: Int = 0,
)

/** Legacy split toning (Lightroom < 10). */
data class SplitToning(
    val shadowHue: Int = 0,
    val shadowSaturation: Int = 0,
    val highlightHue: Int = 0,
    val highlightSaturation: Int = 0,
    val balance: Int = 0,
)

/** Modern three-way color grading (Lightroom 10+). */
data class ColorGradeZone(
    val hue: Int = 0,
    val saturation: Int = 0,
    val luminance: Int = 0,
)

data class ColorGradingSettings(
    val splitToning: SplitToning = SplitToning(),
    val shadows: ColorGradeZone = ColorGradeZone(),
    val midtones: ColorGradeZone = ColorGradeZone(),
    val highlights: ColorGradeZone = ColorGradeZone(),
    val global: ColorGradeZone = ColorGradeZone(),
    val blending: Int = 50,
    val balance: Int = 0,
)

data class LensCorrectionSettings(
    val lensProfileEnable: Int = 0,
    val lensProfileSetup: String = "",
    val lensProfileName: String = "",
    val lensProfileFilename: String = "",
    val lensProfileDigest: String = "",
    val lensProfileDistortionScale: Int = 100,
    val lensProfileChromaticAberrationScale: Int = 100,
    val lensProfileVignettingScale: Int = 100,
    /** Manual distortion; XMP: `LensManualDistortionAmount`. */
    val distortionCorrection: Int = 0,
    val chromaticAberrationR: Int = 0,
    val chromaticAberrationB: Int = 0,
    val autoLateralCA: Int = 0,
    val defringe: Int = 0,
    val defringePurpleAmount: Int = 0,
    val defringePurpleHueLo: Int = 0,
    val defringePurpleHueHi: Int = 0,
    val defringeGreenAmount: Int = 0,
    val defringeGreenHueLo: Int = 0,
    val defringeGreenHueHi: Int = 0,
    val vignetteAmount: Int = 0,
    val vignetteMidpoint: Int = 50,
    val postCropVignetteAmount: Int = 0,
    val postCropVignetteMidpoint: Int = 50,
    val postCropVignetteFeather: Int = 50,
    val postCropVignetteRoundness: Int = 0,
    val postCropVignetteStyle: Int = 0,
    val postCropVignetteHighlightContrast: Int = 0,
    val perspectiveVertical: Int = 0,
    val perspectiveHorizontal: Int = 0,
    val perspectiveRotate: Float = 0f,
    val perspectiveScale: Int = 100,
    val perspectiveAspect: Int = 0,
    val perspectiveUpright: Int = 0,
    val uprightVersion: Int = 0,
)

data class CropSettings(
    val hasCrop: Boolean = false,
    val cropTop: Float = 0f,
    val cropLeft: Float = 0f,
    val cropBottom: Float = 1f,
    val cropRight: Float = 1f,
    val cropWidth: Float = 0f,
    val cropHeight: Float = 0f,
    val cropAngle: Float = 0f,
    val cropUnits: Int = 0,
    val cropConstrainToWarp: Int = 0,
)
