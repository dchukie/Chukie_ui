# Plan: Chukie UI en WoW Forever

Autor del relevamiento: agente Cursor, para Diego Fasciglione. Fecha: 2026-11-07. PC: `pc-chukie-casa` (Windows).

Este documento es solo un plan. En esta pasada **no** se escribió código del addon, **no** se copió nada a `_forever_\Interface\AddOns` y **no** se tocó `main` ni `dev`.

## 1. Rutas verificadas

| Qué | Ruta / dato | Cómo se verificó |
|-----|-------------|------------------|
| Instalación WoW (raíz) | `C:\Program Files (x86)\World of Warcraft` | `.build.info` lista dos productos activos |
| Cliente **Forever** | `C:\Program Files (x86)\World of Warcraft\_forever_` | `.flavor.info` = `wowf`; `Wow.exe` FileVersion `1.60.1.70862` |
| Build Forever | `1.60.1.70862`, producto `wowf` (`.build.info`) | `gx.log`: "World of Warcraft Retail x86_64 1.60.1.70862" |
| Interface Forever | `16001` | `/dump select(4, GetBuildInfo())` en el juego (Diego, captura) |
| Cliente Retail (no es Forever) | `C:\Program Files (x86)\World of Warcraft\_retail_`, build `12.1.5.70783` | `.build.info` |
| Addons Forever | `_forever_\Interface\AddOns` — **vacía** | listado directo |
| Cuenta/personaje Forever | `_forever_\WTF\Account\DCHUKIE\91\Churie-Fasciglione` | sin addons propios; solo SavedVariables Blizzard |
| Addon original (fuente) | `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\Chukie_Ui` | checkout git limpio, rama `dev` @ `ab51ace` (v0.5.8) |
| Repo | https://github.com/dchukie/Chukie_ui (público, por defecto `main`) | `gh repo view` |
| Worktree de trabajo | `C:\chukie-dev\Chukie_ui-wow-forever` (rama `wow-forever`) | `git worktree add` desde el checkout retail |

Búsqueda acotada (profundidad 3) en `Program Files`, `Program Files (x86)`, `C:\Games`, `D:\`, perfil del usuario, escritorios y menú inicio: el único resultado de WoW fue `_forever_`. Lo demás con "forever" en `D:\EMULATIONSTATION` son emuladores/ROMs, no tienen relación.

### Versión de interface y API esperable

- **Número `## Interface` de Forever: 16001 (verificado).** Diego lo leyó en el juego con `/dump select(4, GetBuildInfo())`, que devuelve `16001` para WoW Forever (captura de pantalla de Diego, 2026-11-07). El TOC del addon en Forever tiene que llevar `## Interface: 16001`.
- **El cliente es Mainline, no un Classic viejo.** Evidencia: `Wow.exe` contiene `EditModeLayoutConsts_Mainline`, `ItemScript_Mainline.cpp`, `C_GameRules.SetForeverExperiencePresetPreLogin`, `ForeverExperiencePreset`; los logs tienen `EditMode.log`, `Housing.log`; el personaje tiene SavedVariables de `Blizzard_DamageMeter`, `Blizzard_Professions`, `Blizzard_Communities`, y `AddOns.txt` habilita `Blizzard_ObjectiveTracker` y `Blizzard_CompactRaidFrames`. `Config.wtf` tiene `hasSelectedExperiencePreset "1"`.
- Conclusión razonable: Forever es el motor/FrameXML de retail 12.x con un "preset de experiencia" (`C_GameRules`) que cambia reglas de juego y contenido. Hay que esperar **la API de retail 12.x** (Settings, Edit Mode, `C_Spell`, `C_UnitAuras`, `C_Container`, valores secretos, restricciones de combate de Midnight), pero con contenido distinto: puede no haber Míticas+ de temporada, teletransportes de temporada, Skyriding, especializaciones o talentos iguales. **Lo que más riesgo tiene** es la API nueva de 12.1 (`AuraContainer`) y todo lo que dependa de contenido de temporada.

## 2. Inventario del addon original (v0.5.8, rama `dev`)

TOC `Chukie_Ui.toc`: `## Interface: 120100, 120007`, `## SavedVariables: ChukieUiDB`, `## OptionalDeps: Masque, DialogueUI, LibSharedMedia-3.0, SharedMedia`. Sin dependencias obligatorias. Namespace compartido `ns` (`local _, ns = ...`). Comandos: `/chukieui` (`/chu`), `/chukie-aura`, `/chukie-auras`, `/chukie-party`.

