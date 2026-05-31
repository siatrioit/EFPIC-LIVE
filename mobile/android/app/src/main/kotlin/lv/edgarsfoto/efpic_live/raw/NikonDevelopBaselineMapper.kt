package lv.edgarsfoto.efpic_live.raw

/**
 * Nikon → Lightroom-style develop baseline (matches Dart [NikonCameraSettingsMapper]).
 * Separates compensation dial from develop EV (ADL).
 */
object NikonDevelopBaselineMapper {

    private data class AdlTone(
        val exposureEv: Float = 0f,
        val highlights: Float = 0f,
        val shadows: Float = 0f,
    )

    private val adlByCode = mapOf(
        0 to AdlTone(),
        1 to AdlTone(highlights = -7f, shadows = 10f),
        3 to AdlTone(exposureEv = 0.33f, highlights = -21f, shadows = 10f),
        5 to AdlTone(exposureEv = 0.67f, highlights = -35f, shadows = 10f),
        7 to AdlTone(exposureEv = 1f, highlights = -49f, shadows = 10f),
        8 to AdlTone(exposureEv = 1f, highlights = -49f, shadows = 10f),
    )

    @JvmStatic
    fun apply(raw: CameraBaseline, adlCode: Int?, compensationEv: Float): CameraBaseline {
        if (raw.usedFallback) return raw
        val adl = adlCode?.let { adlByCode[it] } ?: AdlTone()
        val sources = raw.sources.toMutableList()
        if (adlCode != null) sources.add("kotlin:ActiveDLighting($adlCode)")
        return raw.copy(
            exposureEv = adl.exposureEv,
            highlights = adl.highlights,
            shadows = raw.shadows + adl.shadows,
            sources = sources,
        )
    }
}
