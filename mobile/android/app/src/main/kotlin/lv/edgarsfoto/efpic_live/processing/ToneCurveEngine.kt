package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.LightroomPreset
import lv.edgarsfoto.efpic_live.xmp.TonePoint

/**
 * Applies parametric + point-based RGB tone curves via precomputed cubic spline LUTs.
 */
object ToneCurveEngine {

    data class CurveState(
        val masterLut: FloatArray,
        val redLut: FloatArray,
        val greenLut: FloatArray,
        val blueLut: FloatArray,
        val active: Boolean,
    ) {
        override fun equals(other: Any?): Boolean = other is CurveState &&
            masterLut.contentEquals(other.masterLut) &&
            redLut.contentEquals(other.redLut) &&
            greenLut.contentEquals(other.greenLut) &&
            blueLut.contentEquals(other.blueLut) &&
            active == other.active

        override fun hashCode(): Int = masterLut.contentHashCode()

        companion object {
            fun fromPreset(p: LightroomPreset): CurveState {
                val tc = p.toneCurves
                val par = p.parametric

                // Prefer PV2012 curves; fall back to legacy.
                val masterPoints = pickPoints(tc.toneCurvePv2012, tc.toneCurve)
                val redPoints = pickPoints(tc.toneCurvePv2012Red, tc.toneCurveRed)
                val greenPoints = pickPoints(tc.toneCurvePv2012Green, tc.toneCurveGreen)
                val bluePoints = pickPoints(tc.toneCurvePv2012Blue, tc.toneCurveBlue)

                var masterLut = CubicSplineLut.fromTonePoints(masterPoints)
                val paramLut = CubicSplineLut.parametricLut(
                    par.shadows, par.darks, par.lights, par.highlights,
                    par.shadowSplit, par.midtoneSplit, par.highlightSplit,
                )
                if (!CubicSplineLut.isIdentity(paramLut)) {
                    masterLut = composeLuts(paramLut, masterLut)
                }

                val redLut = CubicSplineLut.fromTonePoints(redPoints)
                val greenLut = CubicSplineLut.fromTonePoints(greenPoints)
                val blueLut = CubicSplineLut.fromTonePoints(bluePoints)

                val active = !CubicSplineLut.isIdentity(masterLut) ||
                    !CubicSplineLut.isIdentity(redLut) ||
                    !CubicSplineLut.isIdentity(greenLut) ||
                    !CubicSplineLut.isIdentity(blueLut)

                return CurveState(masterLut, redLut, greenLut, blueLut, active)
            }

            private fun pickPoints(primary: List<TonePoint>, fallback: List<TonePoint>): List<TonePoint> =
                if (primary.isNotEmpty()) primary else fallback

            private fun composeLuts(a: FloatArray, b: FloatArray): FloatArray {
                if (CubicSplineLut.isIdentity(a)) return b
                if (CubicSplineLut.isIdentity(b)) return a
                return FloatArray(256) { i ->
                    val mid = (a[i] * 255f + 0.5f).toInt().coerceIn(0, 255)
                    b[mid]
                }
            }
        }
    }

    @JvmStatic
    fun apply(r: Float, g: Float, b: Float, state: CurveState): Triple<Float, Float, Float> {
        if (!state.active) return Triple(r, g, b)
        val master = if (CubicSplineLut.isIdentity(state.masterLut)) null else state.masterLut
        return CubicSplineLut.applyRgbLuts(
            r, g, b,
            state.redLut, state.greenLut, state.blueLut,
            master,
        )
    }
}