### Librerías y archivos no-Lua

| Parte | Qué hace / de qué vive |
|-------|------------------------|
| `Libs/LibStub` | Registro de librerías; Lua puro, sin API del juego. |
| `Libs/LibCustomGlow-1.0` | Brillos sobre botones (ActionButton glow, pixel, autocast); vive de texturas y `CreateFrame`. Solo la usan Alertas y opciones. |
| `Bindings.xml` | Enlaces de teclado para `ChukieDynAct2..4` (ranuras dinámicas); no va en el TOC. |
| `Media/` (≈390 archivos) | PNG/TGA del addon y media de alertas (arte/sonidos de ThisWeeksAuras/PowerAuras, ver `docs/ALERTS_MEDIA_ATTRIBUTION.md`). |
| `tools/`, `releases/pack_backup.ps1`, `assets/` | Herramientas de desarrollo en PowerShell (recorte de flechas, ZIP de distribución). No se cargan en el juego. |
| `tmp/` | Copias de otros addons como referencia; está en `.gitignore` y **no** forma parte del addon. |

### Módulos Lua (orden del TOC)

| Archivo | Líneas | Qué hace | API de la que vive |
|---------|-------:|----------|--------------------|
| `Core.lua` | 989 | Defaults, CVars, ajustes de UI, eventos de login/spec/combate y comandos slash; llama a cada módulo detrás de `if ns.X`. | `Minimap`, Edit Mode, MicroMenu, CVars, `C_ActionBar` |
| `Profiles.lua` | 748 | Perfiles de opciones por personaje/especialización sobre `ChukieUiDB`. | `GetSpecialization`, SavedVariables |
| `PanelCore.lua` | 261 | Raíz técnica única y árbol de slots de paneles. | Solo `CreateFrame` (Lua puro de UI) |
| `RightPanel.lua` | 1756 | Panel derecho que adopta `MinimapCluster` y lo reafirma frente a Blizzard. | `Minimap`/`MinimapCluster`, Edit Mode |
| `LeftPanel.lua` | 919 | Panel izquierdo con sectores y guías de debug. | `CreateFrame`, guardas `issecretvalue` |
| `RightStrip.lua` | 450 | Grilla 2×2 de oro y espacio de bolsas; clic abre bolsas. | `GetMoney`, `C_Container`, `ToggleAllBags`, Masque opcional |
| `MinimapBar.lua` | 2097 | Limpia el cluster del minimapa, barra de botones de addons y micromenú configurable. | `Minimap`, MicroMenu, LibDBIcon, Masque |
| `HorizontalCompass.lua` | 649 | Brújula horizontal con marcadores sobre el minimapa. | Facing del jugador, `Minimap`, waypoints |
| `TeleportCatalog.lua` | 308 | Catálogo de teletransportes válidos para el personaje y chequeo de M+ de temporada. | `C_ChallengeMode`, `C_SpellBook`, juguetes/ítems |
| `DynamicReservedSlots.lua` | 419 | Botones seguros: acción extra → habilidad de zona → ítem de misión. | Botones seguros, `C_Spell`, Bindings |
| `MiniActionBar.lua` | 646 | Mini barra de 3 acciones (slots 145–147) sin taint. | `C_ActionBar`, `SecureActionButton`, duration objects |
| `ButtonPadModes.lua` | 167 | Formatos Nostromo/Keyzen de la botonera (solo geometría y teclas). | Lua puro |
| `ActionBars.lua` | 2307 | Barras 1–4 estilo Dominos, paginado de vehículo/bonus/Skyriding, barra 6. | `SecureHandler`, `RegisterStateDriver`, `OverrideActionBar`, `C_ActionBar`, Masque |
| `ActionBarLayouts.lua` | 764 | Guarda/restaura las ranuras 1–180 por personaje y spec. | `C_ActionBar`, `C_SpellBook`, `GetSpecialization` |
| `Backup.lua` | 645 | Exporta/importa texto con perfil, ranuras, macros y teclas. | API de macros y bindings, `ActionBarLayouts` |
| `CombatLog.lua` | 300 | Enciende `WoWCombatLog.txt` según dificultad o instancia. | `LoggingCombat`, `GetInstanceInfo`, `C_ChallengeMode` |
| `RightPanelWidgets.lua` | 2715 | Grilla de widgets: LFG, rastreo, correo, dificultad, teleport, toggle de Combat Log, reloj. | `C_Minimap`, LFG, `SecureActionButton`, Masque |
| `AlertsUserMedia.lua` | 24 | Lista de media extra del usuario. | Ninguna |
| `AlertsMedia.lua` | 877 | Catálogo de texturas y sonidos de alertas. | Rutas de archivos |
| `Alerts.lua` | 3595 | Motor de alertas de CD/procs/auras con grupos, reglas y efectos. | `C_UnitAuras`, `C_Spell`, `AuraContainer`, LibCustomGlow, secretos |
| `AlertsAuraContainer.lua` | 488 | Presentación con `AuraContainer` de 12.1; si no existe, el motor usa el camino viejo. | `AuraContainer` (12.1+) |
| `AlertsManager.lua` | 2758 | Editor de grupos/reglas (`/chukie-aura`). | `C_SpellBook`, `C_Spell`, `C_UnitAuras` |
| `AuraPanel.lua` | 902 | Slots grandes de auras fijas (`/chukie-auras`). | `AuraContainer` obligatorio |
| `PartyGrid.lua` | 2798 | Grilla de party con un hechizo seguro por columna y ciclos `/click ch-cl-…`. | `SecureActionButton`, `SecureHandler`, Edit Mode, marcos Blizzard de grupo |
| `ConfigPanel.lua` | 3812 | Panel de opciones de todo el addon en Esc → Opciones → AddOns. | `Settings.*` (130 usos), referencia a casi todos los módulos |

