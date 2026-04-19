# Chukie UI

Addon de interfaz para **World of Warcraft Retail** (TOC `## Interface: 120001`).

## Instalación

Copia la carpeta `Chukie_Ui` en:

`_retail_\Interface\AddOns\`

Activa **Chukie UI** en el selector de addons. Opcional: **Masque**, **DialogueUI** (dependencias opcionales declaradas en el `.toc`).

## Contenido principal

| Área | Descripción |
|------|-------------|
| **Minimapa** | Posición del cluster, escala, `rotateMinimap`, flecha del jugador (modos por defecto / fina / ruta personalizada), zoom preferido dentro de los límites del motor. |
| **Barra de iconos** | Proxies (LibDBIcon, etc.), política por botón, Masque, micromenú configurable. |
| **Panel derecho** | `PanelCore.lua` + `RightPanel.lua`: host del minimapa y rejilla de widgets. |
| **Widgets del panel** | `RightPanelWidgets.lua`: LFG, rastreo, correo, dificultad, teletransporte (`TeleportCatalog.lua`), ranuras dinámicas 2–4 (`DynamicReservedSlots.lua`). |
| **Opciones** | *Esc → Opciones → AddOns → Chukie UI* (`ConfigPanel.lua`, API Settings de Retail). |

## Archivos que carga el cliente

Orden en `Chukie_Ui.toc`: `Core.lua`, `Profiles.lua`, `PanelCore.lua`, `RightPanel.lua`, `MinimapBar.lua`, `TeleportCatalog.lua`, `DynamicReservedSlots.lua`, `RightPanelWidgets.lua`, `ConfigPanel.lua`.

- **`Bindings.xml`** (raíz del addon): define enlaces de teclado para las ranuras dinámicas seguras (`ChukieDynAct2` … `ChukieDynAct4`). **No** debe incluirse en el `.toc` (el cliente lo cargaría como Lua). Los textos visibles en *Controles → Teclas rápidas* se asignan en `Core.lua` (`BINDING_NAME_CLICK …`).
- **`Media/`**: PNG/TGA referenciados por ruta desde Lua; **no** van en el `.toc`.

## Ranuras dinámicas (reservadas 2–4)

Prioridad aproximada: acción extra → habilidad de zona → ítems especiales de misiones rastreadas. Se pueden enlazar teclas en **Controles → Teclas rápidas → Add-ons**. Opción en el panel del addon para activar o desactivar el comportamiento.

## Documentación adicional

- `docs/WoW1201_Opciones_Addons.md` — API de opciones Retail y convenciones del proyecto.
- `docs/ESTADO_Y_RESPALDO.md` — inventario de archivos, limitaciones y empaquetado ZIP.
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
