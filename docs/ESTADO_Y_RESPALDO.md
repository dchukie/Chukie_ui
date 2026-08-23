# Chukie UI — estado del proyecto y respaldo

**Instantánea:** 2026-08-22
**Versión en `Chukie_Ui.toc`:** 0.5.4
**Interface WoW:** `120100, 120007` (Retail **12.1** + compat 12.0.7)  
**Cliente local detectado:** `12.1.0.69382` (`WoW.exe` / `.build.info`)

Este documento describe el estado del addon y cómo restaurarlo.

---

## Seriales / TOC

| Campo | Valor |
|-------|--------|
| `## Interface` | `120100, 120007` |
| `## Version` | `0.5.4` |
| Branch tipica | `dev` |

Hito **0.4.9** (2026-08-21): versión que corre bien en cliente. Incluye party grid clickeable,
barras 1–4 fijas 6 × 4 centradas (strata `MEDIUM`), transparencia por botón, Combat Log
configurable y el resto de paneles/alertas de 12.1.

Versión **0.5.0**: agrega columnas ciclo a PartyGrid. El clic derecho fuera de combate
incluye/excluye unidades y una macro `/click ch-cl-NombreDelHechizo` ejecuta la secuencia
mediante un botón seguro preconfigurado.

Versión **0.5.1**: unifica mejoras generales con el standalone sin incorporar ElvUI:
ventana `/chukie-party` desplazable con edición y macro por columna, dibujo inmediato al
crear columnas y anclaje por jugador también arriba/abajo en layouts Blizzard horizontales.

Versión **0.5.2**: PartyGrid lee la geometría de marcos ajenos con guardas de valores
secretos. Desde 12.0 un marco que recibió un secreto (barras de vida, resaltes de aura)
devuelve medidas secretas, y compararlas desde código con taint aborta la ejecución: eso
rompía el recorrido del árbol al buscar el marco de cada unidad. Ahora un dato ilegible
cuenta como desconocido, no se baja por ramas marcadas y `UnitIsUnit` pasa por el mismo
filtro para mapas restringidos.

Versión **0.5.3**: la distancia al marco anfitrión y los ajustes X/Y de PartyGrid pasan a
±600 px (antes `gap` iba de -60 a 300 y los ajustes a ±400), de modo que la grilla puede
alejarse media pantalla o quedar por encima del propio marco. Los sliders de la ventana
propia aceptan rueda del mouse, que mueve de a un paso: con 180 px de barra y 1200 de
recorrido el arrastre solo sirve para el grueso.

Versión **0.5.4**: las barras circunstanciales (misión, evento, vehículo, formas) se muestran
opacas en la barra 1, el paginado cubre además las barras de bonus 1–4 y, si el juego declara un
reemplazo que la barra 1 no cubre, se devuelve la barra con arte de Blizzard en lugar de dejar al
jugador sin la habilidad del evento. Detalle en «Barras circunstanciales en la barra 1».

También en **0.5.4**: el recorrido del árbol de party de PartyGrid tolera objetos prohibidos
(«Attempt to access forbidden object from code tainted by an AddOn»). Aparecían con ElvUI, así
que el fallo se veía en el standalone (0.4.4) y no acá: el error se repetía en cada evento y el
corte por fallos apagaba la grilla toda la sesión.

`Settings.CreateTextBox` **no existe** en la API de Blizzard (solo checkbox, slider y
dropdown). Acá siempre estuvo detrás de un `if`, así que las cajas de hechizo y de macro por
columna nunca se dibujan en **Marcos → Party**; desde 0.5.3 la sección ofrece un botón que
abre `/chukie-party`, donde sí se escribe el nombre/ID y se copia la línea `/click`. El
standalone las llamaba sin guarda y eso abortaba el registro del panel entero: ver
`tmp/Chukie_PartyGrid`.

`120100` es el Interface de **12.1 live**. Se mantiene `120007` como segundo valor por compat. Tras el patch:

```
/dump select(4, GetBuildInfo())
/chukieui auracheck 436336
```

En 12.1 esperable: `Interface == 120100`, `auraContainerAPI=true` y `displayBackend=container` para reglas aura “Presente”.

---

## Checklist día de 12.1

| Check | Estado |
|-------|--------|
| TOC `120100` primero | OK |
| `ActionBarLayouts.lua` en el TOC | OK |
| `CombatLog.lua` en el TOC (después de ActionBarLayouts) | OK |
| Sin `getglobal` / `setglobal` propios | OK |
| Sin `SecureAuraHeaderTemplate` | OK |
| Sin `COMBAT_LOG_EVENT_UNFILTERED` | OK (`LoggingCombat` no parsea CLEU) |
| `UIParentLoadAddOn` → `LoadAddOnWithErrorHandling` (+ fallback) | Corregido 0.3.1 |
| AuraContainer feature-detect + diferir create en combate | OK (`AlertsAuraContainer.lua`) |
| Guards `issecretvalue` en barras / mini / alertas CD | OK |

---

## Qué cambió respecto a 12.0.7 (impacto en Chukie)

