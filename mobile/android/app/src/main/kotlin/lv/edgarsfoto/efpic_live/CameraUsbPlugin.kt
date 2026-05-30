package lv.edgarsfoto.efpic_live

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class CameraUsbPlugin(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "lv.edgarsfoto.efpic_live/camera_usb"
        const val EVENT_CHANNEL = "lv.edgarsfoto.efpic_live/camera_usb_events"
        const val ACTION_USB_PERMISSION = "lv.edgarsfoto.efpic_live.USB_PERMISSION"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val previewExecutor = Executors.newFixedThreadPool(2)
    private var permissionReceiver: BroadcastReceiver? = null
    private var attachReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    init {
        channel.setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
        registerAttachReceiver()
    }

    fun handleUsbIntent(intent: Intent?) {
        if (intent?.action == UsbManager.ACTION_USB_DEVICE_ATTACHED) {
            emitEvent("attached", mapOf("source" to "intent"))
        }
    }

    private fun registerAttachReceiver() {
        attachReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == UsbManager.ACTION_USB_DEVICE_ATTACHED) {
                        emitEvent("attached", mapOf("source" to "broadcast"))
                    }
                }
            }
        ContextCompat.registerReceiver(
            activity,
            attachReceiver,
            IntentFilter(UsbManager.ACTION_USB_DEVICE_ATTACHED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    private fun emitEvent(type: String, data: Map<String, Any?> = emptyMap()) {
        mainHandler.post {
            eventSink?.success(
                mapOf("event" to type) + data,
            )
        }
    }

    private fun usbManager(): UsbManager =
        activity.getSystemService(Context.USB_SERVICE) as UsbManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.HONEYCOMB_MR1) {
            result.error("unsupported", "MTP prasa Android 3.1+", null)
            return
        }

        when (call.method) {
            "probe" ->
                ioExecutor.execute {
                    val payload = probe()
                    mainHandler.post { result.success(payload) }
                }
            "requestPermission" -> {
                requestPermission()
                result.success(true)
            }
            "listImages" ->
                ioExecutor.execute {
                    val payload = listImages()
                    mainHandler.post { result.success(payload) }
                }
            "downloadBatch" -> {
                @Suppress("UNCHECKED_CAST")
                val rawItems = call.argument<List<Map<String, Any>>>("items")
                if (rawItems.isNullOrEmpty()) {
                    result.error("invalid_args", "items obligāti", null)
                    return
                }
                ioExecutor.execute {
                    val payload = downloadBatch(rawItems)
                    mainHandler.post { result.success(payload) }
                }
            }
            "extractRawPreview" -> {
                val rawPath = call.argument<String>("rawPath")
                val destPath = call.argument<String>("destPath")
                if (rawPath.isNullOrBlank() || destPath.isNullOrBlank()) {
                    result.error("invalid_args", "rawPath un destPath obligāti", null)
                    return
                }
                previewExecutor.execute {
                    val ok = RawPreviewExtractor.extractLargestEmbeddedJpeg(rawPath, destPath)
                    mainHandler.post { result.success(ok) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun probe(): Map<String, Any?> {
        val mgr = usbManager()
        val device = NikonMtpSession.findNikonDevice(mgr)
            ?: return mapOf(
                "connected" to false,
                "error" to "Nikon kamera nav atrasta (USB / MTP režīms?)",
            )

        val probe = NikonMtpSession.probe(mgr, device)
        return mapOf(
            "connected" to probe.connected,
            "needsPermission" to probe.needsPermission,
            "productName" to probe.productName,
            "manufacturer" to probe.manufacturer,
            "deviceName" to probe.deviceName,
            "storageCount" to probe.storageCount,
            "imageCount" to probe.imageCount,
            "sampleFiles" to probe.sampleFiles,
            "error" to probe.error,
        )
    }

    private fun listImages(): Map<String, Any?> {
        val mgr = usbManager()
        val device = NikonMtpSession.findNikonDevice(mgr)
            ?: return mapOf("ok" to false, "error" to "Kamera nav atrasta")

        val (images, error) = NikonMtpSession.listImages(mgr, device)
        if (error != null) {
            return mapOf("ok" to false, "error" to error)
        }
        return mapOf(
            "ok" to true,
            "images" to
                images.map {
                    mapOf(
                        "handle" to it.handle,
                        "name" to it.name,
                        "size" to it.size,
                        "modified" to it.modified,
                    )
                },
        )
    }

    private fun downloadBatch(rawItems: List<Map<String, Any>>): Map<String, Any?> {
        val mgr = usbManager()
        val device = NikonMtpSession.findNikonDevice(mgr)
            ?: return mapOf("ok" to false, "error" to "Kamera nav atrasta")

        val items =
            rawItems.mapNotNull { map ->
                val handle = (map["handle"] as? Number)?.toInt() ?: return@mapNotNull null
                val destPath = map["destPath"] as? String ?: return@mapNotNull null
                val size = (map["size"] as? Number)?.toLong() ?: 0L
                NikonMtpSession.DownloadItem(handle, destPath, size)
            }

        val results = NikonMtpSession.downloadBatch(mgr, device, items)
        return mapOf(
            "ok" to true,
            "results" to
                results.map {
                    mapOf(
                        "destPath" to it.destPath,
                        "ok" to it.ok,
                        "error" to it.error,
                    )
                },
        )
    }

    private fun requestPermission() {
        val mgr = usbManager()
        val device = NikonMtpSession.findNikonDevice(mgr) ?: return
        if (mgr.hasPermission(device)) {
            emitEvent("permission_granted", emptyMap())
            return
        }

        val intent = Intent(ACTION_USB_PERMISSION).setPackage(activity.packageName)
        val flags =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
        val pending = PendingIntent.getBroadcast(activity, 0, intent, flags)

        permissionReceiver?.let {
            try {
                activity.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        permissionReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val granted =
                        intent?.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                            ?: false
                    if (granted) {
                        emitEvent("permission_granted", emptyMap())
                    } else {
                        emitEvent("permission_denied", emptyMap())
                    }
                }
            }
        ContextCompat.registerReceiver(
            activity,
            permissionReceiver,
            IntentFilter(ACTION_USB_PERMISSION),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        mgr.requestPermission(device, pending)
    }

    fun dispose() {
        permissionReceiver?.let {
            try {
                activity.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        attachReceiver?.let {
            try {
                activity.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        permissionReceiver = null
        attachReceiver = null
        channel.setMethodCallHandler(null)
        eventSink = null
    }
}
