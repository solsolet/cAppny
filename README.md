# cAppny
Aplicación tanto para iOS como para Android, que implementa el filtro de detección de bordes **Canny** utilizando **OpenCV 4.10.0**. La app captura imagen en tiempo real desde la cámara trasera del dispositivo y aplica el pipeline completo de Canny sobre cada frame, mostrando el resultado superpuesto sobre el preview de la cámara.

## Plataformas
 
| Plataforma | Estado     |
|------------|------------|
| Android    | ✅ Completado |
| iOS        | 🔄 Pendiente |

### Entorno de desarrollo Android
 
- **IDE:** Android Studio Narwhal
- **Gradle:** 8.13
- **Compile SDK / Target SDK:** API 36 (Android 16 Baklava)
- **Minimum SDK:** API 24
- **Lenguaje:** Kotlin

## TODO
- [ ] Android

## Demo
Se puede ver la demo del proyecto en la carpeta de este zip como demo_cAppny.mp4. Cualquier problema con la versión entregada por Moodle (tanto del proyecto como del README) se puede usar el repositorio donde se encuentra alojada la práctica: [todo: insertar repo]

Para probar la aplicación directamente en un dispositivo Android (SDK <= 35) se puede instalar la APK: cAppny.apk o descargándola de GitHub.

## 📋 Resumen de la arquitectura
```bash
```

## Implementación
### Android
#### Pipeline de procesamiento de imagen
 
Cada frame capturado por la cámara pasa por el siguiente pipeline, implementado con OpenCV:
 
```
Frame (RGBA)
    │
    ▼
cvtColor → Escala de grises
    │
    ▼
GaussianBlur → Reducción de ruido
    │
    ▼
Canny → Detección de bordes
    │
    ▼
Overlay sobre el preview
```
 
1. **Conversión a escala de grises** (`cvtColor`): Canny requiere una imagen de un solo canal. Se convierte el frame RGBA capturado por CameraX a escala de grises.
 
2. **Suavizado Gaussiano** (`GaussianBlur`): Se aplica un filtro Gaussiano para eliminar el ruido de la cámara antes de detectar bordes. Sin este paso, las pequeñas variaciones de intensidad propias del sensor generarían cientos de falsos bordes.
 
3. **Detección de bordes Canny** (`Canny`): El algoritmo aplica internamente el operador Sobel para calcular el gradiente, realiza supresión de no-máximos para adelgazar los bordes a un píxel de ancho, y aplica umbralización doble con histéresis para distinguir bordes fuertes de débiles.
 
#### Controles de la interfaz
 
La app expone los tres parámetros principales del pipeline como sliders:
 
| Slider | Parámetro OpenCV | Rango slider | Conversión | Rango real |
|--------|-----------------|-------------|------------|------------|
| **Blur** | Tamaño del kernel Gaussiano | 0–6 | `v * 2 + 1` | 1, 3, 5, 7, 9, 11, 13 |
| **Edge** | Umbrales de Canny | 0–100 | low = v, high = v × 3 | 0–100 / 0–300 |
| **Gradient Angle** | Apertura del operador Sobel | 0–2 | `v * 2 + 3` | 3, 5, 7 |
 
Los kernels del suavizado y del Sobel deben ser siempre impares (requisito de OpenCV), de ahí las fórmulas de conversión. La relación 1:3 entre umbral bajo y alto del Canny sigue la recomendación estándar del algoritmo.
 
El botón **Start/Stop** activa y desactiva el procesamiento. Al detener, el overlay se limpia para no mostrar el último frame congelado.
 
#### Arquitectura técnica
 
- **CameraX** (`ImageAnalysis` + `Preview`): captura de frames en tiempo real. Se usa `STRATEGY_KEEP_ONLY_LATEST` para descartar frames si el procesamiento es más lento que la captura, evitando lag acumulativo.
- **ViewBinding**: acceso type-safe a las vistas, sin `findViewById`.
- **ExecutorService** (hilo único): todo el procesamiento OpenCV ocurre fuera del hilo principal para no bloquear la UI.
- **Gestión de memoria**: cada `Mat` intermedio se libera explícitamente con `.release()` al terminar cada frame. OpenCV gestiona memoria nativa fuera del garbage collector de Kotlin, por lo que no liberar los `Mat` provocaría memory leaks.
- **Rotación de frames**: se consulta `imageProxy.imageInfo.rotationDegrees` y se aplica `Core.rotate()` antes de procesar, para que el overlay coincida correctamente con el preview independientemente de la orientación del dispositivo.
- **Edge-to-edge**: la app usa `enableEdgeToEdge()` y aplica `WindowInsets` dinámicamente para que el contenido respete el notch y la barra de navegación.
 
### Dependencias
 
```kotlin
implementation("org.opencv:opencv:4.10.0")          // Visión por computador
implementation("androidx.camera:camera-camera2:1.4.2")  // CameraX
implementation("androidx.camera:camera-lifecycle:1.4.2")
implementation("androidx.camera:camera-view:1.4.2")
```
 
OpenCV se descarga automáticamente vía Gradle desde Maven Central. **No está incluido en la entrega.**

### iOS

## Problemas encontrados
### El overlay de bordes no coincidía con el preview
 
**Problema:** En algunos dispositivos, CameraX entrega los frames rotados respecto a cómo se muestra el preview. El resultado era que el overlay de bordes aparecía girado 90° respecto a la imagen real.
 
**Solución:** Se consulta `imageProxy.imageInfo.rotationDegrees` en cada frame y se aplica `Core.rotate()` sobre el `Mat` antes de iniciar el pipeline, usando los códigos `ROTATE_90_CLOCKWISE`, `ROTATE_180` o `ROTATE_90_COUNTERCLOCKWISE` según corresponda.
 
### El contenido quedaba oculto bajo el notch y la barra de navegación
 
**Problema:** Al usar `enableEdgeToEdge()`, la app dibuja bajo las barras del sistema. El panel de controles quedaba parcialmente oculto bajo la barra de navegación, y el preview se iniciaba desde el borde superior sin respetar el notch.
 
**Solución:** Se aplica `ViewCompat.setOnApplyWindowInsetsListener` sobre la raíz del layout. El padding superior se asigna al `PreviewView` y el padding inferior (barra de navegación) se añade dinámicamente al panel de controles.
 
### Crash al pasar un tamaño de kernel par a GaussianBlur
 
**Problema:** OpenCV lanza una excepción nativa si el tamaño del kernel de `GaussianBlur` es par. Un slider con rango directo podría producir valores pares.
 
**Solución:** La fórmula `v * 2 + 1` garantiza que el resultado siempre sea impar, independientemente del valor del slider.

## Notas adicionales
 
- La práctica ha sido probada en un dispositivo físico Android. El emulador tiene una cámara simulada que también permite verificar el funcionamiento básico de la UI.