| Área | Impacto |
|------|---------|
| **AuraContainer / AuraButton** | API oficial 12.1. Chukie ya tiene `AlertsAuraContainer.lua` con feature-detect + `AddAuraSlot`/`AddAuraGroup` + `includeSpellIDs`. |
| **UNIT_AURA / UnitAura secretos** | En secreto el payload/listado es más opaco. Path legacy de alertas por spellId/icon **sigue sin poder** identificar Mass Disintegrate en combate. |
| **Crear AuraContainer en combate** | Error intencional en 12.1 → Chukie difiere creación a `PLAYER_REGEN_ENABLED`. |
| **SecureAuraHeaderTemplate** | Eliminado en Mainline. Chukie no lo usaba. |
| **Private aura anchors** | Siguen siendo para private auras de encuentro, **no** para buffs personales ContextuallySecret (p.ej. Mass Disintegrate). |
| **Action bars / secret CD** | Sin cambio de diseño; ya hay guards `issecretvalue` en barras/mini barra/alertas CD. |
| **Alertas de CD en combate** | Reescrito: solo se leen campos NeverSecret (`isEnabled`, `isActive`, `isOnGCD`, `maxCharges`) y el swipe se dibuja con duration objects (`C_Spell.GetSpellCooldownDuration` / `GetSpellChargeDuration` + `SetCooldownFromDurationObject`), la única vía admitida con valores secretos. |
| **getglobal / setglobal** | Deprecados en 12.1. Chukie no los usa en código propio. |
| **UIParentLoadAddOn** | Renombrado a `LoadAddOnWithErrorHandling` en 12.1. Widgets del calendario/reloj usan el nombre nuevo con fallback. |

---

## Archivos de alertas (orden TOC)

- `Alerts.lua` — árbol grupo → efecto → regla, evaluación, host de overlays  
- `AlertsAuraContainer.lua` — motor 12.1 (delegación al cliente + `CreateSingleAuraContainer`)  
- `AlertsManager.lua` — editor `/chukie-aura` (lista de grupos + ventana de grupo)  
- `AuraPanel.lua` — panel de auras propio `/chukie-auras`  
- Media: `AlertsMedia.lua`, `AlertsUserMedia.lua`, `Media/Alerts/`

---

## Brújula horizontal

La cinta se reparenta al slot central del panel derecho, y ahí el cliente recalcula
su nivel: quedaba tapada por el minimapa. En cada `Layout()` se eleva un plano por
encima de `Minimap` / `MinimapCluster` (nivel del mapa + 20), sin contar su propio
plano en el cálculo para que no escale en cada pasada.

---

## Panel de auras (`/chukie-auras`)

Reemplazo de la barra de buffs cuando los iconos nativos quedan chicos: un slot por
hechizo elegido, cada uno con su `AuraContainer`, así que también muestra las auras
que Blizzard oculta al addon. Opciones: tamaño (24–256 px, aplicado por escala para
no recrear frames al arrastrar el slider), separación, auras por línea, dirección de
crecimiento, unidad y tipo (buff/debuff) por defecto, y unidad/tipo propios por aura
cuando se elige desde la instantánea. `Mover` desbloquea el arrastre y muestra guías
con el icono en gris, porque un hueco sin aura activa sería invisible.

Las auras se agregan por id o con un clic en la instantánea de auras activas
(`Refrescar` la recaptura). Como el addon no sabe cuáles están activas, los slots
**no se compactan**: cada aura vive siempre en su hueco. Los contenedores no se
pueden crear en combate; los que falten aparecen en `PLAYER_REGEN_ENABLED`.

---

## Combat Log configurable (0.4.9)

`CombatLog.lua` controla `LoggingCombat()` sin capturar CLEU dentro del addon: el archivo
lo sigue escribiendo el cliente en `Logs\WoWCombatLog.txt`. La celda elegida
(`reserved2`, `reserved3` o `reserved4`) muestra un icono a color mientras graba y
desaturado/tachado cuando está apagado. La consulta se cachea y sólo se resincroniza cada
5 segundos para convivir con el límite de llamadas de Blizzard y detectar `/combatlog` u
otro logger.

En **Panel izquierdo → Combat Log** se elige la celda, Advanced Combat Logging, parada al
salir y autoactivación independiente para mazmorras normal/heroica/mítica/M+, raids
LFR/normal/heroica/mítica, Timewalking, escenarios/Delves y PvP. M+ y raid mítica vienen
activadas por defecto.

La subpágina **Instancias específicas** obtiene M+ de temporada desde `C_ChallengeMode` y
mazmorras/raids desde Encounter Journal. Lista vacía significa todas las instancias de los
tipos habilitados; con una selección, además debe coincidir `instanceID` o challenge map
ID. «Añadir instancia actual» cubre contenido ausente del catálogo. El addon sólo apaga al
salir una sesión que él mismo autoactivó; nunca una iniciada manualmente o por otro addon.

La celda reemplazada se excluye de `MiniActionBar` y de las ranuras dinámicas, sin borrar
la acción Blizzard guardada. Un cambio de celda durante combate queda visualmente
pendiente hasta `PLAYER_REGEN_ENABLED`.

---

## Barras 1–4: matriz fija y transparencia por botón (0.4.7)

Las cuatro barras del panel izquierdo son una matriz fija de **6 botones × 4 barras**. Se
retiraron «Botones por barra» y los cuatro overrides por fila: el runtime ya no consulta
`leftNumButtons` ni `leftNumButtonsPerBar`, y la migración elimina esas claves de perfiles
viejos para que no parezcan activas.

La subpágina **Barras de acción → Transparencia 6 × 4** es un canvas propio de Settings:
reproduce las cuatro filas, muestra el icono actual de cada ranura y pone debajo un
deslizador de 10–100 % más una caja de texto numérica (0.4.8). El porcentaje queda legible
aunque el icono esté al 10 %. «Restaurar 100 %» limpia toda la matriz.

Deslizador y caja son dos vistas del mismo valor: el deslizador usa paso 1 para que
cualquier número tipeado sea representable, al arrastrarlo se reescribe la caja y al
escribir se mueve el deslizador. Los dos sentidos se protegen con banderas `_syncing` para
que la sincronización no vuelva a disparar el guardado. Mientras se tipea sólo se aplica lo
que ya está dentro de 10–100 (así «3» no salta a 10 antes de completar «37»); al confirmar
con Enter o al perder el foco se recorta al rango y el texto vacío vuelve al valor vigente.
`Refresh()` (al abrir la subpágina y tras «Restaurar 100 %») repinta iconos, deslizadores y
cajas desde el perfil.

