# cAppny
Aplicación tanto para iOS como para Android, que implementa el filtro de detección de bordes **Canny** utilizando **OpenCV 4.10.0**. La app captura imagen en tiempo real desde la cámara trasera del dispositivo y aplica el pipeline completo de Canny sobre cada frame, mostrando el resultado superpuesto sobre el preview de la cámara.

## Plataformas y entorno de desarrollo

|              | Android                                         | iOS                                        |
|--------------|-------------------------------------------------|--------------------------------------------|
| **IDE**      | Android Studio Narwhal                          | XCode 26.0.1                               |
| **SDK**      | API 36, mín. API 24                             | iOS 18.6                                   |
| **Lenguaje** | Kotlin                                          | SwiftSwift + Objective-C++                 |
| **Demo**     | [Demo Android](Android/demo_cAppny_Android.mp4) | [Demo iOS](iOS/cAppny/demo_cappny_ios.mov) |
<!--TODO: revisar si falta algo más-->

## Demo
Se puede ver la demo del proyecto en cada plataforma en su respectiva carpeta. Cualquier problema con la versión entregada por Moodle (tanto del proyecto como del README) se puede usar el repositorio donde se encuentra alojada la práctica: [https://github.com/solsolet/cAppny.git](https://github.com/solsolet/cAppny.git)

Para probar la aplicación directamente en un dispositivo Android (SDK <= 36) se puede instalar la APK: cAppny.apk o descargándola de [GitHub](https://github.com/solsolet/cAppny/releases/tag/Android). Para probarla en iOS Compilar el proyecto de XCode y probar en un dispositivo real.

## 📋 Resumen de la arquitectura
```bash
cAppny/
├── Android/
│   ├── app/
│   │   └── src/main/
│   │       ├── java/.../MainActivity.kt      # Lógica principal, pipeline OpenCV, CameraX
│   │       ├── res/layout/activity_main.xml  # Layout: PreviewView + overlay + controles
│   │       └── AndroidManifest.xml           # Permisos de cámara
│   └── build.gradle                          # Dependencias: OpenCV 4.10.0, CameraX
│
└── iOS/cAppny/
    ├── CameraManager.swift       # Sesión AVFoundation, procesamiento de frames, publicación del resultado
    ├── CameraPreviewView.swift   # UIViewRepresentable que aloja AVCaptureVideoPreviewLayer
    ├── ContentView.swift         # UI en SwiftUI: ZStack con preview, overlay y panel de controles
    ├── cAppnyApp.swift           # Punto de entrada SwiftUI (@main)
    ├── OpenCVWrapper.h           # Interfaz Objective-C visible desde Swift
    ├── OpenCVWrapper.mm          # Implementación Objective-C++: puente Swift ↔ OpenCV
    └── cAppny-Bridging-Header.h  # Importa OpenCVWrapper.h para que Swift lo use
```

¿Por qué es importante cada fichero?

| Fichero | Rol |
|---------|-----|
| `MainActivity.kt` | Orquesta CameraX, lee los sliders, ejecuta el pipeline OpenCV en un hilo secundario y actualiza el overlay en el hilo principal |
| `activity_main.xml` | Define `PreviewView` y `ImageView` superpuestos, más el panel de sliders en la parte inferior |
| `CameraManager.swift` | Equivalente iOS de MainActivity: gestiona `AVCaptureSession`, recibe frames y llama al wrapper de OpenCV |
| `CameraPreviewView.swift` | Necesario porque SwiftUI no puede alojar directamente un `CALayer`; actúa de adaptador UIKit → SwiftUI |
| `ContentView.swift` | Construye el `ZStack` (preview + overlay + controles) y conecta los sliders con `CameraManager` |
| `OpenCVWrapper.mm` | El fichero más crítico de iOS: el único lugar donde conviven C++ (OpenCV) y Objective-C en el mismo archivo gracias a la extensión `.mm` |
| `cAppny-Bridging-Header.h` | Permite que Swift vea la interfaz Objective-C del wrapper sin necesitar saber nada de C++ |


## Implementación
### Pipeline común (Android e iOS)
 
Ambas plataformas ejecutan el mismo pipeline lógico sobre cada frame:
 
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
 
1. **Conversión a escala de grises** (`cvtColor`): Canny requiere una imagen de un solo canal. Se convierte el frame RGBA de la cámara a escala de grises.
2. **Suavizado Gaussiano** (`GaussianBlur`): elimina el ruido del sensor antes de buscar bordes. Sin este paso, las variaciones aleatorias de intensidad generarían cientos de falsos bordes.
3. **Detección de bordes Canny** (`Canny`): aplica internamente Sobel para calcular el gradiente, supresión de no-máximos para adelgazar los bordes a un píxel de ancho, y umbralización doble con histéresis para distinguir bordes fuertes de débiles.
 
### Controles de la interfaz (comunes)
 
| Slider | Parámetro OpenCV | Rango slider | Conversión | Rango real |
|--------|-----------------|-------------|------------|------------|
| **Blur** | Tamaño del kernel Gaussiano | 0–6 | `v * 2 + 1` | 1, 3, 5, 7, 9, 11, 13 |
| **Edge** | Umbrales de Canny | 0–100 | low = v, high = v × 3 | 0–100 / 0–300 |
| **Gradient Angle** | Apertura del operador Sobel | 0–2 | `v * 2 + 3` | 3, 5, 7 |
 
Los kernels de GaussianBlur y Sobel deben ser siempre impares (requisito de OpenCV), de ahí las fórmulas de conversión. La relación 1:3 entre umbral bajo y alto del Canny sigue la recomendación estándar del algoritmo.
 
El botón **Start/Stop** activa y desactiva el procesamiento. Al detener, el overlay se limpia para no mostrar el último frame congelado.

### Android
#### Arquitectura técnica
 
- **CameraX** (`ImageAnalysis` + `Preview`): captura de frames en tiempo real. Se usa `STRATEGY_KEEP_ONLY_LATEST` para descartar frames si el procesamiento es más lento que la captura, evitando lag acumulativo.
- **ViewBinding**: acceso type-safe a las vistas, sin `findViewById`.
- **ExecutorService** (hilo único): todo el procesamiento OpenCV ocurre fuera del hilo principal para no bloquear la UI.
- **Gestión de memoria**: cada `Mat` intermedio se libera explícitamente con `.release()` al terminar cada frame. OpenCV gestiona memoria nativa fuera del garbage collector de Kotlin, por lo que no liberar los `Mat` provocaría memory leaks.
- **Rotación de frames**: se consulta `imageProxy.imageInfo.rotationDegrees` y se aplica `Core.rotate()` antes de procesar, para que el overlay coincida con el preview en cualquier orientación.
- **Edge-to-edge**: la app usa `enableEdgeToEdge()` y aplica `WindowInsets` dinámicamente para respetar el notch y la barra de navegación.
 
#### Dependencias
 
```kotlin
implementation("org.opencv:opencv:4.10.0")
implementation("androidx.camera:camera-camera2:1.4.2")
implementation("androidx.camera:camera-lifecycle:1.4.2")
implementation("androidx.camera:camera-view:1.4.2")
```
 
OpenCV se descarga automáticamente vía Gradle desde Maven Central. **No está incluido en la entrega.**

### iOS
#### Arquitectura técnica
 
- **AVFoundation** (`AVCaptureSession` + `AVCaptureVideoDataOutput`): captura de frames en tiempo real. Se usa `alwaysDiscardsLateVideoFrames = true` para el mismo efecto que `STRATEGY_KEEP_ONLY_LATEST` en Android.
- **SwiftUI + UIViewRepresentable**: la UI se construye completamente en SwiftUI. Como `AVCaptureVideoPreviewLayer` es un `CALayer` de UIKit y SwiftUI no puede alojarlo directamente, se usa `UIViewRepresentable` como adaptador.
- **Patrón ObservableObject / @Published**: `CameraManager` es un `ObservableObject`. Cuando publica un nuevo `edgeImage`, SwiftUI redibuja automáticamente la vista sin necesidad de actualizar manualmente el hilo principal más allá del `DispatchQueue.main.async`.
- **Puente Swift ↔ OpenCV (Objective-C++)**: Swift no puede llamar directamente a C++. Se usa un wrapper en `OpenCVWrapper.mm` (extensión `.mm` = Objective-C++) que expone una interfaz Objective-C limpia a Swift a través del bridging header. El pipeline OpenCV completo vive en este fichero.
- **Gestión de memoria**: en C++, los `cv::Mat` locales se liberan automáticamente al salir del scope (RAII), a diferencia de Android donde hay que llamar `.release()` manualmente.
- **Orientación de frames**: se fija `videoRotationAngle = 90` (iOS 17+) o `videoOrientation = .portrait` en la conexión de salida para que el overlay coincida con el preview.
 
#### Dependencias
 
OpenCV se integra vía **Swift Package Manager**:
 
```
https://github.com/opencv/opencv-spm  —  versión exacta 4.10.0
```
 
Las dependencias se descargan automáticamente al abrir el proyecto en Xcode. **No están incluidas en la entrega.**
 
> Para ejecutar la app iOS es necesario un dispositivo físico. La cámara no funciona en el simulador de iOS. Para ejecutar la app es necesario abrir el proyecto en Xcode y lanzarlo directamente sobre el dispositivo.

## Problemas encontrados
### Android
#### El overlay de bordes no coincidía con el preview
 
**Problema:** En algunos dispositivos, CameraX entrega los frames rotados respecto a cómo se muestra el preview. El resultado era que el overlay de bordes aparecía girado 90° respecto a la imagen real.
 
**Solución:** Se consulta `imageProxy.imageInfo.rotationDegrees` en cada frame y se aplica `Core.rotate()` sobre el `Mat` antes de iniciar el pipeline, usando los códigos `ROTATE_90_CLOCKWISE`, `ROTATE_180` o `ROTATE_90_COUNTERCLOCKWISE` según corresponda.
 
#### El contenido quedaba oculto bajo el notch y la barra de navegación
 
**Problema:** Al usar `enableEdgeToEdge()`, la app dibuja bajo las barras del sistema. El panel de controles quedaba parcialmente oculto bajo la barra de navegación, y el preview se iniciaba desde el borde superior sin respetar el notch.
 
**Solución:** Se aplica `ViewCompat.setOnApplyWindowInsetsListener` sobre la raíz del layout. El padding superior se asigna al `PreviewView` y el padding inferior (barra de navegación) se añade dinámicamente al panel de controles.
 
#### Crash al pasar un tamaño de kernel par a GaussianBlur
 
**Problema:** OpenCV lanza una excepción nativa si el tamaño del kernel de `GaussianBlur` es par. Un slider con rango directo podría producir valores pares.
 
**Solución:** La fórmula `v * 2 + 1` garantiza que el resultado siempre sea impar, independientemente del valor del slider.

### iOS
#### El archivo wrapper se creó como `.m` en lugar de `.mm`
 
**Problema:** Al crear el archivo `OpenCVWrapper` en Xcode, se generó con extensión `.m` (Objective-C) en lugar de `.mm` (Objective-C++). Además, Xcode detectó el bloque `#ifdef __cplusplus` y asignó automáticamente el tipo "C++ Source" en el inspector, cuando debía ser "Objective-C++ Source". Esto hacía que el compilador procesara el archivo como C++ puro, sin entender Objective-C, produciendo cientos de errores como `Unknown type name 'NSString'` y `Expected unqualified-id` en los headers de Foundation.
 
**Solución:** Se renombró el archivo a `.mm` desde Finder, se volvió a añadir al proyecto, y se cambió manualmente el tipo en el File Inspector de Xcode a **Objective-C++ Source**. Adicionalmente, se reordenaron los imports para que `#import <opencv2/opencv.hpp>` aparezca antes que cualquier header de Apple, ya que OpenCV define macros que pueden entrar en conflicto si los headers de Apple se cargan primero.
 
#### Los controles se deformaban al activar el filtro
 
**Problema:** Al pulsar Start y aparecer el overlay de bordes, el panel de controles inferior se redimensionaba y los sliders y etiquetas se veían más grandes y difíciles de usar.
 
**Solución:** El `Image` con `.scaledToFill()` expandía el layout al no tener un frame explícito. Se envolvió en un `GeometryReader` que lee el espacio disponible real y fija el frame de la imagen a esas dimensiones exactas, añadiendo `.clipped()` para que nada desborde.
 
#### La app no pedía permiso de cámara y aparecía en negro
 
**Problema:** La app arrancaba con pantalla negra y no aparecía en los ajustes de privacidad del iPhone. iOS no mostraba el diálogo de permiso.
 
**Solución:** Faltaba la clave `NSCameraUsageDescription` en el Info.plist. Sin esta clave iOS rechaza silenciosamente cualquier intento de acceso a la cámara sin mostrar ningún diálogo. Se añadió desde la pestaña **Info** del target en Xcode. Adicionalmente fue necesario desinstalar la app del dispositivo antes de volver a instalarla para que iOS mostrara el diálogo de permisos desde cero.

## Notas adicionales
 
- Ambas versiones han sido probadas en dispositivos físicos (Android e iOS). El emulador de Android tiene una cámara simulada que también permite verificar el funcionamiento básico de la UI; el simulador de iOS no tiene acceso a cámara real.