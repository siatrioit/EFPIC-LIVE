package lv.edgarsfoto.efpic_live.processing

/**
 * Scene-linear RGB image buffer (interleaved R,G,B in 0…1).
 * Alpha is not processed; callers encode/decode separately.
 */
class LinearImage(
    val width: Int,
    val height: Int,
    pixels: FloatArray? = null,
) {
    val pixels: FloatArray = pixels ?: FloatArray(width * height * 3)

    init {
        require(width > 0 && height > 0)
        require(this.pixels.size == width * height * 3)
    }

    val pixelCount: Int get() = width * height

    inline fun forEachPixel(block: (index: Int, r: Float, g: Float, b: Float) -> Unit) {
        var i = 0
        val px = pixels
        val end = px.size
        while (i < end) {
            block(i / 3, px[i], px[i + 1], px[i + 2])
            i += 3
        }
    }

    inline fun mapPixels(block: (r: Float, g: Float, b: Float) -> Triple<Float, Float, Float>) {
        val px = pixels
        var i = 0
        while (i < px.size) {
            val (nr, ng, nb) = block(px[i], px[i + 1], px[i + 2])
            px[i] = nr
            px[i + 1] = ng
            px[i + 2] = nb
            i += 3
        }
    }

    /** Process rows in parallel (Android API 24+). */
    fun mapPixelsParallel(block: (r: Float, g: Float, b: Float) -> Triple<Float, Float, Float>) {
        val rows = height
        val px = pixels
        val stride = width * 3
        (0 until rows).toList().parallelStream().forEach { y ->
            var i = y * stride
            val rowEnd = i + stride
            while (i < rowEnd) {
                val (nr, ng, nb) = block(px[i], px[i + 1], px[i + 2])
                px[i] = nr
                px[i + 1] = ng
                px[i + 2] = nb
                i += 3
            }
        }
    }

    fun copy(): LinearImage = LinearImage(width, height, pixels.copyOf())

    companion object {
        /** Decode sRGB 8-bit interleaved RGB → linear [LinearImage]. */
        @JvmStatic
        fun fromSrgbBytes(rgb: ByteArray, width: Int, height: Int): LinearImage {
            require(rgb.size >= width * height * 3)
            val out = LinearImage(width, height)
            var si = 0
            var di = 0
            while (si < width * height * 3) {
                out.pixels[di] = ColorSpaces.srgbByteToLinear(rgb[si].toInt() and 0xFF)
                out.pixels[di + 1] = ColorSpaces.srgbByteToLinear(rgb[si + 1].toInt() and 0xFF)
                out.pixels[di + 2] = ColorSpaces.srgbByteToLinear(rgb[si + 2].toInt() and 0xFF)
                si += 3
                di += 3
            }
            return out
        }

        /** Encode linear → sRGB 8-bit interleaved RGB. */
        @JvmStatic
        fun toSrgbBytes(image: LinearImage): ByteArray {
            val out = ByteArray(image.width * image.height * 3)
            var i = 0
            var o = 0
            val px = image.pixels
            while (i < px.size) {
                out[o] = ColorSpaces.linearToSrgbByte(px[i])
                out[o + 1] = ColorSpaces.linearToSrgbByte(px[i + 1])
                out[o + 2] = ColorSpaces.linearToSrgbByte(px[i + 2])
                i += 3
                o += 3
            }
            return out
        }
    }
}
