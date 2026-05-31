package lv.edgarsfoto.efpic_live.xmp

import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.InputStream
import java.io.Reader

/**
 * Parses Adobe Lightroom / Camera Raw `.xmp` sidecars and preset files into [LightroomPreset].
 *
 * Handles:
 * - `crs:*` attributes on `rdf:Description` (typical preset layout)
 * - Nested `rdf:Seq` / `rdf:li` tone curve point lists
 * - Namespace prefixes (`crs`, `rdf`, etc.) regardless of declaration order
 */
object XmpParser {

    const val CRS_NS = "http://ns.adobe.com/camera-raw-settings/1.0/"

    /** Parses from a UTF-8 byte stream (file, asset, etc.). */
    @JvmStatic
    fun parse(input: InputStream): LightroomPreset =
        parseInternal(input.reader().readText())

    /** Parses from a character reader. */
    @JvmStatic
    fun parse(reader: Reader): LightroomPreset =
        parseInternal(reader.readText())

    /** Parses from a complete XMP XML string. */
    @JvmStatic
    fun parseString(xml: String): LightroomPreset = parseInternal(xml)

    private fun parseInternal(xml: String): LightroomPreset {
        val factory = XmlPullParserFactory.newInstance().apply { isNamespaceAware = true }
        val parser = factory.newPullParser().apply { setInput(xml.reader()) }

        val attrs = mutableMapOf<String, String>()
        val curveLists = mutableMapOf<String, MutableList<TonePoint>>()
        val prefixToUri = mutableMapOf<String, String>()

        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_DOCUMENT, XmlPullParser.START_TAG -> {
                    collectNamespaceDeclarations(parser, prefixToUri)

                    if (event == XmlPullParser.START_TAG) {
                        val local = parser.name ?: ""
                        val ns = parser.namespace.orEmpty()

                        for (i in 0 until parser.attributeCount) {
                            val attrNs = parser.getAttributeNamespace(i).orEmpty()
                            val attrName = parser.getAttributeName(i) ?: continue
                            val attrPrefix = parser.getAttributePrefix(i)
                            val value = parser.getAttributeValue(i) ?: continue
                            val crsLocal = resolveCrsLocalName(
                                attrNs, attrPrefix, attrName, prefixToUri,
                            )
                            if (crsLocal != null) {
                                attrs[crsLocal] = value.trim()
                            }
                        }

                        if (isCrsNamespace(ns, local, parser.prefix, prefixToUri) &&
                            isToneCurveTag(localName(local))
                        ) {
                            val curveKey = localName(local)
                            val points = readToneCurveElement(parser)
                            if (points.isNotEmpty()) {
                                curveLists.getOrPut(curveKey) { mutableListOf() }.apply {
                                    clear()
                                    addAll(points)
                                }
                            }
                        }
                    }
                }
            }
            event = parser.next()
        }

        curveLists.forEach { (key, points) ->
            attrs[key] = points.joinToString(" ") { "${it.x}, ${it.y}" }
        }

        return buildPreset(attrs, curveLists)
    }

    // -------------------------------------------------------------------------
    // XML helpers
    // -------------------------------------------------------------------------

    private fun collectNamespaceDeclarations(
        parser: XmlPullParser,
        prefixToUri: MutableMap<String, String>,
    ) {
        for (i in 0 until parser.attributeCount) {
            val name = parser.getAttributeName(i) ?: continue
            val value = parser.getAttributeValue(i) ?: continue
            when {
                name == "xmlns" -> prefixToUri[""] = value
                name.startsWith("xmlns:") -> prefixToUri[name.removePrefix("xmlns:")] = value
            }
        }
    }

    private fun resolveCrsLocalName(
        attrNs: String,
        attrPrefix: String?,
        attrName: String,
        prefixToUri: Map<String, String>,
    ): String? {
        if (attrNs == CRS_NS) return attrName
        if (attrPrefix != null && prefixToUri[attrPrefix] == CRS_NS) return attrName
        if (attrName.startsWith("crs:")) return attrName.removePrefix("crs:")
        return null
    }

    private fun localName(name: String): String =
        name.substringAfter(':', name)

    private fun isCrsNamespace(
        ns: String,
        name: String,
        prefix: String?,
        prefixToUri: Map<String, String>,
    ): Boolean {
        if (ns == CRS_NS) return true
        if (prefix != null && prefixToUri[prefix] == CRS_NS) return true
        if (name.startsWith("crs:")) return true
        return false
    }

    private fun isToneCurveTag(local: String): Boolean =
        local.startsWith("ToneCurve")

    /**
     * Reads tone curve points from:
     * - child `rdf:Seq` / `rdf:li` text ("x, y")
     * - direct text content
     * - attribute value on the element
     */
    private fun readToneCurveElement(parser: XmlPullParser): List<TonePoint> {
        // Attribute-based curve (rare but valid).
        for (i in 0 until parser.attributeCount) {
            val name = parser.getAttributeName(i)
            if (name == "rdf:resource" || name == "resource") continue
            val value = parser.getAttributeValue(i)
            if (!value.isNullOrBlank() && name != null && !name.startsWith("xmlns")) {
                val points = parseTonePointText(value)
                if (points.isNotEmpty()) return points
            }
        }

        val depth = parser.depth
        val buffer = StringBuilder()
        var event = parser.next()
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.TEXT, XmlPullParser.CDSECT ->
                    buffer.append(parser.text)
                XmlPullParser.START_TAG -> {
                    val tag = parser.name
                    if (tag == "li" || tag == "rdf:li" || tag.endsWith(":li")) {
                        val liText = readTextUntilTagEnd(parser)
                        buffer.append(' ').append(liText)
                    }
                }
                XmlPullParser.END_TAG -> {
                    if (parser.depth < depth) break
                }
            }
            event = parser.next()
        }
        return parseTonePointText(buffer.toString())
    }

    private fun readTextUntilTagEnd(parser: XmlPullParser): String {
        val depth = parser.depth
        val sb = StringBuilder()
        var event = parser.next()
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.TEXT, XmlPullParser.CDSECT -> sb.append(parser.text)
                XmlPullParser.END_TAG -> if (parser.depth < depth) return sb.toString().trim()
            }
            event = parser.next()
        }
        return sb.toString().trim()
    }

    // -------------------------------------------------------------------------
    // Tone curve text parsing
    // -------------------------------------------------------------------------

    /** Parses "0, 0 128, 128" or "0,0, 255,255" into [TonePoint] pairs. */
    @JvmStatic
    fun parseTonePointText(raw: String): List<TonePoint> {
        if (raw.isBlank()) return emptyList()
        val tokens = raw.split(',', ' ', '\n', '\r', '\t')
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        if (tokens.size < 2) return emptyList()

        val points = mutableListOf<TonePoint>()
        var i = 0
        while (i + 1 < tokens.size) {
            val x = tokens[i].toIntOrNull() ?: break
            val y = tokens[i + 1].toIntOrNull() ?: break
            points.add(TonePoint(x.coerceIn(0, 255), y.coerceIn(0, 255)))
            i += 2
        }
        return points
    }

    // -------------------------------------------------------------------------
    // Attribute → LightroomPreset mapping
    // -------------------------------------------------------------------------

    private fun buildPreset(
        attrs: Map<String, String>,
        curveLists: Map<String, List<TonePoint>>,
    ): LightroomPreset {
        val extra = mutableMapOf<String, String>()
        val known = KNOWN_CRS_KEYS

        attrs.forEach { (key, value) ->
            if (key !in known) extra[key] = value
        }

        fun curve(key: String): List<TonePoint> =
            curveLists[key] ?: parseTonePointText(attrs[key].orEmpty())

        val detail = DetailSettings(
            sharpness = attrs.int("Sharpness"),
            sharpnessRadius = attrs.float("SharpenRadius", 1f),
            sharpnessDetail = attrs.int("SharpenDetail"),
            sharpnessEdgeMasking = attrs.int("SharpenEdgeMasking"),
            luminanceSmoothing = attrs.int("LuminanceSmoothing"),
            luminanceNoiseReductionDetail = attrs.int("LuminanceNoiseReductionDetail"),
            luminanceNoiseReductionContrast = attrs.int("LuminanceNoiseReductionContrast"),
            colorNoiseReduction = attrs.int("ColorNoiseReduction"),
            colorNoiseReductionDetail = attrs.int("ColorNoiseReductionDetail"),
            colorNoiseReductionSmoothness = attrs.int("ColorNoiseReductionSmoothness"),
        )

        val parametric = ParametricTone(
            shadows = attrs.int("ParametricShadows"),
            darks = attrs.int("ParametricDarks"),
            lights = attrs.int("ParametricLights"),
            highlights = attrs.int("ParametricHighlights"),
            shadowSplit = attrs.int("ParametricShadowSplit", 25),
            midtoneSplit = attrs.int("ParametricMidtoneSplit", 50),
            highlightSplit = attrs.int("ParametricHighlightSplit", 75),
        )

        val toneCurves = ToneCurveSettings(
            toneCurveName = attrs.string("ToneCurveName"),
            toneCurveName2012 = attrs.string("ToneCurveName2012"),
            toneCurve = curve("ToneCurve"),
            toneCurveRed = curve("ToneCurveRed"),
            toneCurveGreen = curve("ToneCurveGreen"),
            toneCurveBlue = curve("ToneCurveBlue"),
            toneCurvePv2012 = curve("ToneCurvePV2012"),
            toneCurvePv2012Red = curve("ToneCurvePV2012Red"),
            toneCurvePv2012Green = curve("ToneCurvePV2012Green"),
            toneCurvePv2012Blue = curve("ToneCurvePV2012Blue"),
        )

        val hsl = HslColorMixer(
            red = attrs.hslChannel("Red"),
            orange = attrs.hslChannel("Orange"),
            yellow = attrs.hslChannel("Yellow"),
            green = attrs.hslChannel("Green"),
            aqua = attrs.hslChannel("Aqua"),
            blue = attrs.hslChannel("Blue"),
            purple = attrs.hslChannel("Purple"),
            magenta = attrs.hslChannel("Magenta"),
        )

        val grayMixer = GrayMixer(
            red = attrs.int("GrayMixerRed"),
            orange = attrs.int("GrayMixerOrange"),
            yellow = attrs.int("GrayMixerYellow"),
            green = attrs.int("GrayMixerGreen"),
            aqua = attrs.int("GrayMixerAqua"),
            blue = attrs.int("GrayMixerBlue"),
            purple = attrs.int("GrayMixerPurple"),
            magenta = attrs.int("GrayMixerMagenta"),
        )

        val splitToning = SplitToning(
            shadowHue = attrs.int("SplitToningShadowHue"),
            shadowSaturation = attrs.int("SplitToningShadowSaturation"),
            highlightHue = attrs.int("SplitToningHighlightHue"),
            highlightSaturation = attrs.int("SplitToningHighlightSaturation"),
            balance = attrs.int("SplitToningBalance"),
        )

        val colorGrading = ColorGradingSettings(
            splitToning = splitToning,
            shadows = ColorGradeZone(
                hue = attrs.int("ColorGradeShadowHue", splitToning.shadowHue),
                saturation = attrs.int("ColorGradeShadowSat", splitToning.shadowSaturation),
                luminance = attrs.int("ColorGradeShadowLum"),
            ),
            midtones = ColorGradeZone(
                hue = attrs.int("ColorGradeMidtoneHue"),
                saturation = attrs.int("ColorGradeMidtoneSat"),
                luminance = attrs.int("ColorGradeMidtoneLum"),
            ),
            highlights = ColorGradeZone(
                hue = attrs.int("ColorGradeHighlightHue", splitToning.highlightHue),
                saturation = attrs.int("ColorGradeHighlightSat", splitToning.highlightSaturation),
                luminance = attrs.int("ColorGradeHighlightLum"),
            ),
            global = ColorGradeZone(
                hue = attrs.int("ColorGradeGlobalHue"),
                saturation = attrs.int("ColorGradeGlobalSat"),
                luminance = attrs.int("ColorGradeGlobalLum"),
            ),
            blending = attrs.int("ColorGradeBlending", 50),
            balance = attrs.int("ColorGradeBalance", splitToning.balance),
        )

        val lens = LensCorrectionSettings(
            lensProfileEnable = attrs.int("LensProfileEnable"),
            lensProfileSetup = attrs.string("LensProfileSetup"),
            lensProfileName = attrs.string("LensProfileName"),
            lensProfileFilename = attrs.string("LensProfileFilename"),
            lensProfileDigest = attrs.string("LensProfileDigest"),
            lensProfileDistortionScale = attrs.int("LensProfileDistortionScale", 100),
            lensProfileChromaticAberrationScale = attrs.int("LensProfileChromaticAberrationScale", 100),
            lensProfileVignettingScale = attrs.int("LensProfileVignettingScale", 100),
            distortionCorrection = attrs.int("LensManualDistortionAmount"),
            chromaticAberrationR = attrs.int("ChromaticAberrationR"),
            chromaticAberrationB = attrs.int("ChromaticAberrationB"),
            autoLateralCA = attrs.int("AutoLateralCA"),
            defringe = attrs.int("Defringe"),
            defringePurpleAmount = attrs.int("DefringePurpleAmount"),
            defringePurpleHueLo = attrs.int("DefringePurpleHueLo"),
            defringePurpleHueHi = attrs.int("DefringePurpleHueHi"),
            defringeGreenAmount = attrs.int("DefringeGreenAmount"),
            defringeGreenHueLo = attrs.int("DefringeGreenHueLo"),
            defringeGreenHueHi = attrs.int("DefringeGreenHueHi"),
            vignetteAmount = attrs.int("VignetteAmount"),
            vignetteMidpoint = attrs.int("VignetteMidpoint", 50),
            postCropVignetteAmount = attrs.int("PostCropVignetteAmount"),
            postCropVignetteMidpoint = attrs.int("PostCropVignetteMidpoint", 50),
            postCropVignetteFeather = attrs.int("PostCropVignetteFeather", 50),
            postCropVignetteRoundness = attrs.int("PostCropVignetteRoundness"),
            postCropVignetteStyle = attrs.int("PostCropVignetteStyle"),
            postCropVignetteHighlightContrast = attrs.int("PostCropVignetteHighlightContrast"),
            perspectiveVertical = attrs.int("PerspectiveVertical"),
            perspectiveHorizontal = attrs.int("PerspectiveHorizontal"),
            perspectiveRotate = attrs.float("PerspectiveRotate"),
            perspectiveScale = attrs.int("PerspectiveScale", 100),
            perspectiveAspect = attrs.int("PerspectiveAspect"),
            perspectiveUpright = attrs.int("PerspectiveUpright"),
            uprightVersion = attrs.int("UprightVersion"),
        )

        val crop = CropSettings(
            hasCrop = attrs.bool("HasCrop"),
            cropTop = attrs.float("CropTop"),
            cropLeft = attrs.float("CropLeft"),
            cropBottom = attrs.float("CropBottom", 1f),
            cropRight = attrs.float("CropRight", 1f),
            cropWidth = attrs.float("CropWidth"),
            cropHeight = attrs.float("CropHeight"),
            cropAngle = attrs.float("CropAngle"),
            cropUnits = attrs.int("CropUnits"),
            cropConstrainToWarp = attrs.int("CropConstrainToWarp"),
        )

        return LightroomPreset(
            version = attrs.string("Version"),
            processVersion = attrs.string("ProcessVersion"),
            cameraProfile = attrs.string("CameraProfile"),
            cameraProfileDigest = attrs.string("CameraProfileDigest"),
            whiteBalance = attrs.string("WhiteBalance"),
            alreadyApplied = attrs.bool("AlreadyApplied"),
            hasSettings = attrs.bool("HasSettings", default = true),
            convertToGrayscale = attrs.bool("ConvertToGrayscale"),
            exposure2012 = attrs.float("Exposure2012"),
            contrast2012 = attrs.int("Contrast2012"),
            highlights2012 = attrs.int("Highlights2012"),
            shadows2012 = attrs.int("Shadows2012"),
            whites2012 = attrs.int("Whites2012"),
            blacks2012 = attrs.int("Blacks2012"),
            exposure = attrs.float("Exposure"),
            contrast = attrs.int("Contrast"),
            shadows = attrs.int("Shadows"),
            brightness = attrs.int("Brightness"),
            fillLight = attrs.int("FillLight"),
            highlightRecovery = attrs.int("HighlightRecovery"),
            temperature = attrs.int("Temperature"),
            tint = attrs.int("Tint"),
            incrementalTemperature = attrs.int("IncrementalTemperature"),
            incrementalTint = attrs.int("IncrementalTint"),
            vibrance = attrs.int("Vibrance"),
            saturation = attrs.int("Saturation"),
            clarity2012 = attrs.int("Clarity2012"),
            clarity = attrs.int("Clarity"),
            dehaze = attrs.int("Dehaze"),
            texture = attrs.int("Texture"),
            detail = detail,
            parametric = parametric,
            toneCurves = toneCurves,
            hsl = hsl,
            grayMixer = grayMixer,
            colorGrading = colorGrading,
            lens = lens,
            crop = crop,
            autoExposure = attrs.bool("AutoExposure"),
            autoContrast = attrs.bool("AutoContrast"),
            autoBrightness = attrs.bool("AutoBrightness"),
            autoShadows = attrs.bool("AutoShadows"),
            extraCrsAttributes = extra,
        )
    }

    // -------------------------------------------------------------------------
    // Typed accessors
    // -------------------------------------------------------------------------

    private fun Map<String, String>.string(key: String, default: String = ""): String =
        this[key]?.trim().orEmpty().ifEmpty { default }

    private fun Map<String, String>.int(key: String, default: Int = 0): Int =
        this[key]?.cleanNumeric()?.toIntOrNull() ?: default

    private fun Map<String, String>.float(key: String, default: Float = 0f): Float =
        this[key]?.cleanNumeric()?.toFloatOrNull() ?: default

    private fun Map<String, String>.bool(key: String, default: Boolean = false): Boolean {
        val raw = this[key]?.trim()?.lowercase() ?: return default
        return when (raw) {
            "true", "1", "yes" -> true
            "false", "0", "no" -> false
            else -> default
        }
    }

    private fun Map<String, String>.hslChannel(color: String): HslChannel = HslChannel(
        hue = int("HueAdjustment$color"),
        saturation = int("SaturationAdjustment$color"),
        luminance = int("LuminanceAdjustment$color"),
    )

    private fun String.cleanNumeric(): String =
        trim().removePrefix("+").replace(',', '.')

    /** Every structured crs key consumed by [buildPreset]; remainder → [LightroomPreset.extraCrsAttributes]. */
    private val KNOWN_CRS_KEYS: Set<String> = setOf(
        // Metadata
        "Version", "ProcessVersion", "CameraProfile", "CameraProfileDigest", "WhiteBalance",
        "AlreadyApplied", "HasSettings", "ConvertToGrayscale", "RawFileName", "HasCrop",
        // Basic 2012
        "Exposure2012", "Contrast2012", "Highlights2012", "Shadows2012", "Whites2012", "Blacks2012",
        // Legacy basic
        "Exposure", "Contrast", "Shadows", "Brightness", "FillLight", "HighlightRecovery",
        // WB & color
        "Temperature", "Tint", "IncrementalTemperature", "IncrementalTint", "Vibrance", "Saturation",
        // Presence
        "Clarity2012", "Clarity", "Dehaze", "Texture",
        // Detail
        "Sharpness", "SharpenRadius", "SharpenDetail", "SharpenEdgeMasking",
        "LuminanceSmoothing", "LuminanceNoiseReductionDetail", "LuminanceNoiseReductionContrast",
        "ColorNoiseReduction", "ColorNoiseReductionDetail", "ColorNoiseReductionSmoothness",
        // Parametric
        "ParametricShadows", "ParametricDarks", "ParametricLights", "ParametricHighlights",
        "ParametricShadowSplit", "ParametricMidtoneSplit", "ParametricHighlightSplit",
        // Tone curves
        "ToneCurveName", "ToneCurveName2012",
        "ToneCurve", "ToneCurveRed", "ToneCurveGreen", "ToneCurveBlue",
        "ToneCurvePV2012", "ToneCurvePV2012Red", "ToneCurvePV2012Green", "ToneCurvePV2012Blue",
        // HSL
        "HueAdjustmentRed", "HueAdjustmentOrange", "HueAdjustmentYellow", "HueAdjustmentGreen",
        "HueAdjustmentAqua", "HueAdjustmentBlue", "HueAdjustmentPurple", "HueAdjustmentMagenta",
        "SaturationAdjustmentRed", "SaturationAdjustmentOrange", "SaturationAdjustmentYellow",
        "SaturationAdjustmentGreen", "SaturationAdjustmentAqua", "SaturationAdjustmentBlue",
        "SaturationAdjustmentPurple", "SaturationAdjustmentMagenta",
        "LuminanceAdjustmentRed", "LuminanceAdjustmentOrange", "LuminanceAdjustmentYellow",
        "LuminanceAdjustmentGreen", "LuminanceAdjustmentAqua", "LuminanceAdjustmentBlue",
        "LuminanceAdjustmentPurple", "LuminanceAdjustmentMagenta",
        // Gray mixer
        "GrayMixerRed", "GrayMixerOrange", "GrayMixerYellow", "GrayMixerGreen",
        "GrayMixerAqua", "GrayMixerBlue", "GrayMixerPurple", "GrayMixerMagenta",
        // Split toning / color grading
        "SplitToningShadowHue", "SplitToningShadowSaturation", "SplitToningHighlightHue",
        "SplitToningHighlightSaturation", "SplitToningBalance",
        "ColorGradeShadowHue", "ColorGradeShadowSat", "ColorGradeShadowLum",
        "ColorGradeMidtoneHue", "ColorGradeMidtoneSat", "ColorGradeMidtoneLum",
        "ColorGradeHighlightHue", "ColorGradeHighlightSat", "ColorGradeHighlightLum",
        "ColorGradeGlobalHue", "ColorGradeGlobalSat", "ColorGradeGlobalLum",
        "ColorGradeBlending", "ColorGradeBalance",
        // Lens / vignette / perspective
        "LensProfileEnable", "LensProfileSetup", "LensProfileName", "LensProfileFilename",
        "LensProfileDigest", "LensProfileDistortionScale", "LensProfileChromaticAberrationScale",
        "LensProfileVignettingScale", "LensManualDistortionAmount",
        "ChromaticAberrationR", "ChromaticAberrationB", "AutoLateralCA", "Defringe",
        "DefringePurpleAmount", "DefringePurpleHueLo", "DefringePurpleHueHi",
        "DefringeGreenAmount", "DefringeGreenHueLo", "DefringeGreenHueHi",
        "VignetteAmount", "VignetteMidpoint",
        "PostCropVignetteAmount", "PostCropVignetteMidpoint", "PostCropVignetteFeather",
        "PostCropVignetteRoundness", "PostCropVignetteStyle", "PostCropVignetteHighlightContrast",
        "PerspectiveVertical", "PerspectiveHorizontal", "PerspectiveRotate", "PerspectiveScale",
        "PerspectiveAspect", "PerspectiveUpright", "UprightVersion",
        // Crop
        "CropTop", "CropLeft", "CropBottom", "CropRight", "CropWidth", "CropHeight",
        "CropAngle", "CropUnits", "CropConstrainToWarp",
        // Auto flags
        "AutoExposure", "AutoContrast", "AutoBrightness", "AutoShadows",
    )
}

/** Thrown when XMP is malformed or not readable. */
class XmpParseException(message: String, cause: Throwable? = null) :
    Exception(message, cause)