Los valores viven por perfil en `actionBars.leftButtonAlphaPercent[barra][botón]`. Se
aplican con `SetAlpha` al botón completo (icono, borde Masque, hotkey, cargas y cooldown).
En combate se guarda el valor y el refresco se difiere a `PLAYER_REGEN_ENABLED`. La
duplicación de perfiles copia explícitamente las cuatro filas para no compartir tablas.

---

## Barras 1–4: bloque centrado en pantalla (0.4.8)

La matriz 6 × 4 ya no cuelga del grupo del panel izquierdo. Las cuatro barras se
reparentan a `ChukieUi_LeftBarsBlock`, un contenedor propio hijo de `UIParent` que se
dimensiona con el ancho de fila y el alto total (filas + separación) y se ancla
`CENTER` → `CENTER` de `UIParent`. Así el centro del bloque coincide con el centro de la
pantalla y «Offset X/Y» lo desplazan desde ahí. Se oculta en `HideAll()` y cuando
`leftEnabled` está apagado.

El contenedor usa strata `MEDIUM` (nivel 20; las barras, 25) con `SetFixedFrameStrata`.
La primera versión heredó el `TOOLTIP` nivel 65521 del panel izquierdo y dibujaba las
barras encima de menús, diálogos y alertas (`Alerts.lua` usa `HIGH`); ahora quedan debajo.
Cada `LayoutLeftBars()` reafirma strata y nivel porque `SetParent` propaga los del padre.

Rango de posición ampliado (más del triple del anterior): **Offset X −1800 a 1800** y
**Offset Y −1200 a 1200**, paso 1 px, con el mismo clamp aplicado en el layout para valores
guardados fuera de rango. Los defaults pasan a `0`.

Como los valores viejos apuntaban a la esquina inferior izquierda del panel, la migración
`MigrateActionBarsLeftCenterAnchor` los pone en `0` una sola vez por perfil
(marca `actionBars._leftCenterAnchorApplied`), también al cambiar de perfil con
`SetCurrent`. El bloque se re-anchora fuera de combate; en combate el refresco queda
diferido a `PLAYER_REGEN_ENABLED`.

---

## Barras circunstanciales en la barra 1 (0.5.4)

Cuando el juego reemplaza la barra del jugador —vehículo, misión con barra propia (override),
posesión, shapeshift temporal o una barra de bonus— la barra 1 pagina a esas acciones. Tres
cosas cambian en 0.5.4.

**Opacidad.** Mientras dura la situación, los seis botones de la barra 1 van a 100 %: son
acciones que aparecieron solas y la transparencia configurada podía dejarlas casi invisibles. Al
terminar, cada celda recupera su porcentaje de `leftButtonAlphaPercent`. Skyriding queda afuera a
propósito: es un modo que el jugador elige, con su propio paginado, no una barra circunstancial.
`SetAlpha` no es una llamada protegida, así que el cambio también entra en combate.

**Paginado de barras de bonus.** `buildPageStates` agrega `[bonusbar:1..4] → páginas 7–10`
(`bonusPaging`, por defecto activo), el mismo cálculo que hace `ActionBarController` con
`6 + GetBonusBarOffset()`. Antes solo estaban vehículo, override, shapeshift temporal y
`[bonusbar:5]` (skyriding): si el juego cambiaba a una barra de bonus —una habilidad temporal de
misión, una forma, el sigilo—, la barra 1 se quedaba en la página normal mostrando las
habilidades del jugador y las acciones del evento no aparecían en ninguna parte. Esas páginas se
suman también a `GetLeftActionSlots()`, que ahora filtra duplicados (la página 8 es
`SKY_PAGE[1]` y `BONUS_PAGE[2]` a la vez).

**Red de seguridad: la barra de Blizzard.** `HideOverrideArtBar` pasa a ser
`UpdateOverrideArtBar` y decide en cada cambio de situación. `ReplacementBarState()` consulta por
API qué reemplazo puso el juego (mismo orden de prioridad que Blizzard) y `ReplacementCoverage()`
mira si la barra 1 tiene un `offset-<estado>` para ese caso. Si hay reemplazo **sin cubrir**
—paginado apagado o un estado que el driver seguro no contempla— `OverrideActionBar` vuelve a
`UIParent` y se fuerza su `Show()` en los estados que ese marco atiende (vehículo y override);
en cuanto la barra 1 vuelve a cubrir la situación, regresa al contenedor oculto. Antes el marco
se escondía una vez y revertirlo pedía `/reload`, así que un cambio de situación tras morir podía
dejar al jugador sin ninguna forma de usar la habilidad del evento.

`SetParent`/`Show` sobre un marco protegido no se pueden llamar en combate: si la situación cambia
ahí, queda `_pendingOverrideArt` y se aplica en `PLAYER_REGEN_ENABLED`. La detección corre en los
eventos de situación (incluidos `PLAYER_DEAD`, `PLAYER_ALIVE` y `PLAYER_UNGHOST`) y no en los de
cooldown, que llegan demasiado seguido.

Las consultas de estado pasan por `apiFlag`, que tolera que la función no exista y descarta
valores secretos: desde 12.0 comparar un secreto desde código con taint aborta la ejecución.

`/chukieui barras` imprime el reemplazo detectado, si la barra 1 lo cubre, el `bonusbar` actual,
las tres opciones de paginado, el estado y offset de la barra 1 y quién tiene
`OverrideActionBar`.

Límite conocido: cuando el reemplazo es una barra de bonus y `bonusPaging` está apagado, no hay
marco de Blizzard que devolver (esas acciones las muestra la barra principal, que el addon
oculta). Por eso la opción viene activa.

---

## Grilla de party clickeable (`/chukie-party`)

