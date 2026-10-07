# Ficonza — contexto del proyecto

App móvil en Flutter **Ficonza**: presupuesto mensual personal. Pasa a la app la hoja de cálculo del usuario (Ingresos, Ingresos ocasionales, Gastos fijos, Gastos variables, Deducciones sobre ingresos y Resumen final) más un módulo de **Ahorros que se acumulan**: **cada tabla es un módulo con su propia pantalla** (el usuario no quiere todo en una sola página). Datos en SQLite en el dispositivo, con exportación a Excel, copia de seguridad JSON y reporte consolidado. Solo Android.

Se construye con la misma forma de trabajo que Vixago Player (`C:\Users\ANDRES\Documents\proyectos de apps\Vixago Player`), DownPlayer y Radio Colombia. Revisar sus `CLAUDE.md` para reutilizar patrones (idioma, apariencia, íconos, MethodChannel, audio en segundo plano, etc.).

## Cómo trabajar con el usuario

- Responder siempre en español.
- El usuario trabaja en Windows, con `cmd`, en la carpeta `C:\Users\ANDRES\Documents\proyectos de apps\Ficonza`.
- **No tiene Flutter, Java ni Android SDK instalados localmente.** El APK se compila en GitHub Actions al hacer push a `main`. No proponer `flutter run` local.
- Pasos manuales (git, GitHub, instalar en el celular) **uno a la vez** y en lenguaje simple.
- **Pedir autorización al usuario antes de hacer commit/push al repositorio** (lo pidió expresamente). Preparar los cambios en local y preguntar.
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

**Firma fija (Vixago).** La llave está FUERA del repositorio en `C:\Users\ANDRES\Documents\proyectos de apps\_firma-vixago\` (`vixago-release.p12`, PKCS12, alias `vixago`; contraseña y huella en `LEEME.txt`; `firma-base64.txt` para el secreto). Es la misma llave para todas las apps de Vixago. **Nunca subirla ni copiar la contraseña al repositorio.** El workflow:
- "Preparar firma fija": si existe el secreto `SIGNING_KEYSTORE_BASE64`, lo decodifica a `$RUNNER_TEMP/firma.p12`, exporta `SIGNING_KEYSTORE_PATH` y ejecuta `plataforma/android/configurar_firma.py`, que agrega `signingConfigs { create("vixago") }` y cambia el release de `debug` a `vixago` en `build.gradle.kts`. La contraseña llega en el secreto `SIGNING_KEYSTORE_PASSWORD` (variable de entorno del paso "Compilar APK").
- Sin los secretos, compila con la llave debug y deja un aviso (hay que desinstalar antes de cada versión).
- Antes de compilar, "Preparar firma fija" quita espacios/saltos de línea de la contraseña y la prueba con `keytool -list`; si no abre la llave, avisa (con el largo recibido; la contraseña real tiene 28 caracteres) y compila con la llave debug. La primera compilación con firma (v0.4.0, 06/10/2026) falló con "keystore password was incorrect" porque la contraseña no llegó bien desde el secreto.
- "Verificar firma" publica una anotación con el titular del certificado usando `apksigner verify --print-certs` del SDK (debe decir CN=Vixago). `keytool -printcert -jarfile` no sirve: con minSdk 24 el APK solo lleva firma v2/v3.
Con la firma fija, cada APK nuevo se instala encima del anterior sin perder datos. La primera vez que se pasa de la llave debug a la de Vixago sí hay que desinstalar una última vez.

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
  main.dart                          Abre la base de datos (store.load) antes de runApp; marca incomeSetupDone si ya hay datos; home = StartGate (configuración inicial o ShellScreen)
  theme.dart                         AppColors (azul #1F6BFF, cian #22C8F0, menta #3DEFC0, noche #0B1530), AppLogo, AppTitle
  l10n/strings.dart                  Clase S: todos los textos en español e inglés; meses; conceptos iniciales
  models/finance.dart                FinanceModule (5 tablas + saving/withdrawal), Entry (fundId), SavingsFund, MonthSummary (fórmulas), MonthId
  services/finance_db.dart           SQLite v2: months, entries, funds; migración v1->v2; fundMovements; dump/restore
  services/finance_store.dart        Mes abierto, renglones, fondos y saldos (FundStatus), empezar mes, guardar/borrar/deshacer/reordenar, summaries()
  services/export_service.dart       Excel (Consolidado + una hoja por mes), copia JSON, guardar (SAF), compartir, abrir archivo
  services/xlsx_writer.dart          Escritor mínimo de .xlsx (estilos, colores, celdas unidas, anchos, fechas)
  services/preferences_service.dart  Apariencia, idioma y moneda
  utils/money.dart                   Currency (COP sin decimales, USD, EUR, MXN), Money.format ("$ 1.234.567", "-" para cero), MoneyInputFormatter
  screens/shell_screen.dart          Pantalla principal: AppSection (7 módulos), barra con el color del módulo + MonthSelector, menú de módulos con totales
  screens/summary_page.dart          Módulo Resumen final: lo que sobra, SummaryTable, total ahorrado
  screens/module_page.dart           Módulo de renglones (sin AppBar propio): lista, reordenar, deslizar para borrar con deshacer, pagado, total; Deducciones con salud y pensión y ahorros por nómina
  screens/savings_page.dart          Módulo Ahorros: total acumulado, tarjeta por fondo (aporte/retiro del mes, meta), editor de fondo
  screens/fund_screen.dart           Detalle de un ahorro: saldo, historial, editar, archivar, eliminar
  screens/report_screen.dart         Consolidado anual: totales, barras ingresos vs gastos, tabla mes a mes
  screens/export_screen.dart         Excel (mes / año / todo) y copia de seguridad: guardar, compartir, restaurar
  widgets/entry_editor.dart          Hoja para agregar/editar un renglón
  widgets/summary_table.dart         SummaryTable (Resumen final) y MonthSelector
  widgets/start_month_card.dart      Mes sin empezar: copiar del anterior o empezar en blanco
  widgets/amount_dialog.dart         askAmount(): diálogo para escribir un valor
  screens/onboarding_screen.dart     Configuración inicial a pantalla completa (carrusel, una pregunta por pantalla) + StartGate
  models/benefits.dart               EmploymentInfo (datos laborales, JSON en settings), BenefitsCalculator (prima, cesantías, intereses, vacaciones), days360
  screens/benefits_page.dart         Módulo Prestaciones sociales: total a hoy, gráfico de barras (colores de reporte), detalle con fórmula y fecha de pago
  screens/employment_screen.dart     Formulario de datos laborales con fechas de corte sugeridas
plataforma/android/MainActivity.kt   Canal 'ficonza/files': "save" (ACTION_CREATE_DOCUMENT) y "open" (ACTION_OPEN_DOCUMENT)
```

