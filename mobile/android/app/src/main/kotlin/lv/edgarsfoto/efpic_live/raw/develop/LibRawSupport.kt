package lv.edgarsfoto.efpic_live.raw.develop

import android.graphics.Bitmap
import android.system.ErrnoException
import android.util.Log
import com.homesoft.photo.libraw.LibRaw
import lv.edgarsfoto.efpic_live.processing.LinearImage
import lv.edgarsfoto.efpic_live.raw.CameraBaseline
import lv.edgarsfoto.efpic_live.raw.EditSessionState

/**
 * LibRaw demosaic (Fāze 2) — NEF/ARW/CR2 → scene-linear RGB.
 */
object LibRawSupport {
    private const val TAG = "LibRawSupport"

    @Volatile
    private var linked: Boolean? = null

    @JvmStatic
    fun isLinked(): Boolean {
        linked?.let { return it }
        return try {
            LibRaw.newInstance().use { true }
        } catch (t: Throwable) {
            Log.w(TAG, "LibRaw not available: ${t.message}")
            false
        }.also { linked = it }
    }

    /**
     * Demosaic [rawPath] to linear sRGB-ish RGB (LibRaw output + sRGB decode).
     * @param halfSize true for preview (~½ resolution per axis).
     */
    @JvmStatic
    fun demosaicToLinear(
        rawPath: String,
        halfSize: Boolean,
        baseline: CameraBaseline? = null,
    ): LinearImage =
        demosaicCropToLinear(
            rawPath = rawPath,
            halfSize = halfSize,
            baseline = baseline,
            cropLeft = 0,
            cropTop = 0,
            cropWidth = 0,
            cropHeight = 0,
        )

    /**
     * Demosaic pilnu kadru vai [cropWidth]×[cropHeight] apgabalu (0 = pilns kadrs).
     */
    @JvmStatic
    fun demosaicCropToLinear(
        rawPath: String,
        halfSize: Boolean,
        baseline: CameraBaseline?,
        cropLeft: Int,
        cropTop: Int,
        cropWidth: Int,
        cropHeight: Int,
    ): LinearImage {
        LibRaw().use { lib ->
            val rc = lib.open(rawPath)
            if (rc != 0) {
                throw ErrnoException("LibRaw.open", rc)
            }
            configureLibRaw(lib, halfSize, baseline)
            if (cropWidth > 0 && cropHeight > 0) {
                lib.setCropBox(cropLeft, cropTop, cropWidth, cropHeight)
            }
            val proc = lib.dcrawProcess()
            if (proc != 0) {
                throw ErrnoException("LibRaw.dcrawProcess", proc)
            }
            var bitmap = lib.getBitmap()
                ?: throw IllegalStateException("LibRaw.getBitmap returned null")
            if (!bitmap.isMutable) {
                bitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
                    ?: throw IllegalStateException("LibRaw bitmap copy failed")
            }
            return DevelopBitmapUtils.linearFromBitmap(bitmap)
        }
    }

    private fun configureLibRaw(
        lib: LibRaw,
        halfSize: Boolean,
        baseline: CameraBaseline?,
    ) {
        lib.setQuality(3)
        lib.setHalfSize(halfSize)
        lib.setAutoBrightness(true)
        lib.setOutputColorSpace(1) // sRGB
        lib.setUseCameraMatrix(3)
        val b = baseline
        if (b != null && (b.redGain != 1f || b.greenGain != 1f || b.blueGain != 1f)) {
            lib.setAutoWhiteBalance(false)
            lib.setCameraWhiteBalance(false)
            lib.setUserMul(b.redGain, b.greenGain, b.blueGain, b.greenGain)
        } else {
            lib.setAutoWhiteBalance(false)
            lib.setCameraWhiteBalance(true)
        }
    }

    @JvmStatic
    fun halfSizeForMaxEdge(maxLongEdge: Int): Boolean =
        maxLongEdge > 0 && maxLongEdge <= RawDevelopCoordinator.PREVIEW_MAX_LONG_EDGE
}