Grilla propia de `player` + `party1..4` con una habilidad distinta por columna, pegada por defecto
al costado de la grilla de party de Blizzard (`CompactPartyFrame`,
`CompactRaidFrameContainer` o `PartyFrame`, el primero visible) y con posición libre
arrastrable si esa grilla no está a la vista.

Separación de capas, tal como pide el modelo de 12.1:

- **Capa segura**: cada celda es un `SecureActionButtonTemplate` directo con `unit`
  fijo, `type1 = spell` y `spell1 = ID` de su columna (el ID numérico es válido: el
  template usa `CastSpellByID` cuando el atributo es un número). No hay `type2`, menú,
  target, `ClickCastFrames` ni `ClickCastUnitTemplate`. Se registran `LeftButtonDown` y
  `LeftButtonUp` con `useOnKeyDown = false` (cast al soltar, independiente del CVar
  `ActionButtonUseKeyDown`), más `RightButtonUp` desde 0.5.0 para editar la lista de las
  columnas ciclo: no hay `type2`, así que el derecho nunca ejecuta una acción de juego.
  Los atributos se aplican solo fuera de combate.
- **Capa visual**: celda cuadrada con icono del hechizo, cooldown real, cargas,
  usabilidad/recursos, rango por unidad, tooltip, highlight, vida y rol opcionales.
  `isOnGCD` oculta el swipe del GCD y además el duration object se pide con
  `C_Spell.GetSpellCooldownDuration(id, true)` (`ignoreGCD`), así el barrido global
  tampoco entra por la vía del widget; `isActive` decide cooldown/recarga. Rango o
  usabilidad secretos o desconocidos dejan color neutral: nunca se comparan.
- **Costo por pase**: icono, cooldown, cargas y usabilidad son idénticos en las cinco
  celdas de una columna, así que se calculan una vez por columna y no una vez por celda.
  El `Cooldown` solo se reasigna cuando cambia la firma de estado de la columna. El
  pulso de 0,2 s revisa únicamente el rango (eso sí es por unidad) y se apaga junto con
  la grilla, igual que los eventos de hechizo.

La vida se pasa tal cual al `StatusBar` (`SetMinMaxValues` / `SetValue` bajo `pcall`):
si el cliente la entrega como valor secreto igual se dibuja, y el addon nunca la
compara ni la usa como condición. Nada de elegir objetivos ni cambiar hechizos.

Toda configuración de PartyGrid se centraliza en `SetOption`/`SetColumnSpell` y se
rechaza durante `InCombatLockdown()` sin escribir SavedVariables ni tocar atributos,
tamaño, posición o pool; apagar la grilla cuenta como configurar y también se rechaza.
Los controles propios se deshabilitan. Los proxy de Settings no se pueden deshabilitar
en caliente, así que el rechazo les reescribe el valor real del perfil con
`setting:SetValue`, marcado con un guardia para que ese rebote no vuelva a entrar por el
setter (nada de recursión Settings ↔ `SetOption`). Cerrar la ventana propia en combate
con la grilla suelta no puede fijarla: queda anotado y se fija en
`PLAYER_REGEN_ENABLED`, que además resincroniza layout, pool, controles y atributos. La
visibilidad general va por state driver
(`[group:party][group:raid]`), con opción de mostrarla en solitario.

Aislamiento (0.3.2, revisado en 0.4.2): el handler de eventos y el pulso corren bajo
`xpcall` y, si el fallo se repite tres veces, apagan la grilla **solo por esta sesión**
(`PG._killed`) sin tocar el perfil, informan por chat y reenvían el error a
`geterrorhandler()` para que quede la traza; los eventos de unidad solo se escuchan
mientras la grilla está activa; y el botón de ayuda **no** llama a `ShowUIPanel` (abrir
paneles de Blizzard desde un addon contamina `UIParent_ManageFramePositions` y puede mover
u ocultar otros marcos, entre ellos el cluster del minimapa). Interruptor rápido sin UI:
`/chukieui party on | off`; estado: `/chukieui party diag`.

Correspondencia con la grilla de Blizzard (0.3.7), en tres piezas:

1. **Visibilidad atada sin Lua**: el host cuelga del contenedor de Blizzard
   (`CompactPartyFrame` / `CompactRaidFrameContainer` / `PartyFrame`, desde 0.4.2 el que se
   está dibujando y no el primero que exista) vía `SetParent`. Si
   el juego oculta su grilla, la nuestra desaparece con ella, también en combate, donde
   ocultarla por código no está permitido. Con `attachToBlizzard` la casilla «Mostrar en
   solitario» queda deshabilitada porque ya no decide nada.
2. **Mismo orden**: `BlizzardUnitFrames` recorre el árbol del contenedor (hasta 8
   niveles) y lee `child.unit` o el atributo seguro `unit`; después mapea unidad → marco
   comparando con `UnitIsUnit`, así un `raid3` casa con nuestro `party2`.
   Desde 0.4.6 el recorrido **salta la propia grilla** (`_chukieGrid`): ver más abajo.
   El árbol se recorre rama por rama y tolerando lo ilegible: `frameChildren` pide los hijos
   bajo `pcall` y cada hijo se examina dentro de otro `pcall`. Un **objeto prohibido** (de los
   que el cliente se reserva; con ElvUI aparecen en el árbol de la party) aborta cualquier
   acceso desde código con taint —incluso preguntar si lo es—, así que se descarta esa rama en
   lugar de perder el mapa completo. Antes el error se repetía en cada evento y el corte por
   fallos apagaba la grilla toda la sesión (0.5.4).
   El orden sale de la posición real de cada marco suyo, ordenado por clave numérica y no
   por comparador de posiciones (un comparador contradictorio aborta `table.sort`), de
   modo que respetamos su ordenamiento por rol o grupo sin replicar sus reglas.
