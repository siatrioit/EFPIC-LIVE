package lv.edgarsfoto.efpic_live.raw

import lv.edgarsfoto.efpic_live.processing.LinearImage

/**
 * Approximate color-space / Picture Control matrices (sensor → display linear).
 * Full ICC would be ideal; these are heuristic 3×3 RGB transforms.
 */
object ColorProfileMatrix {
    private val IDENTITY = floatArrayOf(
        1f, 0f, 0f,
        0f, 1f, 0f,
        0f, 0f, 1f,
    )

    private val ADOBE_RGB = floatArrayOf(
        1.02f, -0.01f, 0f,
        -0.01f, 1.01f, 0f,
        0f, -0.02f, 1.03f,
    )

    fun forProfile(
        space: CameraBaseline.ColorSpace,
        pictureControl: String?,
    ): FloatArray {
        var m = when (space) {
            CameraBaseline.ColorSpace.ADOBE_RGB -> ADOBE_RGB
            else -> IDENTITY
        }
        val pc = pictureControl?.lowercase() ?: return m
        val tint = when {
            pc.contains("portrait") -> portraitMatrix()
            pc.contains("landscape") -> landscapeMatrix()
            pc.contains("vivid") || pc.contains("vi") -> vividMatrix()
            pc.contains("neutral") -> neutralMatrix()
            pc.contains("flat") -> flatMatrix()
            else -> IDENTITY
        }
        return multiply(m, tint)
    }

    private fun portraitMatrix() = floatArrayOf(
        1.02f, 0.02f, 0f,
        0.01f, 0.98f, 0.01f,
        0f, 0.01f, 1.01f,
    )

    private fun landscapeMatrix() = floatArrayOf(
        0.98f, 0f, 0.02f,
        0f, 1.02f, 0f,
        0.01f, 0.01f, 1.04f,
    )

    private fun vividMatrix() = floatArrayOf(
        1.08f, -0.02f, 0f,
        -0.02f, 1.06f, -0.02f,
        0f, -0.02f, 1.08f,
    )

    private fun neutralMatrix() = floatArrayOf(
        1f, 0f, 0f,
        0f, 1f, 0f,
        0f, 0f, 1f,
    )

    private fun flatMatrix() = floatArrayOf(
        0.96f, 0.02f, 0.02f,
        0.02f, 0.96f, 0.02f,
        0.02f, 0.02f, 0.96f,
    )

    /** Heuristiska 3×3 uz scene-linear RGB (Fāze 3 — Picture Control). */
    @JvmStatic
    fun applyToLinear(image: LinearImage, matrix: FloatArray) {
        if (matrix.size != 9 || isIdentity(matrix)) return
        image.mapPixelsParallel { r, g, b ->
            Triple(
                matrix[0] * r + matrix[1] * g + matrix[2] * b,
                matrix[3] * r + matrix[4] * g + matrix[5] * b,
                matrix[6] * r + matrix[7] * g + matrix[8] * b,
            )
        }
    }

    private fun isIdentity(m: FloatArray): Boolean {
        for (i in m.indices) {
            if (kotlin.math.abs(m[i] - IDENTITY[i]) > 0.001f) return false
        }
        return true
    }

    private fun multiply(a: FloatArray, b: FloatArray): FloatArray {
        val out = FloatArray(9)
        for (row in 0..2) {
            for (col in 0..2) {
                var sum = 0f
                for (k in 0..2) {
                    sum += a[row * 3 + k] * b[k * 3 + col]
                }
                out[row * 3 + col] = sum
            }
        }
        return out
    }
}