**SavedVariables:** una sola, `ChukieUiDB` (perfiles, `actionLayouts[personaje-reino][specID]`, `partyGrid`, alertas). En Forever es otro `WTF`, así que el nombre puede quedar igual sin colisión.

**Dependencias internas fuertes:** `ConfigPanel` toca casi todo; `RightPanel` y `RightPanelWidgets` toman `MinimapBar`, `MiniActionBar`, `DynamicReservedSlots`, `TeleportCatalog`, `CombatLog`; `Backup` necesita `ActionBarLayouts`; los cuatro `Alerts*` y `AuraPanel` van juntos. `Core` y `Profiles` están guardados con `if ns.X`, lo que permite cargarlos con un TOC reducido.

## 3. Propuesta de corte

La idea es tener un **TOC propio para Forever** en la rama `wow-forever` que liste solo los archivos de la etapa en curso. Cada etapa suma un bloque, se prueba en el cliente y recién ahí se agrega el siguiente.

| Bloque | Archivos | Veredicto | Riesgo |
|--------|----------|-----------|--------|
| A. Núcleo | `LibStub`, `Core`, `Profiles` | **Reescribir parcial**: separar `ApplyUiTweaks` (minimapa/Edit Mode/micromenú) del arranque; agregar una sonda de API. | Bajo |
| B. Combat Log | `CombatLog` | **Casi tal cual**; revisar `C_ChallengeMode` y tipos de dificultad de Forever. Se controla por slash hasta que haya widgets. | Bajo |
| C. Base de paneles + franja | `PanelCore`, `RightStrip` | **Tal cual** (Lua puro + `C_Container`). Sin `RightPanel`, la franja se ancla directo a `UIParent`. | Bajo |
| D. Opciones mínimas | `ConfigPanel` recortado | **Reescribir**: un panel nuevo con solo las páginas de los bloques cargados; el actual referencia todo. | Medio |
| E. Botonera | `ButtonPadModes`, `ActionBars` | **Portar con revisión**: el paginado de vehículo/bonus/Skyriding y los índices 16/17/18 dependen del contenido. | Medio-alto (taint, combate) |
| F. Panel derecho y minimapa | `RightPanel`, `MinimapBar`, `HorizontalCompass`, `LeftPanel` | **Portar con revisión**: depende de los nombres de marcos de Blizzard del cluster, que pueden variar. | Medio |
| G. Widgets | `RightPanelWidgets`, `DynamicReservedSlots`, `MiniActionBar`, `Bindings.xml` | **Portar con revisión**: LFG y dificultad dependen de contenido. | Medio |
| H. Teletransportes | `TeleportCatalog` | **Reescribir datos**: el catálogo y la temporada de M+ son de retail. | Medio |
| I. Guardado y respaldo | `ActionBarLayouts`, `Backup` | **Portar después de E**; depende de que existan specs/loadouts en Forever. | Medio |
| J. PartyGrid | `PartyGrid` | **Fuera de la primera etapa**; portar tal cual cuando E esté estable. | Alto (seguro + marcos de grupo) |
| K. Alertas y auras | `AlertsUserMedia`, `AlertsMedia`, `Alerts`, `AlertsAuraContainer`, `AlertsManager`, `AuraPanel`, `LibCustomGlow`, `Media/Alerts` | **Fuera de la primera etapa**. `AuraPanel` necesita `AuraContainer`; el resto tiene camino viejo pero mucho volumen. | Alto |