3. **Sin desfase acumulado**: con `perUnitAnchor` cada grupo de celdas se ancla al marco
   de su unidad en cualquiera de los cuatro lados. El bloque de columnas se centra sobre
   ese marco, también en parties Blizzard horizontales con celdas arriba/abajo. Las
   unidades sin marco propio se encadenan detrás de la última. La opción se puede apagar
   para volver al bloque único.

Al mover, el host cuelga de `UIParent` (si no, con la grilla de Blizzard oculta no habría
nada que arrastrar), pero los anclajes por celda se siguen usando cuando su grilla está a
la vista, para poder comprobar que coinciden. El layout se recalcula con
`EDIT_MODE_LAYOUTS_UPDATED` y con los callbacks `EditMode.Enter` / `EditMode.Exit`
(registrados con `pcall`: si el cliente no los publica, nunca se disparan).

Para probar estando solo hay una forma mejor que simular nada: **armar un grupo de
seguidores por la cola de LFG**. Con eso las dos grillas aparecen con miembros reales, así
que se ve la correspondencia de verdad y el click funciona. Por eso el modo debug de 0.3.6
(celdas y datos inventados) se quitó en 0.3.9: era una segunda ruta de código que había
que mantener al día para algo que el propio juego resuelve mejor.

Opciones en el menú del addon (0.3.9): subcategoría **Marcos**, con las secciones «Party:
grilla clickeable» y «Party: posición» (activar, tamaño, separación entre jugadores,
columnas por jugador, separación entre columnas, dirección de crecimiento, orientación,
incluir jugador, vida, rol, pegada a Blizzard, lado, distancia, ajuste X/Y y mostrar en
solitario). `/chukieui party` abre esa página; `/chukie-party` sigue abriendo la ventana
propia, que queda para lo que el menú no puede hacer: **Mover** necesita la pantalla
despejada para arrastrar. Las dos ventanas escriben las mismas claves del perfil, así que
`Layout` sincroniza la ventana propia si está abierta. Los rangos y las etiquetas de las
listas los publica `PartyGrid.lua` (`PG.LIMITS`, `PG.SIDES`, `PG.SIDE_LABELS`,
`PG.ORIENTATIONS`, `PG.ORIENTATION_LABELS`) para no tener los límites escritos dos veces.

Columnas por jugador (0.4.0): la grilla pasó de una columna × N jugadores a **C columnas ×
N jugadores**. Cada jugador tiene una fila de celdas y todas llevan la misma unidad
detrás; desde 0.4.1 cada columna corresponde a una habilidad. Claves: `columns` (1–8),
`columnSpacing` (0–20 px) y `growth` (`RIGHT` por defecto, más `LEFT`, `DOWN` y `UP`),
además de `spacing`, que ahora es solo la separación entre jugadores.

Habilidades por columna (0.4.1): `partyGrid.columnSpells[columna]` guarda el spell ID por
perfil (la duplicación copia esta tabla explícitamente). Soltar un hechizo del libro en
cualquier celda asigna toda la columna. Arrastrar desde una celda a otra columna mueve la
asignación (reemplaza destino y vacía origen); cancelar o soltar fuera conserva el origen.
El movimiento solo se toma como tal si el hechizo que trae el cursor es el mismo que salió
de la celda de origen, así un arrastre viejo nunca puede vaciar una columna ajena; el
descarte de ese estado va diferido un frame porque `OnDragStop` puede llegar antes que el
`OnReceiveDrag` del destino. El ID sale del cuarto retorno de `GetCursorInfo` (el segundo
es un índice del libro, no un ID). Solo se aceptan hechizos. La ventana propia muestra
nombre/ID y permite limpiar; **Marcos → Party** ofrece campos de estado de solo lectura y
botones para limpiar.

El clic no casteaba (arreglado en 0.4.3): las celdas registraban solo `LeftButtonUp` y no
fijaban `useOnKeyDown`, así que la fase que ejecuta la acción quedaba a cargo del CVar
`ActionButtonUseKeyDown`. Con ese CVar en «pulsación», el botón seguro nunca recibía la fase
que esperaba y el clic no hacía nada: sin error, sin aviso y con el icono correcto a la
vista. Ahora se registran **las dos fases** (`LeftButtonDown` y `LeftButtonUp`) y el botón
fija `useOnKeyDown = false`, así ejecuta siempre en el release, que además es lo que
necesita el arrastre (la celda es también el asa para asignar hechizos: casteando en la
pulsación, empezar a arrastrar lanzaría el hechizo). El resto de los botones seguros del
addon ya lo hacían así; la grilla era la excepción. Un `PostClick` anota el último clic
recibido —unidad, columna, hechizo y fase— y `/chukieui party diag` lo imprime junto al
valor del CVar: si algún día no castea, eso dice si el clic llegó al botón seguro o no.

Masque (0.4.4): si está instalado, las celdas se registran en el grupo independiente
**`Chukie UI → PartyGrid`**, separado de `ActionBars` y `RightStrip`, para poder asignarle
otra skin. Masque recibe las regiones propias de icono, cooldown, cargas y borde normal;
el resaltado, rol, borde de objetivo y vida siguen controlados por PartyGrid. La opción
«Usar Masque» está en **Marcos → Party** y en la ventana propia, activada por defecto.
Agregar/quitar botones y aplicar la skin se difiere hasta salir de combate.

Opacidad (0.4.5): `alphaPercent` (10–100 %, por defecto 100) se aplica con `SetAlpha` **al
host**, así que las celdas la heredan y un solo valor cubre iconos, vida, cooldown, rol y
bordes sin recorrer región por región —también con una skin de Masque puesta, que no toca
el alfa—. El piso es 10 y no 0 a propósito: una grilla invisible no se distingue de una que
falla. Mientras está en modo **Mover** se fuerza opaca, porque arrastrar algo translúcido
con la pantalla despejada no tiene sentido. El deslizador está en **Marcos → Party** y en la
ventana propia; `/chukieui party diag` imprime la opacidad real del host.

