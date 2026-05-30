package lv.edgarsfoto.efpic_live

import android.graphics.BitmapFactory
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile

/**
 * Izvelk iegulto JPEG no Nikon NEF (un līdzīgiem RAW).
 * Neskatās visu failu atmiņā — skenē pa fragmentiem; validē ar BitmapFactory.
 */
object RawPreviewExtractor {
    private const val TAG = "RawPreviewExtractor"
    private const val MIN_JPEG_SIZE = 3 * 1024
    private const val MAX_JPEG_SIZE = 16 * 1024 * 1024
    private const val CHUNK_SIZE = 512 * 1024
    private const val OVERLAP = 4

    data class JpegSegment(val offset: Long, val size: Int)

    fun extractLargestEmbeddedJpeg(sourcePath: String, destPath: String): Boolean {
        val file = File(sourcePath)
        if (!file.exists() || file.length() < MIN_JPEG_SIZE) return false

        val dest = File(destPath)
        dest.parentFile?.mkdirs()
        if (dest.exists()) dest.delete()

        val segments = findJpegSegments(file)
        if (segments.isEmpty()) {
            Log.w(TAG, "Nav JPEG segmentu: $sourcePath")
            return tryExifThumbnailFallback(sourcePath, destPath)
        }

        val candidates =
            segments
                .filter { it.size in MIN_JPEG_SIZE..MAX_JPEG_SIZE }
                .sortedByDescending { it.size }

        for (segment in candidates) {
            if (writeSegment(file, segment, dest) && isDecodableJpeg(dest)) {
                resetExtractedThumbOrientation(destPath)
                Log.d(TAG, "Embedded JPEG ${segment.size} B → $destPath")
                return true
            }
            dest.delete()
        }

        val fallback = segments.filter { it.size >= 2 * 1024 }.maxByOrNull { it.size }
        if (fallback != null &&
            writeSegment(file, fallback, dest) &&
            isDecodableJpeg(dest)
        ) {
            resetExtractedThumbOrientation(destPath)
            return true
        }

        dest.delete()
        Log.w(TAG, "Neizdevās dekodēt segmentus, mēģina Exif sīktēlu: $sourcePath")
        return tryExifThumbnailFallback(sourcePath, destPath)
    }

    private fun tryExifThumbnailFallback(sourcePath: String, destPath: String): Boolean {
        if (!tryExifThumbnail(sourcePath, destPath)) return false
        resetExtractedThumbOrientation(destPath)
        Log.d(TAG, "Exif thumb (fallback) OK: $destPath")
        return true
    }

    private fun tryExifThumbnail(sourcePath: String, destPath: String): Boolean {
        return try {
            val exif = ExifInterface(sourcePath)
            val thumb = exif.thumbnail ?: return false
            if (thumb.size < 1024) return false
            FileOutputStream(destPath).use { it.write(thumb) }
            isDecodableJpeg(File(destPath))
        } catch (e: Exception) {
            Log.d(TAG, "Exif thumb: ${e.message}")
            false
        }
    }

    private fun writeSegment(file: File, segment: JpegSegment, dest: File): Boolean {
        return try {
            RandomAccessFile(file, "r").use { raf ->
                raf.seek(segment.offset)
                val buf = ByteArray(segment.size)
                raf.readFully(buf)
                dest.writeBytes(buf)
            }
            dest.exists() && dest.length() > 0
        } catch (e: Exception) {
            Log.d(TAG, "writeSegment: ${e.message}")
            false
        }
    }

    private fun isDecodableJpeg(file: File): Boolean {
        if (!file.exists() || file.length() < 512) return false
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, opts)
        return opts.outWidth > 0 && opts.outHeight > 0
    }

    fun findJpegSegments(file: File): List<JpegSegment> {
        val length = file.length()
        if (length < 4) return emptyList()

        val segments = mutableListOf<JpegSegment>()
        val starts = mutableListOf<Long>()

        RandomAccessFile(file, "r").use { raf ->
            var fileOffset = 0L
            val buffer = ByteArray(CHUNK_SIZE)
            var prevTail = ByteArray(0)

            while (fileOffset < length) {
                raf.seek(fileOffset)
                val read = raf.read(buffer)
                if (read <= 0) break

                val combined =
                    if (prevTail.isEmpty()) {
                        buffer.copyOf(read)
                    } else {
                        prevTail + buffer.copyOf(read)
                    }

                var i = 0
                while (i < combined.size - 1) {
                    if (combined[i] == 0xFF.toByte() && combined[i + 1] == 0xD8.toByte()) {
                        val absStart = fileOffset - prevTail.size + i
                        if (absStart >= 0) starts.add(absStart)
                    }
                    i++
                }

                prevTail =
                    if (read == CHUNK_SIZE) {
                        combined.copyOfRange(combined.size - OVERLAP, combined.size)
                    } else {
                        byteArrayOf()
                    }
                fileOffset += read
                if (read < CHUNK_SIZE) break
            }
        }

        for (start in starts.distinct().sorted()) {
            val end = findJpegEnd(file, start, length)
            if (end > start) {
                val size = (end - start + 2).toInt()
                if (size > 1024) {
                    segments.add(JpegSegment(start, size))
                }
            }
        }
        return segments
    }

    /** Pēdējais EOI (FF D9) diapazonā — pirmā bieži ir nepareiza un bojā JPG. */
    private fun findJpegEnd(file: File, start: Long, fileLength: Long): Long {
        val maxEnd = minOf(start + MAX_JPEG_SIZE, fileLength)
        var lastEoi = -1L
        RandomAccessFile(file, "r").use { raf ->
            val buf = ByteArray(64 * 1024)
            var pos = start + 2
            while (pos < maxEnd - 1) {
                raf.seek(pos)
                val toRead = minOf(buf.size.toLong(), maxEnd - pos).toInt()
                val n = raf.read(buf, 0, toRead)
                if (n <= 0) break
                for (j in 0 until n - 1) {
                    if (buf[j] == 0xFF.toByte() && buf[j + 1] == 0xD9.toByte()) {
                        lastEoi = pos + j
                    }
                }
                pos += n - 1
            }
        }
        return lastEoi
    }

    /** Iegultā JPG pikseļi jau ir pareizi — noņem maldinošu EXIF no _emb.jpg. */
    private fun resetExtractedThumbOrientation(destPath: String) {
        try {
            val dest = ExifInterface(destPath)
            dest.setAttribute(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL.toString(),
            )
            dest.saveAttributes()
        } catch (e: Exception) {
            Log.d(TAG, "Orient reset: ${e.message}")
        }
    }
}