## Base de datos (ficonza.db, versión 3)

- `months(id TEXT PK "AAAA-MM", health_pct REAL default 8, created_at)`: un mes existe cuando se "empieza".
- `entries(id, month, module, concept, amount REAL, date, note, applies_health, paid, position, created_at, fund_id)`; `module` es el nombre del enum (`income`, `occasional`, `fixed`, `variable`, `deduction`, `saving` = aporte, `withdrawal` = retiro).
- `funds(id, name, initial_balance, from_salary, goal, archived, created_at)`: cada ahorro.
- `settings(key TEXT PK, value TEXT)` (v3): `employment` = JSON de `EmploymentInfo`. Va en la copia de seguridad (formato v3).
- **Migración 1 -> 2** (`onUpgrade`): agrega `fund_id`, crea `funds` y pasa los renglones de Deducciones cuyo concepto contiene "ahorro"/"saving" a aportes de un fondo con ese nombre (por nómina). Restaurar una copia v1 hace la misma conversión.
- Si se cambia el esquema: subir `_version` en `FinanceDb` y agregar el paso en `onUpgrade` (no borrar datos del usuario).

## Fórmulas (MonthSummary)

- Salud y pensión = base (IBC) × `health_pct` / 100. Por defecto 8 % (4 % salud + 4 % pensión del empleado); editable por mes.
- Base (IBC) = ingresos salariales (`applies_health`) + **excedente no salarial**: lo no salarial que supere el 40 % del total de ingresos (regla del 40 %, Ley 1393 de 2010 art. 30). `MonthSummary.nonSalaryExcess`; en Deducciones se explica cuando aplica. No se calcula el Fondo de Solidaridad Pensional ni el tope mínimo/máximo del IBC.
- Total deducciones = salud y pensión + otras deducciones (módulo Deducciones) + **aportes a ahorros por nómina** (`from_salary`).
- **Ingresos netos = ingresos + ocasionales + retiros de ahorros − total deducciones − aportes a ahorros voluntarios.** (Los ocasionales se suman: decisión pendiente de confirmar con el usuario.)
- Saldo disponible (lo que sobra) = ingresos netos − gastos fijos − gastos variables.
- Saldo de un ahorro hasta un mes = saldo inicial + aportes − retiros de todos los meses <= ese mes.

