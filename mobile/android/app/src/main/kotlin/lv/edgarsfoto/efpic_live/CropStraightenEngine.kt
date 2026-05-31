package lv.edgarsfoto.efpic_live

import android.graphics.Matrix
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * Lightroom-style crop / straighten math (matrix-based).
 *
 * **Auto-zoom to cover crop** at rotation θ (degrees):
 * Let image size (W,H), crop size (Cw,Ch). Rotated axis-aligned bounds:
 *   Bw = W·|cos θ| + H·|sin θ|
 *   Bh = W·|sin θ| + H·|cos θ|
 * Minimum uniform scale so crop has no empty corners:
 *   s_min = max(Cw / Bw, Ch / Bh)
 *
 * Combined user scale: s = s_min × userScale (userScale ≥ 1).
 */
object CropStraightenEngine {

    const val STRAIGHTEN_MIN = -45f
    const val STRAIGHTEN_MAX = 45f

    data class CropTransformMetadata(
        val cropLeftNorm: Float,
        val cropTopNorm: Float,
        val cropWidthNorm: Float,
        val cropHeightNorm: Float,
        val rotationQuarterTurns: Int,
        val rotationFineDegrees: Float,
        val panXNorm: Float,
        val panYNorm: Float,
        val userScale: Float,
        val lockedAspect: Float?,
    )

    enum class GridMode { RULE_OF_THIRDS, FINE_STRAIGHTEN, HIDDEN }

    /** Aspect presets (width / height). */
    object AspectRatios {
        const val FREE = -1.0
        const val ORIGINAL = 0.0
        const val SQUARE = 1.0
        const val RATIO_4_5 = 4.0 / 5.0
        const val RATIO_8_5_11 = 8.5 / 11.0
        const val RATIO_2_3 = 2.0 / 3.0
        const val RATIO_16_9 = 16.0 / 9.0
    }

    /**
     * Minimum uniform scale to cover crop rectangle after rotation [thetaDeg].
     */
    @JvmStatic
    fun minCoverScale(
        imageWidth: Float,
        imageHeight: Float,
        cropWidth: Float,
        cropHeight: Float,
        thetaDeg: Float,
    ): Float {
        if (imageWidth <= 0f || imageHeight <= 0f) return 1f
        val theta = Math.toRadians(thetaDeg.toDouble())
        val c = abs(cos(theta)).toFloat()
        val s = abs(sin(theta)).toFloat()
        val boundW = imageWidth * c + imageHeight * s
        val boundH = imageWidth * s + imageHeight * c
        if (boundW <= 0f || boundH <= 0f) return 1f
        return max(cropWidth / boundW, cropHeight / boundH)
    }

    /** Total scale = auto × user (user must be ≥ 1 so image never shrinks below cover). */
    @JvmStatic
    fun totalScale(
        imageWidth: Float,
        imageHeight: Float,
        cropWidth: Float,
        cropHeight: Float,
        thetaDeg: Float,
        userScale: Float,
    ): Float {
        val auto = minCoverScale(imageWidth, imageHeight, cropWidth, cropHeight, thetaDeg)
        return auto * userScale.coerceAtLeast(1f)
    }

    /**
     * Build image transform: center → rotate → scale → pan (crop space pixels).
     */
    @JvmStatic
    fun buildImageMatrix(
        imageWidth: Float,
        imageHeight: Float,
        cropCenterX: Float,
        cropCenterY: Float,
        thetaDeg: Float,
        userScale: Float,
        cropWidth: Float,
        cropHeight: Float,
        panX: Float,
        panY: Float,
        out: Matrix,
    ) {
        out.reset()
        val scale = totalScale(imageWidth, imageHeight, cropWidth, cropHeight, thetaDeg, userScale)
        out.postTranslate(-imageWidth / 2f, -imageHeight / 2f)
        out.postRotate(thetaDeg)
        out.postScale(scale, scale)
        out.postTranslate(cropCenterX + panX, cropCenterY + panY)
    }

    /** After ±90° CW, swap locked aspect (2:3 → 3:2). */
    @JvmStatic
    fun swapAspectForQuarterTurn(aspect: Float): Float =
        if (aspect > 0f) 1f / aspect else aspect

    @JvmStatic
    fun rotate90Clockwise(quarterTurns: Int): Int = (quarterTurns + 1) and 3

    @JvmStatic
    fun rotate90CounterClockwise(quarterTurns: Int): Int = (quarterTurns + 3) and 3

    /**
     * Rubber-band: if projected image rect smaller than crop, snap pan back.
     * Returns corrected (panX, panY).
     */
    @JvmStatic
    fun enforcePanBounds(
        imageWidth: Float,
        imageHeight: Float,
        cropWidth: Float,
        cropHeight: Float,
        thetaDeg: Float,
        userScale: Float,
        panX: Float,
        panY: Float,
    ): Pair<Float, Float> {
        val scale = totalScale(imageWidth, imageHeight, cropWidth, cropHeight, thetaDeg, userScale)
        val theta = Math.toRadians(thetaDeg.toDouble())
        val c = abs(cos(theta)).toFloat()
        val s = abs(sin(theta)).toFloat()
        val scaledW = imageWidth * scale
        val scaledH = imageHeight * scale
        val boundW = scaledW * c + scaledH * s
        val boundH = scaledW * s + scaledH * c
        val maxPanX = max(0f, (boundW - cropWidth) / 2f)
        val maxPanY = max(0f, (boundH - cropHeight) / 2f)
        return panX.coerceIn(-maxPanX, maxPanX) to panY.coerceIn(-maxPanY, maxPanY)
    }
}
