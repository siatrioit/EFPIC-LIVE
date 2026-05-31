package lv.edgarsfoto.efpic_live.raw.develop

import android.util.Log
import lv.edgarsfoto.efpic_live.raw.EditSessionState

/**
 * Fāze 2: demosaic via LibRaw → [EditDevelopPipeline] (absolute tones on sensor data).
 */
class LibRawDevelopEngine : RawDevelopEngine {

    override fun develop(
        session: EditSessionState,
        maxLongEdge: Int,
        jpegQuality: Int,
    ): RawDevelopEngine.DevelopResult {
        if (!LibRawSupport.isLinked()) {
            throw UnsupportedOperationException("LibRaw native library not loaded")
        }
        if (maxLongEdge == 0 && TiledLibRawDevelopEngine.shouldUseTiles(session)) {
            return TiledLibRawDevelopEngine.develop(session, jpegQuality)
        }
        val half = LibRawSupport.halfSizeForMaxEdge(maxLongEdge)
        val linear = LibRawSupport.demosaicToLinear(
            session.rawPath,
            half,
            session.cameraBaseline,
        )
        val w = linear.width
        val h = linear.height

        EditDevelopPipeline.apply(linear, session, useEmbeddedProxyMode = false)

        val jpeg = DevelopBitmapUtils.encodeJpeg(linear, w, h, jpegQuality)
        Log.d(TAG, "develop libraw ${session.rawPath} ${w}x$h half=$half q=$jpegQuality")
        return RawDevelopEngine.DevelopResult(
            jpegBytes = jpeg,
            width = w,
            height = h,
            sourceLabel = "libraw_demosaic",
        )
    }

    companion object {
        private const val TAG = "LibRawDevelop"
    }
}
