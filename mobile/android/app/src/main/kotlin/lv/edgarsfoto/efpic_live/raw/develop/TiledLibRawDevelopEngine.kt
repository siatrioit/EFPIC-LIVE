package lv.edgarsfoto.efpic_live.raw.develop

import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.util.Log
import lv.edgarsfoto.efpic_live.raw.EditSessionState

/**
 * Fāze 3: pilnas izšķirtspējas eksports mozaīkās — izvairās no viena ~500MB+ [LinearImage].
 */
object TiledLibRawDevelopEngine {

    const val TILE_SIZE = 1536
    const val TILED_EXPORT_MIN_LONG_EDGE = 4000
    const val TILED_EXPORT_MIN_PIXELS = 14_000_000L

    data class TileRect(val left: Int, val top: Int, val width: Int, val height: Int)

    @JvmStatic
    fun shouldUseTiles(session: EditSessionState): Boolean {
        if (!DevelopOptions.tiledExportEnabled) return false
        val w = session.cameraBaseline.rawWidth
        val h = session.cameraBaseline.rawHeight
        if (w <= 0 || h <= 0) return false
        val longEdge = maxOf(w, h)
        if (longEdge >= TILED_EXPORT_MIN_LONG_EDGE) return true
        return w.toLong() * h >= TILED_EXPORT_MIN_PIXELS
    }

    @JvmStatic
    fun develop(
        session: EditSessionState,
        jpegQuality: Int,
    ): RawDevelopEngine.DevelopResult {
        if (!LibRawSupport.isLinked()) {
            throw UnsupportedOperationException("LibRaw native library not loaded")
        }
        return try {
            developTiled(session, jpegQuality)
        } catch (e: Exception) {
            Log.w(TAG, "tiled export failed, fallback single pass: ${e.message}")
            LibRawDevelopEngine().develop(session, maxLongEdge = 0, jpegQuality)
        }
    }

    private fun developTiled(
        session: EditSessionState,
        jpegQuality: Int,
    ): RawDevelopEngine.DevelopResult {
        val (fullW, fullH) = LibRawSupport.probeOutputDimensions(session.rawPath, halfSize = false)
        if (fullW <= 0 || fullH <= 0) {
            throw IllegalStateException("LibRaw probe failed: ${session.rawPath}")
        }

        val tiles = computeTiles(fullW, fullH, TILE_SIZE)
        val output = Bitmap.createBitmap(fullW, fullH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        if (DevelopOptions.useGpuTileBlit && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            canvas.enableZ()
        }

        Log.d(TAG, "tiled export ${session.rawPath} ${fullW}x$fullH tiles=${tiles.size}")

        try {
            for (tile in tiles) {
                val linear = LibRawSupport.demosaicCropToLinear(
                    rawPath = session.rawPath,
                    halfSize = false,
                    baseline = session.cameraBaseline,
                    cropLeft = tile.left,
                    cropTop = tile.top,
                    cropWidth = tile.width,
                    cropHeight = tile.height,
                )
                EditDevelopPipeline.apply(
                    linear,
                    session,
                    useEmbeddedProxyMode = false,
                    parallel = true,
                )
                val tileBitmap = DevelopBitmapUtils.bitmapFromLinear(linear)
                canvas.drawBitmap(tileBitmap, tile.left.toFloat(), tile.top.toFloat(), null)
                tileBitmap.recycle()
            }
            val jpeg = DevelopBitmapUtils.encodeJpegFromBitmap(output, jpegQuality)
            val gpu = DevelopOptions.useGpuTileBlit && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            val label = if (gpu) "libraw_tiled_demosaic_gpu" else "libraw_tiled_demosaic"
            return RawDevelopEngine.DevelopResult(
                jpegBytes = jpeg,
                width = fullW,
                height = fullH,
                sourceLabel = label,
            )
        } finally {
            output.recycle()
        }
    }

    @JvmStatic
    fun computeTiles(fullW: Int, fullH: Int, tileSize: Int): List<TileRect> {
        val out = ArrayList<TileRect>()
        var y = 0
        while (y < fullH) {
            var x = 0
            while (x < fullW) {
                val w = minOf(tileSize, fullW - x)
                val h = minOf(tileSize, fullH - y)
                out.add(TileRect(x, y, w, h))
                x += tileSize
            }
            y += tileSize
        }
        return out
    }

    private const val TAG = "TiledLibRawDevelop"
}
