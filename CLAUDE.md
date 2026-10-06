# Ficonza — contexto del proyecto

App móvil en Flutter **Ficonza** (por el logo y el nombre, de finanzas). Solo Android por ahora. **Los módulos todavía no están definidos: el usuario los va a indicar.**

Se construye con la misma forma de trabajo que Vixago Player (`C:\Users\ANDRES\Documents\proyectos de apps\Vixago Player`), DownPlayer y Radio Colombia. Revisar sus `CLAUDE.md` para reutilizar patrones (idioma, apariencia, íconos, MethodChannel, audio en segundo plano, etc.).

## Cómo trabajar con el usuario

- Responder siempre en español.
- El usuario trabaja en Windows, con `cmd`, en la carpeta `C:\Users\ANDRES\Documents\proyectos de apps\Ficonza`.
- **No tiene Flutter, Java ni Android SDK instalados localmente.** El APK se compila en GitHub Actions al hacer push a `main`. No proponer `flutter run` local.
- Pasos manuales (git, GitHub, instalar en el celular) **uno a la vez** y en lenguaje simple.
- Para publicar cambios: `git add .`, `git commit -m "mensaje"`, `git push`.

## Cómo se compila

El repositorio **no contiene** `android/` ni `ios/`. El workflow `.github/workflows/compilar-apk.yml`:

1. Instala Java 17 y Flutter estable.
2. `flutter create --org com.ficonza --project-name ficonza --platforms=android .` (applicationId `com.ficonza.ficonza`) y borra `test/`.
3. Copia `plataforma/android/AndroidManifest.xml`, pega `plataforma/android/MainActivity.kt` conservando la línea `package` generada (**la primera línea de ese archivo debe ser siempre `package`**) y sube `minSdk` a 24 con `sed` en `build.gradle.kts`.
4. `flutter pub get` (si falla, `flutter pub upgrade --major-versions`).
5. `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create` (configurados al final de `pubspec.yaml`).
6. `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64` (salida en `build.log`) y sube ambos APK en el artifact `ficonza-apk`. **El que sirve para casi todos los celulares es `app-arm64-v8a-release.apk`.**
7. Si la compilación falla, el paso "Mostrar errores" publica los errores como anotaciones, que se leen sin iniciar sesión en `https://api.github.com/repos/<usuario>/<repo>/check-runs/<id del job>/annotations`.

El APK se firma con la llave debug de cada compilación: hay que desinstalar la versión anterior antes de instalar una nueva.

## Stack

- Flutter (SDK `^3.6.0`, Material 3). Stable en Actions es 3.47 o superior.
- `flutter_localizations` (SDK) y `shared_preferences`. Dev: `flutter_launcher_icons`, `flutter_native_splash`.
- Estado con `ChangeNotifier` + `ListenableBuilder` (sin provider ni riverpod). Dependencias por constructor desde `main.dart`.

## Estructura

```
lib/
  main.dart                          MaterialApp dentro de ListenableBuilder(preferences) para themeMode y locale
  theme.dart                         AppColors (azul #1F6BFF, cian #22C8F0, menta #3DEFC0, noche #0B1530), AppLogo, AppTitle
  l10n/strings.dart                  Clase S con todos los textos en español e inglés (_t('es', 'en'))
  services/preferences_service.dart  Apariencia (ThemeMode, por defecto del sistema) e idioma (null = sistema)
  screens/home_screen.dart           Pantalla provisional (logo + "Muy pronto") y menú lateral con Ajustes y Acerca de
assets/icon/
  app_icon.png     Símbolo sobre fondo redondeado (512), para Android viejo
  logo.png         Igual, 256, para dentro de la app (AppLogo)
  foreground.png   Solo el símbolo (F + barras) con fondo transparente, ~60% del lienzo (ícono adaptable y arranque Android 12+)
  background.png   Degradado vertical azul noche (#122044 -> #081228)
  logo_full.png    Logo completo con "Ficonza" (arranque en Android < 12 y pantalla de inicio)
plataforma/android/  AndroidManifest.xml (label "Ficonza") y MainActivity.kt (FlutterActivity)
```

## Decisiones

- **Logo.** El original (1254 px, fondo blanco alrededor del cuadro azul noche) trae el texto "Ficonza". En el ícono del celular va solo el símbolo (F + barras); el logo completo va en el arranque y en la pantalla de inicio. Recortes hechos con Pillow (alfa según el brillo).
- **Idioma.** `supportedLocales` `[en, es]` (inglés de respaldo), selector en el menú (Automático, Español, English). Regla: ningún texto fijo en pantallas, todo va a `S`.
- **Apariencia.** `themeMode` por defecto `ThemeMode.system`; selector en el menú.
- **Nombres.** Evitar nombres genéricos que choquen con Flutter (en Vixago Player, `RepeatMode` rompió la compilación con Flutter 3.47).

## Estado actual

- v0.1.0: base del proyecto (ícono, arranque, idioma, apariencia, pantalla provisional). Repositorio: https://github.com/vperea95/Ficonza (rama `main`). Esperando que el usuario defina los módulos.
