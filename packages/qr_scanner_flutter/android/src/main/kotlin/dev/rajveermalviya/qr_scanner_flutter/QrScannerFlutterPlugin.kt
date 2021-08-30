package dev.rajveermalviya.qr_scanner_flutter

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.pm.PackageManager
import java.lang.Runnable

import android.view.Surface
import android.util.Size
import android.util.Log

import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import androidx.core.util.Consumer
import androidx.lifecycle.LifecycleOwner

import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.ImageAnalysis
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat

import com.google.mlkit.vision.barcode.Barcode
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage

import io.flutter.view.TextureRegistry
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.PluginRegistry

const val PERMISSION_REQUEST_CAMERA = 69_420 // 🙃

class QrScannerFlutterPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var methodChannel: MethodChannel? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var flutterTexture: TextureRegistry.SurfaceTextureEntry? = null
    private var barcodeScanner: BarcodeScanner? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = binding

        val channel = MethodChannel(flutterPluginBinding!!.binaryMessenger, "qr_scanner_flutter.rajveermalviya.dev")
        channel.setMethodCallHandler(this)
        methodChannel = channel
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityPluginBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityPluginBinding?.removeRequestPermissionsResultListener(this)
        activityPluginBinding = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)

        methodChannel = null
        flutterPluginBinding = null
    }

    @androidx.camera.core.ExperimentalGetImage
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "dispose" -> dispose(result)
            else -> result.notImplemented()
        }
    }

    @androidx.camera.core.ExperimentalGetImage
    private fun initialize(result: MethodChannel.Result) {
        clean()
        val activity: Activity = activityPluginBinding!!.activity

        when (PackageManager.PERMISSION_GRANTED) {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.CAMERA
            ) -> {
                startCamera(activity)
            }
            else -> {
                ActivityCompat.requestPermissions(activity,
                    arrayOf(Manifest.permission.CAMERA),
                    PERMISSION_REQUEST_CAMERA)
            }
        }

        result.success(null)
    }

    @androidx.camera.core.ExperimentalGetImage
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CAMERA) {
            return false
        }

        if (grantResults.size == 1 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            val activity: Activity = activityPluginBinding!!.activity
            startCamera(activity)

        } else {
            // TODO:
        }
        return true
    }

    @androidx.camera.core.ExperimentalGetImage
    @SuppressLint("RestrictedApi")
    private fun startCamera(activity: Activity) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        val executor = ContextCompat.getMainExecutor(activity)

        cameraProviderFuture.addListener(Runnable {
        val provider = cameraProviderFuture.get()
        this.cameraProvider = provider

        val surfaceTexture = flutterPluginBinding!!.textureRegistry.createSurfaceTexture()
        this.flutterTexture = surfaceTexture

        val surfaceProvider = Preview.SurfaceProvider { surfaceRequest ->
            val resolution = surfaceRequest.resolution

            val texture = surfaceTexture.surfaceTexture()
            texture.setDefaultBufferSize(resolution.width, resolution.height)

            val surface = Surface(texture)
            surfaceRequest.provideSurface(surface, executor, Consumer<SurfaceRequest.Result> {})
        }

        val preview = Preview.Builder().build()
        preview.setSurfaceProvider(surfaceProvider)

        val imageAnalysis = ImageAnalysis.Builder()
                .setTargetResolution(Size(1280, 720))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        val scanner = BarcodeScanning.getClient(options)
        this.barcodeScanner = scanner

        imageAnalysis.setAnalyzer(executor, ImageAnalysis.Analyzer { imageProxy ->
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees

            val mediaImage = imageProxy.image
            if (mediaImage != null) {
                val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

                val result = scanner.process(image)
                .addOnSuccessListener { barcodes ->
                    for (barcode in barcodes) {
                        methodChannel?.invokeMethod("barcodeDetected", barcode.rawValue)
                    }
                }
                .addOnFailureListener { e -> Log.e("QrScanner", e.message, e) }
                .addOnCompleteListener { imageProxy.close() }
            } else {
                imageProxy.close()
            }
        })

        val camera = provider.bindToLifecycle(activity as LifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, imageAnalysis, preview)

        val resolution = preview.attachedSurfaceResolution!!
        val portrait = camera.cameraInfo.sensorRotationDegrees % 180 == 0
        val width = if (portrait) resolution.width.toDouble() else resolution.height.toDouble()
        val height = if (portrait) resolution.height.toDouble() else resolution.width.toDouble()
        val answer = mapOf("texture_id" to surfaceTexture.id(), "width" to width, "height" to height)
        methodChannel?.invokeMethod("cameraInitialized", answer)
        }, executor)
    }

    private fun clean() {
        cameraProvider?.unbindAll()
        flutterTexture?.release()
        barcodeScanner?.close()

        flutterTexture = null
        cameraProvider = null
        barcodeScanner = null
    }

    private fun dispose(result: MethodChannel.Result) {
        clean()
        result.success(null)
    }
}
