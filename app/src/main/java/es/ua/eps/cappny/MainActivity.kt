package es.ua.eps.cappny

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import es.ua.eps.cappny.databinding.ActivityMainBinding
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.Mat
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    private lateinit var cameraExecutor: ExecutorService

    private var isProcessing = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Inicializar OpenCV antes de usarlo
        if (!OpenCVLoader.initLocal()) {
            Log.e("OpenCV", "Error al inicializar OpenCV")
            return
        }
        Log.d("OpenCV", "OpenCV initialized successfully")

        cameraExecutor = Executors.newSingleThreadExecutor()

        // Start/Stop button toggles the isProcessing flag and updates button text
        binding.btnStartStop.setOnClickListener {
            isProcessing = !isProcessing
            binding.btnStartStop.text = if (isProcessing) "Stop" else "Start"
            // If we stop, clear the overlay so it doesn't remain frozen on screen
            if (!isProcessing) {
                binding.overlayView.setImageBitmap(null)
            }
        }

        // Solicitar permisos y arrancar cámara
        if (checkSelfPermission(Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        } else {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), 100)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100
            && grantResults.isNotEmpty()
            && grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this@MainActivity)

        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            val preview = Preview.Builder().build().also {
                it.surfaceProvider = binding.previewView.surfaceProvider
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also {
                    it.setAnalyzer(cameraExecutor) { imageProxy ->
                        processFrame(imageProxy)
                    }
                }

            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                this,
                CameraSelector.DEFAULT_BACK_CAMERA,
                preview,
                imageAnalysis
            )
        }, ContextCompat.getMainExecutor(this@MainActivity))
    }

    private fun processFrame(imageProxy: androidx.camera.core.ImageProxy) {
        // If the user pressed Stop, skip processing but still close the proxy
        if (!isProcessing) {
            imageProxy.close()
            return
        }

        // --- Read slider values ---
        // Blur: slider 0–6, we want odd kernel sizes 1,3,5,7,9,11,13
        // Formula: value * 2 + 1  →  0→1, 1→3, 2→5, 3→7, 4→9, 5→11, 6→13
        val blurProgress = binding.sliderBlur.progress
        val blurSize = blurProgress * 2 + 1   // always odd, minimum 1

        // Edge: slider 0–100 maps directly to the low threshold.
        // High threshold = low × 3  (Canny recommendation: ratio 1:3)
        val lowThreshold = binding.sliderEdge.progress.toDouble()
        val highThreshold = lowThreshold * 3.0

        // Gradient: slider 0–2 maps to aperture sizes 3, 5, 7
        // Formula: value * 2 + 3  →  0→3, 1→5, 2→7
        val gradientProgress = binding.sliderGradient.progress
        val apertureSize = gradientProgress * 2 + 3

        // --- Convert ImageProxy to Bitmap ---
        val bitmap = imageProxy.toBitmap()

        // --- OpenCV pipeline ---
        // All Mat objects created here must be released before returning

        val src = Mat()
        Utils.bitmapToMat(bitmap, src)   // Bitmap → Mat (RGBA, 4 channels)

        val gray = Mat()
        Imgproc.cvtColor(src, gray, Imgproc.COLOR_RGBA2GRAY)  // RGBA → Grayscale

        val blurred = Mat()
        // GaussianBlur needs an odd kernel size. blurSize=1 means no blur (1×1 kernel)
        Imgproc.GaussianBlur(gray, blurred, Size(blurSize.toDouble(), blurSize.toDouble()), 0.0)

        val edges = Mat()
        // Canny: blurred input, output, low threshold, high threshold, Sobel aperture
        Imgproc.Canny(blurred, edges, lowThreshold, highThreshold, apertureSize)

        // --- Convert result back to Bitmap and update UI ---
        // edges is a single-channel (grayscale) Mat; createBitmap needs ARGB_8888
        val resultBitmap = Bitmap.createBitmap(
            edges.cols(), edges.rows(), Bitmap.Config.ARGB_8888
        )
        Utils.matToBitmap(edges, resultBitmap)

        // UI updates must happen on the main thread
        runOnUiThread {
            binding.overlayView.setImageBitmap(resultBitmap)
        }

        // --- Release ALL Mat objects to avoid native memory leaks ---
        src.release()
        gray.release()
        blurred.release()
        edges.release()

        // CRITICAL: close the ImageProxy or CameraX stops delivering frames
        imageProxy.close()
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }

    companion object {
        private const val CAMERA_REQUEST_CODE = 100
    }
}