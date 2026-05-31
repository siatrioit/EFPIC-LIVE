package lv.edgarsfoto.efpic_live

import android.content.Intent
import android.hardware.usb.UsbManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var cameraUsbPlugin: CameraUsbPlugin? = null
    private var xmpPresetPlugin: XmpPresetPlugin? = null
    private var rawEditPlugin: RawEditPlugin? = null
    private var rawDevelopPlugin: RawDevelopPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        cameraUsbPlugin =
            CameraUsbPlugin(
                this,
                messenger,
            )
        xmpPresetPlugin = XmpPresetPlugin(messenger)
        rawEditPlugin = RawEditPlugin(messenger)
        rawDevelopPlugin = RawDevelopPlugin(messenger)
        handleUsbIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        cameraUsbPlugin?.handleUsbIntent(intent)
    }

    private fun handleUsbIntent(intent: Intent?) {
        if (intent?.action == UsbManager.ACTION_USB_DEVICE_ATTACHED) {
            cameraUsbPlugin?.handleUsbIntent(intent)
        }
    }

    override fun onDestroy() {
        cameraUsbPlugin?.dispose()
        cameraUsbPlugin = null
        xmpPresetPlugin?.dispose()
        xmpPresetPlugin = null
        rawEditPlugin?.dispose()
        rawEditPlugin = null
        rawDevelopPlugin?.dispose()
        rawDevelopPlugin = null
        super.onDestroy()
    }
}
