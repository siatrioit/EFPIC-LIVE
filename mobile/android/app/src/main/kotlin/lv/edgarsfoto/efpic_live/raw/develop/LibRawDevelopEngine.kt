package lv.edgarsfoto.efpic_live.raw.develop

import lv.edgarsfoto.efpic_live.raw.EditSessionState

/**
 * Fāze 2: demosaic NEF/ARW/CR2 via LibRaw (NDK) → [EditDevelopPipeline] with
 * [useEmbeddedProxyMode] = false.
 *
 * Not linked yet — [RawDevelopCoordinator] uses [EmbeddedProxyDevelopEngine].
 */
@Suppress("unused")
class LibRawDevelopEngine : RawDevelopEngine {
    override fun develop(
        session: EditSessionState,
        maxLongEdge: Int,
        jpegQuality: Int,
    ): RawDevelopEngine.DevelopResult {
        throw UnsupportedOperationException(
            "LibRaw NDK not integrated — see docs/RAW_DEVELOP.md Fāze 2",
        )
    }
}
