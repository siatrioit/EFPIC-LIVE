package lv.edgarsfoto.efpic_live.raw.develop

/**
 * Fāze 3 — eksporta veiktspēja (mozaīkas, GPU kompozīcija).
 */
object DevelopOptions {
    /** Mozaīkas eksports pilnai izšķirtspējai (Z8 NEF u.c.). */
    @Volatile
    var tiledExportEnabled: Boolean = true

    /** Hardware-accelerated Canvas, kad liek mozaīkas uz galīgā Bitmap. */
    @Volatile
    var useGpuTileBlit: Boolean = true
}