Lo que se separa: Alertas/AuraPanel (bloque K) y PartyGrid (J) quedan aislados porque son los más grandes y los que más dependen de API 12.1. `ConfigPanel` no se arrastra entero en ninguna etapa: se reconstruye por páginas.

## 4. Orden de implementación (de a una parte)

1. **A — Núcleo y sonda.** TOC Forever con `## Interface: 16001`, `LibStub`, `Core` (solo arranque, perfiles, slash) y `Profiles`. Agregar `/chukieui forever` que imprima `GetBuildInfo()`, `WOW_PROJECT_ID` y qué existe: `C_UnitAuras`, `AuraContainer`, `issecretvalue`, `Settings`, `EditModeManagerFrame`, `C_ChallengeMode`, `C_ClassTalents`, `GetSpecialization`. **Criterio de entrega:** el addon aparece en la lista, carga sin errores de Lua y crea `ChukieUiDB`. Esta es la pieza más chica que se puede cargar sin arrastrar el resto.
2. **B — Combat Log.** Sumar `CombatLog.lua`; `/chukieui` para prender/apagar. Probar en una instancia.
3. **C — Franja de oro y bolsas.** `PanelCore` + `RightStrip`, anclada a `UIParent`.
4. **D — Opciones mínimas.** Panel de Settings nuevo con páginas solo para A–C.
5. **E — Botonera 1–4.** `ButtonPadModes` + `ActionBars`, primero sin paginado especial; después vehículo/bonus. Probar entrar y salir de combate y de vehículo.
6. **F — Panel derecho y minimapa**, en este orden: `RightPanel` → `MinimapBar` → `HorizontalCompass` → `LeftPanel`.
7. **G — Widgets** con `DynamicReservedSlots`, `MiniActionBar` y `Bindings.xml`.
8. **H — Teletransportes** con catálogo propio de Forever.
9. **I — Guardado de acciones y respaldo.**
10. **J — PartyGrid.**
11. **K — Alertas y AuraPanel**, primero el motor con camino viejo y después `AuraContainer` si la sonda dice que existe.

Para cada paso: un commit en `wow-forever`, copia manual de la carpeta al cliente Forever solo cuando el usuario lo decida, prueba en el juego, y nota de resultado en este documento.

## 5. Entorno: qué queda listo y qué falta

Listo:
- `git` 2.53.0 (Windows).
- `gh` autenticado como `dchukie` (scopes `repo`, `workflow`).
- Worktree limpio en `C:\chukie-dev\Chukie_ui-wow-forever` con la rama `wow-forever` publicada en `origin`. El checkout de retail (rama `dev`) no se tocó.
- **`wow-forever` ya incluye `dev`.** El 2026-11-07 se mergeó `origin/dev` (`ab51ace`, v0.5.8) sobre la rama que salía de `main` (`79536e6`). El merge fue limpio, sin conflictos (commit `a14ce82`). El código del addon en esta rama es el de v0.5.8. Las ramas `main` y `dev` no se movieron.
- Ruta del cliente Forever confirmada: `C:\Program Files (x86)\World of Warcraft\_forever_`.
- Empaquetado: alcanza con `releases/pack_backup.ps1` (PowerShell, ya existe en `dev`). No hace falta instalar nada.

Falta:
- No hay `lua`/`luacheck` instalados. Son opcionales (chequeo de sintaxis fuera del juego); no se instalaron.
- Escribir en `_forever_\Interface\AddOns` necesita permisos sobre `Program Files (x86)`. La forma de cargar el addon (copia, o un enlace de directorio desde el worktree) queda a decisión del usuario.

## 6. Qué no se hizo

- No se copió ni se enlazó el addon en `_forever_\Interface\AddOns` (sigue vacía).
- No se cambió código del addon; en `wow-forever` solo se agregó este documento.
- No se tocaron `main` ni `dev`, ni el working tree del checkout de retail.
- No se subieron binarios, `WTF`, cuentas ni tokens.
- No se instaló software.
