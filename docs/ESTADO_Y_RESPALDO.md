# Chukie UI — estado del proyecto y respaldo

**Instantánea:** 2026-04-19  
**Versión en `Chukie_Ui.toc`:** 0.1.0  
**Interface WoW:** 120001 (Retail 12.0.1)

Este documento describe el estado del addon **tal como se empaqueta en el ZIP de respaldo** y cómo restaurarlo.

---

## Qué incluye el addon (distribución)

### Archivos cargados por el cliente (orden del `.toc`)

| Archivo | Rol |
|---------|-----|
| `Chukie_Ui.toc` | Metadatos, dependencias opcionales Masque / DialogueUI, `SavedVariables: ChukieUiDB` |
| `Core.lua` | Arranque, nombres de teclas para ranuras dinámicas, valores por defecto y fusión de perfil |
| `Profiles.lua` | Perfiles guardados y modelo de datos del panel de widgets |
| `PanelCore.lua` | Núcleo de layout de paneles (árbol de slots izquierdo/derecho) |
| `RightPanel.lua` | Marco global `ChukieUi_RightPanel`, minimapa/cluster, reglas de escala y depuración |
| `MinimapBar.lua` | Barra de iconos, políticas por botón, strip Blizzard, proxies, Masque, micromenú |
| `TeleportCatalog.lua` | Catálogo de teletransporte (hechizos, juguetes, ítems) |
| `DynamicReservedSlots.lua` | Cola de acciones para ranuras reservadas 2–4 (extra / zona / misión) |
| `RightPanelWidgets.lua` | Rejilla 2×4 de sistema + teletransporte + ranuras dinámicas + fecha/hora |
| `ConfigPanel.lua` | Opciones en *Esc → Opciones → AddOns → Chukie UI* |

### Otros archivos en la carpeta del addon (necesarios pero no en el `.toc`)

| Archivo / carpeta | Rol |
|-------------------|-----|
| `Bindings.xml` | Teclas rápidas `CLICK ChukieDynAct2|3|4:LeftButton` (cuerpo XML = Lua válido, p. ej. `-- noop`) |
| `Media/` | Texturas PNG (dificultad en panel, flechas del minimapa si se generan con `tools/`) |
| `README.md` | Resumen para quien instala desde Git o ZIP |
| `docs/` | Referencias técnicas; **no** las carga el juego |
| `releases/` | `README.txt` y `pack_backup.ps1` para regenerar el ZIP; **no** las carga el juego |
| `tools/` | Scripts de desarrollo (recorte de flechas); **no** los carga el juego |

---

## Funcionalidad actual (resumen)

- **Minimapa / barra:** igual que en versiones anteriores del documento: strip opcional del cromado Blizzard, proxies con Masque, micromenú configurable, políticas por icono.
- **Panel azul (widgets):** LFG, rastreo, correo, dificultad (iconos propios en `Media/`), **teletransporte** (clic izquierdo = acción segura por defecto, derecho = lista), **ranuras 2–4 dinámicas** con validación de contexto (extra / zona / ítem de misión rastreada).
- **Teclas:** `Bindings.xml` + nombres en `Core.lua`; categoría *Add-ons* en el panel de controles.

---

## Limitaciones conocidas

1. **Icono de Zygor (ZygorGuidesViewerMapIcon):** el proxy puede no reflejar la misma textura que el marco original; clics y tooltips suelen funcionar.
2. **Botones seguros o lógica no expuesta por scripts:** el reenvío desde proxies depende de los scripts del marco original; casos raros pueden no replicarse al 100 %.
3. **Ranuras dinámicas en combate:** si el contexto cambia durante el bloqueo de combate, la reaplicación puede quedar pendiente hasta `PLAYER_REGEN_ENABLED`.
4. **Integración con DynamicCam (pendiente):** togglear opciones de cámara desde Chukie UI sin abrir el panel del otro addon.
5. **Modal de rastreo (pendiente):** ampliar favoritos / pins y APIs de mapa.
6. **Estado visual LFG:** fallback al ojo «abierto» en reposo si no hay variante fiable del ojo cerrado en todos los estados del cliente.

---

## Qué **no** va en el ZIP de respaldo

- Carpeta **`tmp/`** (referencias locales u otros addons para desarrollo).
- **`releases/*.zip`** (artefacto generado; se ignora en git por `.gitignore`).
- Carpeta opcional **`assets/`** (hoja fuente para `CropMinimapArrows.ps1`), si la mantienes solo en tu máquina.

---

## Restaurar desde el ZIP

1. Cierra WoW (recomendado) o recarga con `/reload` tras copiar.
2. Descomprime el ZIP; dentro debe existir la carpeta **`Chukie_Ui`** con el `.toc`, todos los `.lua`, `Bindings.xml`, `Media/` y, si se incluyeron, `docs/`.
3. Copia **`Chukie_Ui`** a  
   `_retail_\Interface\AddOns\`  
   sustituyendo la carpeta anterior si quieres volver exactamente a esta instantánea.
4. En el selector de personajes, **Addons**: activa **Chukie UI** y dependencias opcionales si aplica.
5. Los ajustes siguen en `WTF\Account\<cuenta>\SavedVariables\ChukieUiDB.lua` (no van en el ZIP del código).

---

## Generar de nuevo el paquete

```text
powershell -ExecutionPolicy Bypass -File releases\pack_backup.ps1
```

Ejecútalo desde la raíz del addon `Chukie_Ui`. El ZIP queda en **`releases\`** con nombre `Chukie_Ui_v0.1.0_backup_YYYY-MM-DD.zip`. Para cambiar la versión del nombre, edita `$ver` en `releases\pack_backup.ps1` o alinea con `## Version:` del `.toc`.

El script copia los mismos archivos que el cliente necesita (lista alineada con el `.toc`) más `Bindings.xml`, `README.md`, `.gitignore`, `docs/`, `tools/` y `Media/`.
