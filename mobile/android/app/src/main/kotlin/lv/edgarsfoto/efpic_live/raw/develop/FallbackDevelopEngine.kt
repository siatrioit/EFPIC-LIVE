package lv.edgarsfoto.efpic_live.raw.develop

import android.util.Log
import lv.edgarsfoto.efpic_live.raw.EditSessionState

/**
 * Tries [LibRawDevelopEngine], falls back to [EmbeddedProxyDevelopEngine] on failure.
 */
class FallbackDevelopEngine : RawDevelopEngine {
    private val libRaw = LibRawDevelopEngine()
    private val proxy = EmbeddedProxyDevelopEngine()

    override fun develop(
        session: EditSessionState,
        maxLongEdge: Int,
        jpegQuality: Int,
    ): RawDevelopEngine.DevelopResult {
        if (LibRawSupport.isLinked()) {
            try {
                return libRaw.develop(session, maxLongEdge, jpegQuality)
            } catch (e: Exception) {
                Log.w(TAG, "LibRaw develop failed, using embedded proxy: ${e.message}")
            }
        }
        return proxy.develop(session, maxLongEdge, jpegQuality)
    }

    companion object {
        private const val TAG = "FallbackDevelop"
    }
}
