package lv.edgarsfoto.efpic_live.raw.develop

import lv.edgarsfoto.efpic_live.raw.EditSessionState

/**
 * Lightroom-style develop: one engine, preview + export differ only by resolution.
 *
 * @param maxLongEdge 0 = no downscale (export); else longest edge cap (preview).
 */
interface RawDevelopEngine {
    data class DevelopResult(
        val jpegBytes: ByteArray,
        val width: Int,
        val height: Int,
        val sourceLabel: String,
    )

    fun develop(session: EditSessionState, maxLongEdge: Int, jpegQuality: Int): DevelopResult
}
