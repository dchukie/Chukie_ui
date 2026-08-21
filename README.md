# Chukie UI

Addon de interfaz para **World of Warcraft Retail** (TOC `## Interface: 120100, 120007` — **12.1** live; compat 12.0.7).

## Instalación

Copia la carpeta `Chukie_Ui` en:

`_retail_\Interface\AddOns\`

Activa **Chukie UI** en el selector de addons. Opcional: **Masque**, **DialogueUI** (dependencias opcionales declaradas en el `.toc`).

## Contenido principal

| Área | Descripción |
|------|-------------|
| **Minimapa** | Posición del cluster, escala, `rotateMinimap`, flecha del jugador, **brújula horizontal** (`HorizontalCompass.lua`, posición vertical libre desde el centro del minimapa: encima o debajo), zoom preferido. |
| **Barra de iconos** | Proxies (LibDBIcon, etc.), política por botón, Masque, micromenú configurable. |
| **Panel derecho** | `PanelCore.lua` + `RightPanel.lua`: host del minimapa, rejilla de widgets y slot lateral derecho. |
| **Widgets del panel** | `RightPanelWidgets.lua`: LFG, rastreo, correo, dificultad, teletransporte y toggle de **Combat Log** en una ranura 2–4 configurable. `CombatLog.lua` permite auto-logging por dificultad (M+, raids, etc.) y por instancia concreta. |
| **Sector amarillo** | `RightStrip.lua`: grilla inferior fija 2x2 (oro abreviado + huecos libres de bolsas), clic para `ToggleAllBags`, estilo Masque opcional y ocultado de la barra de bolsas Blizzard. |
| **Barras de acción 1–4** | Matriz fija de **6 × 4** centrada en la pantalla (Offset X −1800…1800, Offset Y −1200…1200 desde el centro). La subpágina **Barras de acción → Transparencia 6 × 4** reproduce las 24 celdas y permite ajustar cada botón entre 10 y 100 % con deslizador o caja de texto (ambos sincronizados). |
| **Opciones** | *Esc → Opciones → AddOns → Chukie UI* (`ConfigPanel.lua`, API Settings de Retail). |
| **Alertas CD/procs/auras** | Grupos con efectos y condiciones, editor `/chukie-aura`. En **12.1**, un grupo cuya única condición es aura “Presente” y cuyo único efecto visual es icono/textura lo dibuja el cliente (**AuraContainer**), así que también ve las auras que Blizzard oculta; el resto usa el path propio. Media en `Media/Alerts/`. |
| **Panel de auras** | `AuraPanel.lua`, `/chukie-auras`: un slot grande por aura elegida usando **AuraContainer**, con tamaño, separación, auras por línea, dirección y posición arrastrable. Los slots no se compactan (el addon no sabe cuál está activa). |
| **Grilla de party por habilidades** | `PartyGrid.lua`. Cada columna guarda un hechizo por perfil y cada celda es un `SecureActionButtonTemplate`: clic izquierdo lo lanza sobre `player`/`party1..4`; clic derecho no hace nada. Asignación desde el libro y movimiento entre columnas por arrastre, icono/cooldown real sin GCD/cargas/usabilidad/rango y tooltip. Soporte Masque en el grupo separado **Chukie UI → PartyGrid** y opacidad del conjunto (10–100 %). Toda configuración se rechaza durante el combate. Opciones en **Marcos → Party** (`/chukieui party`), ventana propia (`/chukie-party`) y estado con `/chukieui party diag`. Por defecto: 1 columna a la derecha de la grilla Blizzard, creciendo a la derecha. |
| **Combat Log** | `CombatLog.lua`. Toggle en una ranura 2–4 de la grilla azul. Auto-logging por tipo (M+, mítica 0, raids por dificultad, etc.) y por instancia concreta. Opciones en **Panel izquierdo → Combat Log**. El archivo lo escribe el cliente (`Logs\WoWCombatLog.txt`); el addon no parsea CLEU. |

## Archivos que carga el cliente

Orden en `Chukie_Ui.toc`: ver el `.toc` (incluye `ActionBars.lua`, `Alerts*.lua`, paneles, etc.).

- **`Bindings.xml`** (raíz del addon): define enlaces de teclado para las ranuras dinámicas seguras (`ChukieDynAct2` … `ChukieDynAct4`). **No** debe incluirse en el `.toc` (el cliente lo cargaría como Lua). Los textos visibles en *Controles → Teclas rápidas* se asignan en `Core.lua` (`BINDING_NAME_CLICK …`).
- **`Media/`**: PNG/TGA referenciados por ruta desde Lua; **no** van en el `.toc`.

## Ranuras dinámicas (reservadas 2–4)

Prioridad aproximada: acción extra → habilidad de zona → ítems especiales de misiones rastreadas. Se pueden enlazar teclas en **Controles → Teclas rápidas → Add-ons**. Opción en el panel del addon para activar o desactivar el comportamiento. Si el toggle de Combat Log está activo, su celda se excluye y la cola se compacta en las restantes.

## Combat Log

- Toggle en **Panel izquierdo → Combat Log** (ranura 2, 3 o 4 de la grilla 2 × 4).
- Por defecto autoactiva M+ y raid mítica; el resto de tipos va desmarcado.
- **Instancias específicas**: lista vacía = todas las del tipo marcado; con marcas, sólo esas.
- «Detener al salir» sólo apaga una sesión que arrancó el addon, no un `/combatlog` manual.
- Advanced Combat Logging es un CVar aparte (`advancedCombatLogging`).

## Guardado de acciones (barras 1–4)

Blizzard guarda un juego de barras **por loadout de talentos**, así que al cambiar de build las ranuras se pisan. `ActionBarLayouts.lua` guarda qué hay en cada ranura de las barras 1–4 (y sus páginas de skyriding) **por personaje y especialización** y lo vuelve a colocar tras un cambio de talentos, loadout o especialización.

- Opciones en *Barras de acción → Guardar acciones (barras 1–4)*: guardar automático, restaurar al cambiar talentos y botones **Guardar acciones ahora / Restaurar acciones / Borrar guardado**.
- Comandos: `/chukieui acciones` (estado), `… guardar`, `… restaurar`, `… borrar`.
- Tipos soportados: hechizo, macro (por nombre), ítem, flyout, montura, mascota de combate y conjunto de equipo.
- Nunca vacía ranuras (solo repone lo guardado) y siempre actúa fuera de combate y con el cursor libre.
- Los datos viven en `ChukieUiDB.actionLayouts[personaje-reino][specID]`, fuera de los perfiles de UI, para no perderse al cambiar de perfil.

## Sector amarillo (franja derecha inferior)

- Muestra moneda del personaje con formato compacto (`k` / `m`) y el icono correspondiente (oro/plata/cobre según monto).
- Muestra bolsas como **espacio libre / total** en una grilla fija de 2 filas.
- Clic izquierdo sobre la grilla abre/cierra bolsas (`ToggleAllBags`).
- Configurable desde opciones: Masque, escala de grilla, fuente y tamaño de texto.
- La barra original de bolsas de Blizzard se oculta para evitar duplicidad visual.

## Documentación adicional

- `docs/WoW1201_Opciones_Addons.md` — API de opciones Retail y convenciones del proyecto.
- `docs/ESTADO_Y_RESPALDO.md` — inventario de archivos, limitaciones y empaquetado ZIP.
- `docs/ALERTS_MEDIA_ATTRIBUTION.md` — licencias y atribución del arte/sonidos de alertas.
- `releases/README.txt` — uso de `pack_backup.ps1`.

## Herramientas (desarrollo)

- `tools/CropMinimapArrows.ps1` — recorta una hoja fuente (`assets/source_arrows.png`, local, no obligatoria en el repo) y genera flechas del jugador en `Media/`.
- `releases/pack_backup.ps1` — genera un ZIP de distribución (misma estructura que `AddOns\Chukie_Ui`).

## Publicar en GitHub

Si el repositorio ya existe con remoto `origin`:

```bash
cd "/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/Chukie_Ui"
git add -A
git status
git commit -m "Descripción del cambio"
git push -u origin dev
```

(Ajusta la rama si usas `main` u otra.) Para crear el repo desde cero, sigue las instrucciones genéricas en la documentación de GitHub o usa `gh repo create`.