«Cannot anchor to itself» al cargar fuera de grupo (arreglado en 0.4.6): `Layout` cuelga el
host del contenedor de Blizzard **antes** de escanearlo, así que nuestras celdas pasan a ser
hijas suyas. Y como cada celda lleva su propio campo `unit`, `BlizzardUnitFrames` las tomaba
por marcos de party: el mapa devolvía una celda nuestra como marco de su unidad y
`SetPoint` fallaba con «Cannot anchor to itself», abortando el layout a mitad de camino (el
resto de las celdas quedaba sin punto). Solo se veía fuera de grupo con «mostrar en
solitario»: ahí los marcos de Blizzard no se dibujan y los nuestros sí, así que ganaban el
escaneo. Ahora el host y las celdas llevan la marca `_chukieGrid`, el recorrido no entra en
lo nuestro, y además `Layout` descarta un `ref` que sea la propia celda antes de anclar.

Detalles que importan:

- **Celdas por columna, nunca destruidas** (`EnsureColumns`): son botones seguros, y
  crearlos en combate no está permitido. Cambiar el número de columnas en pelea se
  rechaza sin guardar. El pool se completa por columna y luego por unidad para que nunca
  queden filas activas con cantidades distintas. El techo es 8 por unidad (40 botones
  con los 5 jugadores) para que la cuenta total sea previsible.
- **La fila sigue a su unidad**: la celda de la columna 1 es la que se ancla al marco de
  Blizzard (o a la fila propia) y las demás cuelgan en cadena de la anterior según
  `growth`. Así, si Blizzard mueve su grilla, la fila entera acompaña sin recalcular nada.
- **Crecimiento hacia atrás**: con `LEFT` o `UP` las columnas salen hacia el borde
  contrario de la caja del host, así que la primera celda arranca corrida (`colBack`) para
  que el bloque siga entrando en el rectángulo que se arrastra.
- **El rol va solo en la columna 1**: es un dato de la unidad, no de la columna, y
  repetirlo en cada celda solo tapaba el centro, que es donde va a ir el icono del debuff.

Por defecto: 1 columna, pegada a la derecha de la grilla de party de Blizzard y creciendo
hacia la derecha.

Celda cuadrada, sin nombre (0.3.9): la grilla usa el centro para el icono del hechizo de
la columna y permite lanzarlo sobre la unidad con un clic. Así que se
quitó el `FontString` del nombre y su casilla, y `width`/`height` pasaron a una sola clave
`size` (16–100 px) con el deslizador «Tamaño de celda»; el perfil viejo arranca del valor
que tenía en `height`. El icono de rol se mudó a la esquina inferior izquierda para dejar
el centro libre.

---

## Columnas ciclo y acción de macro (0.5.0)

Una columna se puede marcar como **ciclo** (`columnCycles[n]` en el perfil). Con eso el clic
derecho **fuera de combate** agrega o quita a esa unidad de `columnCycleUnits[n]`, que guarda
el orden de marcado, y las celdas cuya unidad no está en la lista se dibujan apagadas
(`SetDesaturated` + vertex color oscuro). El clic izquierdo no cambia: sigue lanzando el
hechizo de la columna sobre la unidad de su fila.

El avance en combate lo hace un botón seguro propio, uno por columna con ciclo, llamado
`ch-cl-<NombreDelHechizo>` (nombre del cliente, sin espacios ni caracteres que separen
argumentos de macro). Se usa desde una macro con `/click ch-cl-Prescience`. El botón lleva
`type = spell`, `spell = ID`, `pressAndHoldAction` y `typerelease = spell` (sin esto último,
`/click` no dispara según el CVar `ActionButtonUseKeyDown`), y un `SecureHandlerWrapScript`
en `PreClick` que en la fase de release avanza al siguiente `UnitExists` de la lista y
escribe `unit`. Todo lo demás (crear el botón, poblar la lista, cambiar el hechizo) ocurre
fuera de combate, en `ApplyCycleAttributes`, y en combate queda pendiente igual que el resto
del módulo.

**Trampa que costó una pasada de depuración**: la lista de unidades no puede vivir en
`unit1`, `unit2`, … porque para un `SecureActionButton` esos son atributos *modificados* (la
unidad de cada botón del mouse). El `/click` entra como botón izquierdo, el cliente resuelve
`unit1` y descarta el `unit` que el snippet acababa de escribir, así que el hechizo caía
siempre sobre el primero de la lista. La lista vive en `cycleUnit1..N`, y al reaplicar
atributos se limpian los `unitN` heredados de la versión anterior.

Restricciones que no se pueden esquivar: no hay selección por vida, rango ni aura (además,
en 12.1 esos valores pueden ser secretos), no hay casteo sin pulsación real del jugador, y un
comando slash del addon no sirve para castear en combate porque corre como Lua sin
privilegios. Dos columnas no pueden compartir hechizo en modo ciclo: compartirían el nombre
global de la acción, y el conflicto se rechaza al asignar. `/chukieui party diag` imprime,
por columna con ciclo, la macro, las unidades, el índice y la unidad activa.

---

## Panel derecho en 1x1 tras un /reload en combate (arreglado en 0.3.4)

Síntoma: minimapa, widgets y franja desaparecen todos juntos, las barras siguen bien y
**no hay ningún error de Lua**. El `diag` lo delata: `Panel tam=1x1 anclas=1` y los slots
con posiciones negativas (fuera de pantalla).

Causa: mientras el panel aloja al `MinimapCluster` queda protegido, así que en combate
`PanelCore` no puede redimensionarlo y posterga el layout (`pendiente_layout=true`). Pero
el resto de `ApplyMinimapClusterInRightPanel` seguía corriendo y anclaba el cluster y los
slots a un host de 1x1: todo colapsaba a un punto de la esquina inferior derecha. Si el
primer layout de la sesión caía en combate (un `/reload` en plena pelea), el panel se
quedaba así hasta que la pelea terminara.