## Prestaciones sociales (BenefitsCalculator, a la fecha de hoy)

- Días con año comercial de 360 días (`days360`, ambas fechas incluidas; día 31 y fin de febrero cuentan como 30). Cada periodo empieza el día siguiente a la última liquidación (o en la fecha de ingreso).
- Base de prima y cesantías = promedio mensual del periodo (CST art. 253) + auxilio de transporte si lo recibe (solo hasta 2 SMMLV; aviso si lo supera). El ingreso salarial de cada mes del periodo (`BenefitsCalculator.salaryForMonth`) es el registrado en la app si existe; si no, los ingresos salariales actuales (`FinanceStore.salaryItems`) con el valor anterior para los conceptos que cambiaron después de ese mes (`EmploymentInfo.incomeChanges`: concepto, valor anterior, mes desde el que gana el actual). Así quien se registra a final de año obtiene el promedio real (pedido del usuario: aumento de sueldo desde julio, bonificación y stand-by de 550 mil a 800 mil).
- Prima (CST art. 306) = base × días / 360. Cesantías (CST art. 249) = base × días / 360. Intereses (Ley 52 de 1975) = cesantías del periodo × días × 12 % / 360.
- Vacaciones (CST art. 186) = días trabajados desde las últimas vacaciones × 15 / 360 + días pendientes; valor = sueldo básico (renglón "Sueldo base") / 30 × días.
- Salario integral: prima, cesantías e intereses no aplican (CST art. 132).
- Valores legales por defecto (2026): SMMLV $1.750.905, auxilio de transporte $249.095 (editables en el formulario).
- Fechas sugeridas: prima hasta el último 30 de junio / 31 de diciembre; cesantías e intereses hasta el 31 de diciembre del año anterior.

## Decisiones

