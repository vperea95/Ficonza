# Ficonza — contexto del proyecto

App móvil en Flutter **Ficonza**: presupuesto mensual personal. Pasa a la app la hoja de cálculo del usuario (Ingresos, Ingresos ocasionales, Gastos fijos, Gastos variables, Deducciones sobre ingresos y Resumen final): **cada tabla es un módulo**. Datos en SQLite en el dispositivo, con exportación a Excel, copia de seguridad JSON y reporte consolidado. Solo Android.

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
- `sqflite` (base de datos `ficonza.db`), `path`, `path_provider`, `shared_preferences`.
- `intl: any` (la versión la fija `flutter_localizations`; poner una versión fija choca) para el formato de dinero.
- `archive: ^4` para escribir el `.xlsx` a mano. **No usar el paquete `excel`**: exige `archive` 3 y choca con `flutter_launcher_icons` (que usa `image` → `archive` 4).
- `share_plus` 13 (`SharePlus.instance.share(ShareParams(files: [XFile(...)]))`).
- Dev: `flutter_launcher_icons`, `flutter_native_splash`.
- Estado con `ChangeNotifier` + `ListenableBuilder` (sin provider ni riverpod). Dependencias por constructor desde `main.dart`.

## Estructura

```
lib/
  main.dart                          Abre la base de datos (store.load) antes de runApp; MaterialApp en ListenableBuilder(preferences)
  theme.dart                         AppColors (azul #1F6BFF, cian #22C8F0, menta #3DEFC0, noche #0B1530), AppLogo, AppTitle
  l10n/strings.dart                  Clase S: todos los textos en español e inglés; meses; conceptos iniciales
  models/finance.dart                FinanceModule (5 módulos con el color de la hoja), Entry, MonthSummary (fórmulas), MonthId ("AAAA-MM")
  services/finance_db.dart           SQLite: tablas months y entries; dump/restore para copias
  services/finance_store.dart        Mes abierto, renglones, empezar mes (copiar anterior), guardar/borrar/deshacer/reordenar, summaries()
  services/export_service.dart       Excel (Consolidado + una hoja por mes), copia JSON, guardar (SAF), compartir, abrir archivo
  services/xlsx_writer.dart          Escritor mínimo de .xlsx (estilos, colores, celdas unidas, anchos, fechas)
  services/preferences_service.dart  Apariencia, idioma y moneda
  utils/money.dart                   Currency (COP sin decimales, USD, EUR, MXN), Money.format ("$ 1.234.567", "-" para cero), MoneyInputFormatter
  screens/home_screen.dart           Selector de mes, "Lo que te sobra", tarjetas de módulos, Resumen final, menú lateral
  screens/module_screen.dart         Un módulo: lista (reordenar, deslizar para borrar con deshacer, pagado), total; deducciones con salud y pensión
  screens/report_screen.dart         Consolidado anual: totales, barras ingresos vs gastos, tabla mes a mes
  screens/export_screen.dart         Excel (mes / año / todo) y copia de seguridad: guardar, compartir, restaurar
  widgets/entry_editor.dart          Hoja para agregar/editar un renglón
  widgets/summary_table.dart         SummaryTable (Resumen final) y MonthSelector
plataforma/android/MainActivity.kt   Canal 'ficonza/files': "save" (ACTION_CREATE_DOCUMENT) y "open" (ACTION_OPEN_DOCUMENT)
```

## Base de datos (ficonza.db, versión 1)

- `months(id TEXT PK "AAAA-MM", health_pct REAL default 8, created_at)`: un mes existe cuando se "empieza".
- `entries(id, month, module, concept, amount REAL, date, note, applies_health, paid, position, created_at)`; `module` es el nombre del enum (`income`, `occasional`, `fixed`, `variable`, `deduction`).
- Si se cambia el esquema: subir `_version` en `FinanceDb` y agregar `onUpgrade` (no borrar datos del usuario).

## Fórmulas (MonthSummary)

- Salud y pensión = (suma de ingresos con `applies_health`) × `health_pct` / 100. Por defecto 8 %; editable por mes. El "Auxilio de internet" inicial viene sin salud y pensión (no salarial).
- Total deducciones = salud y pensión + renglones del módulo Deducciones (ahorro vacacional, etc.).
- **Ingresos netos = ingresos + ingresos ocasionales − total deducciones.** (Decisión: la hoja original no mostraba dónde sumaban los ocasionales; si el usuario dice otra cosa, cambiar `netIncome`.)
- Saldo disponible (lo que sobra) = ingresos netos − gastos fijos − gastos variables.

## Decisiones

- **Meses.** Cada mes es independiente. Al abrir un mes sin empezar se ofrece copiar del mes creado más reciente anterior: ingresos, gastos fijos y deducciones (con `paid` en falso); ocasionales y variables no se copian. El primer mes de todos crea los conceptos de la hoja en cero.
- **Exportar.** El Excel replica la hoja: tablas con los mismos colores (verde, azul, morado, rojo, naranja), "(−)" y saldo en verde o rojo. Formato de miles `#,##0` (o con decimales según la moneda). Guardar usa el selector del sistema (Descargas, Drive…) sin pedir permisos; compartir usa share_plus.
- **Copia de seguridad.** JSON `{format: "ficonza-backup", version: 1, exportedAt, months, entries}`. Restaurar reemplaza todo (con confirmación).
- **Borrar.** Deslizar quita el renglón de la lista al instante (lo exige `Dismissible`) y luego de la base; "Deshacer" lo vuelve a insertar sin id.
- **Logo.** Ícono del celular = símbolo (F + barras); logo completo con "Ficonza" en el arranque. Recortes con Pillow.
- **Idioma y apariencia.** `[en, es]` con inglés de respaldo; `ThemeMode.system` por defecto; selectores en el menú. Ningún texto fijo en pantallas.
- **Nombres.** Evitar nombres genéricos que choquen con Flutter (en Vixago Player, `RepeatMode` rompió la compilación con Flutter 3.47).

## Estado actual

- v0.1.0: base del proyecto (ícono, arranque, idioma, apariencia, pantalla provisional). Repositorio: https://github.com/vperea95/Ficonza (rama `main`). Esperando que el usuario defina los módulos.
- v0.2.0: los 6 módulos, base de datos, reporte consolidado, Excel y copia de seguridad. Escrita completa, **sin compilar todavía**.
