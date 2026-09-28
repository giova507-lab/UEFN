# Guía rápida (español)

Resumen para poner RIDE A SEA BEAST en marcha en UEFN. Los detalles de cada paso están en las guías en inglés que se enlazan.

> **Estado:** el código Verse está completo y pasó dos comprobadores estáticos y varias revisiones independientes, pero **nunca se ha compilado ni probado dentro de UEFN**. Cuenta con una ronda de correcciones al compilar por primera vez. Si me pegas los errores que muestre UEFN, los corrijo.

## 1. Copiar el código y compilar

1. Crea (o abre) un proyecto en UEFN. Una isla en blanco es lo más sencillo.
2. Copia todos los archivos de `Content/Verse/` a la carpeta Verse del proyecto (**Verse > Open Verse Explorer**). Deben quedar todos juntos, porque forman un solo módulo.
3. **No** copies `Optional/ExperimentalMoveInput.verse` salvo para pruebas privadas: usa una API experimental y con ella no se puede publicar.
4. Pulsa **Verse > Build Verse Code** y apunta los errores que aparezcan.

## 2. Ajustes de la isla

* **Jugadores máximos: 6**, todos contra todos.
* Construcción desactivada, **daño por caída desactivado** y sin límite de tiempo.
* Un océano (Water Body) cuya superficie esté a la altura `SeaLevelZ` del dispositivo de juego (0 por defecto).

## 3. Montaje mínimo jugable

Monta esto primero y luego amplía (sección 1 de [UEFN_SETUP_GUIDE.md](UEFN_SETUP_GUIDE.md)):

1. **Un** `sea_beast_game_device` en el centro de la isla central, a nivel del mar.
2. **Seis** `lagoon_device` (uno por laguna) con cartel de nombre, botón RIDE, botón de gestión y **4 incubadoras** (botón + cartel cada una).
3. **Seis** plataformas de montura (`mount_rig_setup`), cada una con un dispositivo **Chair**.
4. Visuales para las criaturas 1-5: un prop de exhibición y al menos un **Animated Mesh** de nado cada una.
5. Visuales para los huevos 1 (Pearl) y 2 (Sandy), y unos 20 `egg_spawn_point_device` en el arrecife que acepten `Common`.
6. Algunas zonas `sea_zone_device` de tipo Land alrededor de la isla central.
7. Un Player Spawner por laguna, añadido a `PlayerSpawners`.

Al iniciar la sesión, el Output Log debe mostrar:

```
RIDE A SEA BEAST - starting
Registry: <N> egg spawn points, <N> zones, <N> stations
RIDE A SEA BEAST - running
```

Cualquier línea `WARNING` del canal `sea_beast_log` indica qué falta configurar.

## 4. Lo primero que hay que probar

Estas tres cosas no se pueden confirmar sin UEFN:

1. **¿El jugador sentado se mueve con la silla (Chair)?** Si no, cambia `RiderAttachMode` a `PlatformStasis` en el dispositivo de juego y asigna un prop invisible en `Saddle`.
2. **¿Llegan Saltar, Agacharse, Esprintar y Disparar estando sentado?** Deberían verse en el HUD (salto, buceo, nado rápido, nadar).
3. **¿Aparecen todos los huevos y exhibiciones?** Hay un límite de props generados por isla. Para los huevos comunes usa `PlacedEggProps` (ver [PERFORMANCE.md](PERFORMANCE.md)).

Para probar más rápido, activa `DeveloperToolsEnabled` en el dispositivo de juego y abre la pestaña DEV del menú (mantén Recargar). Nunca aparece en una sesión publicada.

## 5. Controles

| Acción | Control |
|---|---|
| Dirigir | Mover la cámara |
| Nadar | Mantener Disparar (en móvil: tocar para empezar/parar) |
| Frenar / marcha atrás | Mantener Apuntar |
| Nado rápido | Esprintar (activa / desactiva) |
| Salto (breach) | Saltar en movimiento |
| Bucear | Mantener Agacharse |
| Desmontar | Saltar casi parado |
| Menú | Mantener Recargar |

## 6. Dónde está cada cosa

| Documento | Contenido |
|---|---|
| [UEFN_SETUP_GUIDE.md](UEFN_SETUP_GUIDE.md) | Cada dispositivo y cada campo que hay que rellenar |
| [WORLD_DESIGN.md](WORLD_DESIGN.md) | Anillos de biomas, distancias según velocidad, colocación de huevos |
| [BALANCE.md](BALANCE.md) | Tablas de criaturas, huevos, precios y fórmulas |
| [TEST_PLAN.md](TEST_PLAN.md) | Pruebas paso a paso (jugador nuevo, 6 jugadores, guardado…) |
| [CONTENT_BROWSER.md](CONTENT_BROWSER.md) | Estructura de carpetas y lista de assets |
| [PERFORMANCE.md](PERFORMANCE.md) | Límites de props, memoria y efectos |
| [PUBLISHING_CHECKLIST.md](PUBLISHING_CHECKLIST.md) | Qué revisar antes de publicar |

## 7. Ajustar el equilibrio

Todo el equilibrio está en los archivos de configuración: `CreatureConfig.verse`, `EggConfig.verse`, `ProgressionConfig.verse`, `MovementBalance.verse` y `GameConfig.verse`. La interfaz y la lógica usan las mismas funciones, así que un precio mostrado siempre coincide con el cobrado.

**Una vez publicado, nunca cambies ni reutilices los ID de criaturas o huevos**, porque el guardado los almacena. Añade los nuevos siempre al final.