- **Configuración inicial (pedido del usuario: lo primero después del logo, sin menú ni módulos).** `StartGate` (en `onboarding_screen.dart`) muestra `OnboardingScreen` a pantalla completa mientras `income_setup_done` sea falso; al terminar o al omitir se pasa a `ShellScreen`. Es un carrusel con una pregunta por pantalla, flecha atrás, barra de progreso y "Omitir": bienvenida (con "Ya tengo una copia de seguridad", que restaura y entra directo) -> fecha de ingreso -> sueldo base -> ¿ingresos adicionales? -> formulario de un ingreso (tipo `IncomeKind`, nombre, valor, salud y pensión sugerida por la norma) -> "¿Deseas agregar otro ingreso?" (vuelve al formulario) -> si ingresó antes del mes actual: "¿En este año cambió tu sueldo o alguno de tus ingresos?" y por cada ingreso valor anterior + mes desde el que gana el actual -> preguntas de liquidaciones solo si aplican (prima si ingresó antes del último 30 jun/31 dic; cesantías e intereses si antes del 31 dic pasado; vacaciones si lleva un año o más; integral si gana 13 SMMLV o más) -> resumen -> "Empezar a usar Ficonza" (`saveIncomeSetup(..., employment:)`). El auxilio de transporte para prestaciones se toma del ingreso adicional de ese tipo. En `main.dart`, si ya hay datos (mes actual, meses anteriores o ingresos), se marca como hecho y no se muestra.
- **Prestaciones (pedido del usuario: "pensar como contador").** Módulo propio (`AppSection.benefits`) con gráfico de barras, que por ser reporte usa colores distintos. En Ingresos aparece una tarjeta que invita a configurarlo mientras falten los datos laborales.
- **Color uniforme (pedido del usuario).** Módulos, barras, botones, íconos y textos usan un solo color: el azul de la marca (`AppColors.blue`; en modo oscuro el `primary` es #6FA0FF). Barras y botones flotantes van en el tema (`appBarTheme`, `floatingActionButtonTheme`); las tarjetas grandes usan `AppColors.brandGradient`. **Los colores mezclados de cada tabla (`FinanceModule.color`) solo se usan en los reportes**: `report_screen.dart` y el Excel. Única excepción: el rojo de borrar (deslizar y confirmar eliminación).
- **Navegación (pedido del usuario).** Cada tabla es un módulo en su propia pantalla, elegido desde el menú ☰ (con el total del mes al lado). Arranca en Resumen final; "Atrás" vuelve al Resumen. La barra superior lleva el nombre del módulo y el selector de mes.
- **Ahorros (pedido del usuario).** Las deducciones de salario que son ahorro deben acumularse: cada fondo tiene saldo inicial, aportes mensuales, retiros y meta opcional. Por nómina = deducción; voluntario = se resta de lo que sobra; retiro = suma a lo disponible del mes. Archivar un fondo lo oculta y deja de copiarse.
- **Solo un mes hacia el futuro (pedido del usuario).** `FinanceStore.maxMonth` = mes actual + 1. `MonthSelector` no deja pasar de ahí, `openMonth` lo limita, "aplicar a los meses siguientes" solo llega hasta ahí y al abrir la app `deleteFutureCopies` borra los meses posteriores que solo tienen conceptos copiados (no toca los que tienen variables, ocasionales o retiros). En enero, Ingresos muestra un aviso para revisar el incremento anual.
- **Meses (pedido del usuario: nada de "copiar de octubre").** Al abrir un mes que no existe, si hay un mes anterior, `openMonth` lo crea solo con los conceptos fijos de ese mes: ingresos, gastos fijos, deducciones y aportes a ahorros (`FinanceStore.recurring`; `paid` en falso). Ocasionales, variables y retiros no se copian. `StartMonthCard` solo aparece si no hay mes anterior (antes del primer mes registrado) y empieza en blanco. Al editar un renglón fijo (o el aporte de un ahorro) que también está en meses siguientes, se pregunta "¿Aplicar también a los meses siguientes?" (`laterMonthsWith` / `saveForward` / `updateForward`, por módulo + concepto o por `fund_id`).
- **Exportar.** El Excel replica la hoja: tablas con los mismos colores (verde, azul, morado, rojo, naranja), "(−)" y saldo en verde o rojo. Formato de miles `#,##0` (o con decimales según la moneda). Guardar usa el selector del sistema (Descargas, Drive…) sin pedir permisos; compartir usa share_plus.
- **Copia de seguridad.** JSON `{format: "ficonza-backup", version: 2, exportedAt, months, funds, entries}` (los fondos conservan su id). Restaurar reemplaza todo (con confirmación) y acepta copias v1.
- **Excel.** Consolidado con columnas de retiros, deducciones, ahorros voluntarios y total ahorrado acumulado; cada mes incluye la tabla AHORROS (aporte, retiro, acumulado).
- **Borrar.** Deslizar quita el renglón de la lista al instante (lo exige `Dismissible`) y luego de la base; "Deshacer" lo vuelve a insertar sin id.
- **Logo.** Ícono del celular = símbolo (F + barras); logo completo con "Ficonza" en el arranque. Recortes con Pillow.
- **Idioma y apariencia.** `[en, es]` con inglés de respaldo; `ThemeMode.system` por defecto; selectores en el menú. Ningún texto fijo en pantallas.
- **Nombres.** Evitar nombres genéricos que choquen con Flutter (en Vixago Player, `RepeatMode` rompió la compilación con Flutter 3.47); por eso la sección se llama `AppSection`.

## Estado actual

- v0.1.0: base del proyecto (ícono, arranque, idioma, apariencia, pantalla provisional). Repositorio: https://github.com/vperea95/Ficonza (rama `main`). Esperando que el usuario defina los módulos.
- v0.2.0: los 6 módulos, base de datos, reporte consolidado, Excel y copia de seguridad. Compilada con éxito en Actions al primer intento (06/10/2026). Falta probarla en un celular.
- v0.3.0: cada módulo en su propia pantalla (menú de módulos), módulo Ahorros acumulativo, color uniforme (mezclados solo en reportes); base de datos v2 con migración. Compilada con éxito en Actions al primer intento (06/10/2026). Falta probarla en un celular.
- v0.4.0: firma fija Vixago en el workflow, asistente de ingresos, regla del 40 % y módulo de prestaciones sociales (base de datos v3). Compilada (06/10/2026): el primer intento falló por el secreto de la contraseña; al relanzar con los dos secretos la llave de Vixago abrió y firmó el APK.
- v0.5.0: configuración inicial con fecha de ingreso y liquidaciones, conceptos fijos que se repiten solos cada mes, aplicar cambios a los meses siguientes, verificación de firma con apksigner. Compilada con éxito (06/10/2026) y firmada con la llave de Vixago (apksigner: C=CO, O=Vixago, CN=Vixago). Falta probarla en un celular.
- v0.6.0: configuración inicial a pantalla completa en carrusel, antes de los módulos, con opción de restaurar una copia. Compilada con éxito (07/10/2026) y firmada con la llave de Vixago. Falta probarla en un celular.
- v0.7.0: cambios de ingresos durante el año (promedio real para prestaciones, también editables en Datos laborales), solo un mes hacia el futuro con limpieza de meses proyectados, aviso de enero.
