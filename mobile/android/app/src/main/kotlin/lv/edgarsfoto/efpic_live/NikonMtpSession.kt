package lv.edgarsfoto.efpic_live

import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.mtp.MtpConstants
import android.mtp.MtpDevice
import android.mtp.MtpObjectInfo
import android.os.Build
import androidx.annotation.RequiresApi
import java.io.File
import java.util.concurrent.Executors

object NikonMtpSession {
    const val NIKON_VENDOR_ID = 0x04B0
    private val ioExecutor = Executors.newSingleThreadExecutor()

    data class ProbeResult(
        val connected: Boolean,
        val needsPermission: Boolean = false,
        val productName: String? = null,
        val manufacturer: String? = null,
        val deviceName: String? = null,
        val storageCount: Int = 0,
        val imageCount: Int = 0,
        val sampleFiles: List<String> = emptyList(),
        val error: String? = null,
    )

    data class RemoteImage(
        val handle: Int,
        val name: String,
        val size: Long,
        val modified: Long,
    )

    data class DownloadItem(
        val handle: Int,
        val destPath: String,
        val size: Long,
    )

    data class DownloadResult(
        val destPath: String,
        val ok: Boolean,
        val error: String? = null,
    )

    fun findNikonDevice(usbManager: UsbManager): UsbDevice? =
        usbManager.deviceList.values.firstOrNull { it.vendorId == NIKON_VENDOR_ID }

    @RequiresApi(Build.VERSION_CODES.HONEYCOMB_MR1)
    fun probe(usbManager: UsbManager, device: UsbDevice): ProbeResult =
        runOnIo {
            if (!usbManager.hasPermission(device)) {
                return@runOnIo ProbeResult(
                    connected = true,
                    needsPermission = true,
                    productName = device.productName,
                    manufacturer = device.manufacturerName,
                    deviceName = device.deviceName,
                )
            }
            withOpenMtp(usbManager, device) { mtp ->
                val storageIds = mtp.storageIds ?: intArrayOf()
                val images = mutableListOf<RemoteImage>()
                for (storageId in storageIds) {
                    collectImages(mtp, storageId, -1, images)
                }
                ProbeResult(
                    connected = true,
                    productName = device.productName,
                    manufacturer = device.manufacturerName,
                    deviceName = device.deviceName,
                    storageCount = storageIds.size,
                    imageCount = images.size,
                    sampleFiles = images.take(8).map { it.name },
                )
            } ?: ProbeResult(connected = true, error = "Neizdevās atvērt MTP sesiju")
        }

    @RequiresApi(Build.VERSION_CODES.HONEYCOMB_MR1)
    fun listImages(usbManager: UsbManager, device: UsbDevice): Pair<List<RemoteImage>, String?> =
        runOnIo {
            if (!usbManager.hasPermission(device)) {
                return@runOnIo emptyList<RemoteImage>() to "Nav USB atļaujas"
            }
            val result =
                withOpenMtp(usbManager, device) { mtp ->
                    val images = mutableListOf<RemoteImage>()
                    val storageIds = mtp.storageIds ?: intArrayOf()
                    for (storageId in storageIds) {
                        collectImages(mtp, storageId, -1, images)
                    }
                    images
                }
            if (result == null) {
                emptyList<RemoteImage>() to "Neizdevās atvērt MTP sesiju"
            } else {
                result to null
            }
        }

    @RequiresApi(Build.VERSION_CODES.HONEYCOMB_MR1)
    fun downloadBatch(
        usbManager: UsbManager,
        device: UsbDevice,
        items: List<DownloadItem>,
    ): List<DownloadResult> =
        runOnIo {
            if (!usbManager.hasPermission(device)) {
                return@runOnIo items.map {
                    DownloadResult(it.destPath, false, "Nav USB atļaujas")
                }
            }
            withOpenMtp(usbManager, device) { mtp ->
                items.map { item -> downloadOne(mtp, item) }
            }
                ?: items.map {
                    DownloadResult(it.destPath, false, "Neizdevās atvērt MTP sesiju")
                }
        }

    @RequiresApi(Build.VERSION_CODES.HONEYCOMB_MR1)
    private fun downloadOne(mtp: MtpDevice, item: DownloadItem): DownloadResult {
        val dest = File(item.destPath)
        dest.parentFile?.mkdirs()
        if (dest.exists()) dest.delete()

        return try {
            var ok = mtp.importFile(item.handle, item.destPath)
            if (!ok || !dest.exists() || dest.length() == 0L) {
                val size = item.size.toInt().coerceAtLeast(0)
                if (size > 0) {
                    val bytes = mtp.getObject(item.handle, size)
                    if (bytes != null && bytes.isNotEmpty()) {
                        dest.writeBytes(bytes)
                        ok = true
                    }
                }
            }
            if (ok && dest.exists() && dest.length() > 0L) {
                DownloadResult(item.destPath, true, null)
            } else {
                DownloadResult(
                    item.destPath,
                    false,
                    "importFile/getObject neizdevās (${item.nameFromPath()})",
                )
            }
        } catch (e: Exception) {
            DownloadResult(item.destPath, false, e.message ?: e.toString())
        }
    }

    private fun DownloadItem.nameFromPath(): String =
        destPath.substringAfterLast('/').substringAfterLast('\\')

    @RequiresApi(Build.VERSION_CODES.HONEYCOMB_MR1)
    private inline fun <T> withOpenMtp(
        usbManager: UsbManager,
        device: UsbDevice,
        block: (MtpDevice) -> T,
    ): T? {
        val connection =
            usbManager.openDevice(device) ?: return null
        val mtp = MtpDevice(device)
        if (!mtp.open(connection)) {
            connection.close()
            return null
        }
        return try {
            block(mtp)
        } catch (e: Exception) {
            null
        } finally {
            mtp.close()
        }
    }

    @RequiresApi(Build.VERSION_CODES.HONEYCOMB_MR1)
    private fun collectImages(
        mtp: MtpDevice,
        storageId: Int,
        parentHandle: Int,
        out: MutableList<RemoteImage>,
        depth: Int = 0,
    ) {
        if (depth > 16 || out.size > 5000) return
        val handles =
            try {
                mtp.getObjectHandles(storageId, 0, parentHandle)
            } catch (_: Exception) {
                null
            } ?: return

        for (handle in handles) {
            val info: MtpObjectInfo =
                try {
                    mtp.getObjectInfo(handle)
                } catch (_: Exception) {
                    continue
                } ?: continue

            if (info.format == MtpConstants.FORMAT_ASSOCIATION) {
                collectImages(mtp, storageId, handle, out, depth + 1)
            } else if (isImageFile(info)) {
                out.add(
                    RemoteImage(
                        handle = handle,
                        name = info.name,
                        size = info.compressedSize.toLong(),
                        modified = info.dateModified.toLong(),
                    ),
                )
            }
        }
    }

    private fun isImageFile(info: MtpObjectInfo): Boolean {
        val name = info.name.lowercase()
        if (name.endsWith(".jpg") || name.endsWith(".jpeg")) return true
        if (name.endsWith(".nef") || name.endsWith(".nrw")) return true
        if (name.endsWith(".tif") || name.endsWith(".tiff")) return true
        return info.format == MtpConstants.FORMAT_EXIF_JPEG
    }

    private fun <T> runOnIo(block: () -> T): T = ioExecutor.submit(block).get()
}
