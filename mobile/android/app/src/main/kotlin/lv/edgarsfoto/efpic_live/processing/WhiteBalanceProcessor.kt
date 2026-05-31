package lv.edgarsfoto.efpic_live.processing

/**
 * Real-time white balance on scene-linear [LinearImage] using precomputed [WhiteBalanceMath.RgbGains].
 */
object WhiteBalanceProcessor {

    @JvmStatic
    fun applyDelta(image: LinearImage, delta: WhiteBalanceMath.RgbGains) {
        if (delta.isNeutral()) return
        val dr = delta.r
        val dg = delta.g
        val db = delta.b
        image.mapPixelsParallel { r, g, b ->
            WhiteBalanceMath.applyDiagonalGains(r, g, b, WhiteBalanceMath.RgbGains(dr, dg, db))
        }
    }

    @JvmStatic
    fun applyAbsolute(image: LinearImage, kelvin: Float, tint: Float) {
        val gains = WhiteBalanceMath.vonKriesGains(kelvin, tint)
        if (gains.isNeutral()) return
        image.mapPixelsParallel { r, g, b ->
            WhiteBalanceMath.applyDiagonalGains(r, g, b, gains)
        }
    }
}