Arreglo, en tres capas:

1. **Geometría al nacer** (`EnsureRightPanel`): el panel recibe tamaño y ancla justo al
   crearse, cuando todavía no aloja al cluster y por lo tanto no está protegido. Funciona
   incluso en combate y es lo que elimina la causa raíz.
2. **Nunca colapsar** (`isHostUsable`): si el host mide menos de 8 px, no se ancla nada
   adentro (cluster, slots, widgets, franja). El minimapa se queda donde lo puso Blizzard,
   visible, en vez de irse fuera de pantalla.
3. **Recuperación garantizada**: `RightPanel` escucha `PLAYER_REGEN_ENABLED` y el watcher
   de `PanelCore` reaplica siempre al salir de combate. Manual: `/chukieui fix`.

---

## Mini barra (celdas 2–4) al recargar en combate (0.3.5)

Las celdas 2–4 son botones de acción seguros sobre los slots 145–147 (Action Bar 6).
WoW no permite crear ni configurar marcos seguros en combate, así que un `/reload` en
plena pelea dejaba las tres celdas vacías. No se puede evitar la restricción, pero sí
sus dos consecuencias:

- **Marcador provisorio**: mientras no se puedan armar los botones, la celda muestra el
  icono real de su slot (leído con `GetActionTexture`, ignorado si viene como valor
  secreto; si no se puede leer, un signo de pregunta), desaturado. Se ve qué hay puesto,
  aunque el clic recién funcione al terminar el combate. Nunca se pisa una celda que ya
  tenga el botón seguro enganchado.
- **Rearmado garantizado**: `OnRegenEnabled` ya no exige marcas de pendiente (si la UI
  cargó en combate no hay marca que valga) y `MiniActionBar` registra su propio watcher
  de `PLAYER_REGEN_ENABLED` desde el primer `EnsureButtons`/`AttachToSlots`, sin depender
  de que alguien haya llamado a `Refresh`. Además guarda las celdas en `_lastSlots` para
  poder reengancharse sin `RightPanelWidgets`.

---

## Posición de la entrada de chat (0.3.8)

La caja de entrada del sector chat general es el `ChatFrame1EditBox` de Blizzard
reparentado al grupo del panel izquierdo; su ancho lo fijan dos anclas horizontales y su
alto la banda libre entre L3 y L4, así que no hay un punto único que se pueda arrastrar.
Para poder ajustarla hay dos sliders nuevos en **Panel izquierdo → Sector chat general**:
«Mover entrada chat X» y «Mover entrada chat Y» (`leftPanelGeneralInputOffsetX` /
`OffsetY`, −600 a 600 px, positivo = derecha y arriba).

Los offsets se suman a las dos anclas a la vez, de modo que la caja se mueve sin cambiar
de ancho, y se aplican también en la rama de reserva (cuando la banda L3/L4 queda por
debajo de 8 px). El grupo del panel no recorta hijos, así que la entrada puede salirse de
su sector si hace falta. Para mover todo el panel siguen estando «Mover conjunto X/Y».

---

## La grilla de party desaparece y no vuelve con /reload (arreglado en 0.4.2)

Síntoma: la grilla funciona un rato y en algún momento (al morir y reaparecer) se va.
La grilla de party de Blizzard sigue a la vista y un `/reload` no la trae de vuelta.

Eran dos cosas distintas, y las dos sobrevivían al `/reload`:

1. **El corte por error escribía el perfil.** El aislamiento del módulo, ante el primer
   fallo en su manejador de eventos, llamaba a `SetEnabled(false)`: eso guarda
   `partyGrid.enabled = false` en SavedVariables, así que la grilla quedaba apagada para
   siempre y el aviso en chat se perdía entre el resto. Ahora el corte es de sesión
   (`PG._killed`, en memoria), hace falta que el fallo se repita tres veces, y el error se
   reenvía a `geterrorhandler()` para que un capturador (BugSack) guarde la traza. Un
   `/reload` restaura; `/chukieui party on` reintenta en el momento.
2. **Podía quedar colgada del contenedor equivocado.** Los tres candidatos
   (`CompactPartyFrame`, `CompactRaidFrameContainer`, `PartyFrame`) existen a la vez: el
   del modo activo se dibuja y los otros quedan creados pero ocultos. `BlizzardContainer`
   tomaba el primero que existiera, de modo que la grilla podía terminar colgada de uno que
   nunca se muestra: invisible aunque la de Blizzard esté a la vista. Ahora se prefiere el
   que se está dibujando, después el que está `IsShown`, y sin grupo se le pregunta a
   `EditModeManagerFrame:UseRaidStylePartyFrames()`.

Además, para que no haga falta esperar un evento que quizá no llegue:

- **Vigía de padre** (`PG:CheckHost`, una vez por segundo dentro del pulso que ya existía):
  si el padre del host no es el que corresponde, rehace el layout. Blizzard no avisa cuando
  cambia de contenedor, y comparar dos marcos no cuesta nada.
- **Eventos de muerte**: `PLAYER_DEAD`, `PLAYER_ALIVE` y `PLAYER_UNGHOST` recalculan
  posición y orden, porque morir y volver rearma los marcos de Blizzard.
- **El pulso también va protegido**: un fallo ahí se contabiliza igual que uno de evento,
  en vez de repetirse cinco veces por segundo.

Para ver el estado: `/chukieui party diag` imprime si la apagó un fallo, de qué marco
cuelga, cuál se está dibujando, la condición de visibilidad y el último error.

---

## Diagnóstico del panel derecho

