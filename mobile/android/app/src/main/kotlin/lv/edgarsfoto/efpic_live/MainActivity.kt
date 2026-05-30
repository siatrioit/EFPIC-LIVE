package lv.edgarsfoto.efpic_live

import android.content.Intent
import android.hardware.usb.UsbManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var cameraUsbPlugin: CameraUsbPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cameraUsbPlugin =
            CameraUsbPlugin(
                this,
                flutterEngine.dartExecutor.binaryMessenger,
            )
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
        super.onDestroy()
    }
}