`/chukieui diag` (0.3.3) imprime en chat el estado real de la cadena de marcos del
panel derecho: `ChukieUi_Root`, `ChukieUi_Panel_rightPanel`, los slots
(`center`/`left`/`right`), `MinimapCluster`, `Minimap`, widgets, franja y micromenú.
De cada uno muestra padre, `IsShown`, `IsVisible`, alpha, escala efectiva, tamaño,
posición en pantalla y cantidad de anclas; además el estado de `WantsRightPanel`,
Edit Mode, diferido por cinemática/`UIParent` oculto, combate y offsets guardados.

Sirve para separar los tres motivos por los que el panel “desaparece” sin error de
Lua: alguien lo **ocultó** (`shown=NO`), quedó **fuera de pantalla** (posición
absurda) o quedó **degenerado** (tamaño 1x1 o alpha 0).

`/chukieui diagbotones` hace lo mismo con los grupos de botones: grilla de widgets y
sus 8 celdas, `ChukieUi_MiniAct1..3` (con escala, slot de acción y `statehidden`),
barra de iconos de addons, micromenú, franja y barra 6.

Ojo con dos falsos positivos: `ChukieUi_MicroMenuHolder` está oculto **a propósito**
(es el aparcadero del armazón de micromenú de Blizzard, igual que hace Dominos), y las
celdas 2–4 muestran la mini barra **o** las ranuras dinámicas, nunca las dos: si
`miniActionBarEnabled` está activo, gana la mini barra y las ranuras dinámicas no se
dibujan (`staticSessionMode` también las bloquea).

---

## Funcionalidad actual (resumen)

- Paneles izq/der, minimapa, micromenú, RightStrip, widgets, teleports.
- Barras de acción 1–4: matriz fija **6 × 4** en `ChukieUi_LeftBarsBlock`, anclada al
  centro de la pantalla, strata `MEDIUM`, transparencia por botón y offsets amplios.
- Grilla de party (`/chukie-party`): hechizo por columna, columnas ciclo con acción
  `/click ch-cl-<Hechizo>` y selección por clic derecho fuera de combate.
- Mini barra / ranuras dinámicas 2–4; una de esas celdas puede ser el toggle de Combat Log.
- Combat Log (`CombatLog.lua`): `LoggingCombat` + filtros por tipo de contenido e instancia.
- Guardado de layout de barras 1–4 (`ActionBarLayouts.lua`).
- Alertas: árbol **grupo → efecto → regla**. Un grupo (ej. Presciencia) agrupa
  efectos (icono / textura / texto / sonido; barra-reloj-contador como stub) y
  condiciones AND/OR (CD, aura, proc, combate, target, cargas), cada una con su
  propio `spellId`.
- La ventana de grupo muestra a la izquierda las dos listas (efectos arriba,
  condiciones abajo) y a la derecha el editor del elemento seleccionado. El panel
  se abre centrado en la mitad derecha de la pantalla.
- `Forzar grupo` / `Forzar efecto` ignoran las condiciones para configurar
  visualmente.
- Condiciones de tipo Aura y Proc muestran una instantánea de las auras activas
  (player y target, buffs y debuffs) tomada al abrir el grupo, con botón
  `Refrescar`. Un clic copia el `spellId` real del aura y, en Aura, ajusta unidad
  y tipo según dónde se leyó.
- Las `rules[]` legacy migran solas a `groups[]` en `EnsureSchema`.
- En **12.1**, un grupo cuya única condición activa es aura “Presente” y cuyo único
  efecto visual activo es icono o textura se delega al cliente (`AuraContainer`):
  Blizzard decide el show/hide (por eso ve auras ocultas) y el addon solo aporta
  tamaño, posición, color y alpha del efecto, o una textura propia en modo textura.
  Cualquier otra condición, un efecto de texto, sonido o varios efectos visuales
  vuelven al path propio. El editor avisa en verde cuando el grupo queda delegado y
  `/chukieui auracontainer` lista grupo por grupo si es delegable y si tiene
  contenedor vivo.
- En builds sin AuraContainer, mismo código cae a legacy.

---

## Limitaciones conocidas

1. Auras ContextuallySecret en path legacy: no hay lectura fiable por spellId/icon.
   Consecuencia: con un aura secreta, «Ausente» ya no se cumple (antes daba falso
   positivo porque "no la veo" se tomaba como "no la tiene"). El editor lo avisa
   en el pie de la condición. Alternativa práctica: condición Cooldown.
   Los payloads de `UNIT_AURA` (`isFullUpdate`, listas de instancias) pueden venir
   secretos: siempre pasar por `truthy()` / `plain()` antes de un `if` o `tonumber`.
2. PrivateAuraAnchor ≠ solución para Mass Disintegrate.
3. Preview del editor: `SetLivePreview(groupId[, effectId])` fuerza grupo o una capa.
4. Ausente / Siempre / filtro stacks: no van por AuraContainer (legacy).
5. Cargas en combate: Blizzard oculta `currentCharges`. El número exacto solo se
   deduce con 2 cargas (lleno / recargando / sin cargas). Con 3 o más, en los
   estados intermedios no se muestra número y el filtro por cantidad se ignora.
   La deducción vive en `ns.CdInfo` (`Core.lua`) y la usan las barras y la mini
   barra para el contador; las alertas tienen su equivalente por spellId.
   Verificar con `/chukieui cdcheck <spellId>` (p. ej. `410089` Presciencia).
6. Barra / reloj circular / contador: schema listo, renderer aún no-op.
7. Zygor / proxies / taint: ver notas históricas del README.

---

## Restaurar desde ZIP

1. Cierra WoW o `/reload` tras copiar.
2. Carpeta `Chukie_Ui` → `_retail_\Interface\AddOns\`.
3. Activa el addon; SavedVariables en `WTF\...\ChukieUiDB.lua` (no van en el ZIP de código).
