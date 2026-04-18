# Chukie UI — estado del proyecto y respaldo

**Instantánea:** 2026-04-17  
**Versión en `Chukie_Ui.toc`:** 0.1.0  
**Interface WoW:** 120001 (Retail 12.0.1)

Este documento describe el estado del addon **tal como está empaquetado en el ZIP de respaldo** y cómo restaurarlo.

---

## Qué incluye el addon (distribución)

Archivos cargados por el cliente (orden del `.toc`):

| Archivo | Rol |
|---------|-----|
| `Chukie_Ui.toc` | Metadatos, dependencia opcional Masque, `SavedVariables: ChukieUiDB` |
| `Core.lua` | Arranque, perfil activo, valores por defecto |
| `Profiles.lua` | Perfiles guardados |
| `MinimapPosition.lua` | Posición/tamaño del minimapa |
| `MinimapBar.lua` | Barra de iconos, políticas por botón, strip Blizzard, **barra por proxies**, Masque |
| `ConfigPanel.lua` | Opciones en Esc → Opciones → AddOns → Chukie UI |

Carpeta **`docs/`**: referencias técnicas (p. ej. API de opciones Retail) y este estado; **no** la carga el juego.

Carpeta **`releases/`** (solo en el ZIP de respaldo): `README.txt` y `pack_backup.ps1` para volver a generar el paquete desde una copia descomprimida; **no** la carga el juego.

---

## Funcionalidad actual (minimapa / barra)

- **Solo mapa:** opción para ocultar cromado Blizzard del cluster/minimapa (lista `STRIP_FRAMES` y resolutores).
- **Política por icono:** Defecto (minimapa) / Barra Chukie / Oculto; descubrimiento y orden en perfil.
- **Barra «Barra Chukie»:** los botones reales (LibDBIcon, Zygor map icon, etc.) **permanecen en el minimapa pero ocultos**; la barra muestra **botones proxy** con icono copiado y reenvío de clic, ratón y tooltips al marco original. Así **Masque** puede aplicarse al proxy sin pelear con el marco LibDBIcon.
- **Masque:** grupo `Chukie UI` → `MinimapBar` sobre los proxies (si Masque está instalado y la opción está activa).
- **LibDBIcon:** al usar la barra se fuerza bloqueo / visibilidad coherente; al desactivar la barra se restaura `ShowOnEnter`, `Unlock`, etc.

---

## Limitaciones conocidas

1. **Icono de Zygor (ZygorGuidesViewerMapIcon):** el proxy no obtiene aún la textura correcta; **clics y tooltips** parecen funcionar. La detección de icono usa `icon` / `IconTexture` / `Icon`; Zygor puede usar otra ruta (otro hijo, atlas, etc.). Pendiente ampliar `getOriginIconTexture` o un caso explícito para ese marco.
2. **Botones seguros o lógica no expuesta por scripts de marco:** el reenvío depende de `GetScript("OnClick")` y similares; casos raros pueden no replicarse al 100 %.

---

## Qué **no** va en el ZIP de respaldo

- Carpeta **`tmp/`** (referencias de otros addons / libs para desarrollo local). No forman parte del addon en juego.
- Cualquier otro archivo suelto no listado en el `.toc` salvo que se añada a mano a futuros empaquetados.

---

## Restaurar desde el ZIP

1. Cierra WoW (recomendado) o recarga con `/reload` tras copiar.
2. Descomprime el ZIP; dentro debe existir la carpeta **`Chukie_Ui`** con el `.toc` y los `.lua` (y opcionalmente `docs/`).
3. Copia **`Chukie_Ui`** a  
   `_retail_\Interface\AddOns\`  
   sustituyendo la carpeta anterior si quieres volver exactamente a esta instantánea.
4. En el selector de personajes, **Addons**: activa **Chukie UI** y dependencias opcionales (Masque) si aplica.
5. Los ajustes del personaje/cuenta siguen en `WTF\Account\<cuenta>\SavedVariables\ChukieUiDB.lua` (no van en el ZIP del código).

---

## Generar de nuevo el paquete

Opción recomendada: ejecutar el script incluido en el repo (actualiza la fecha en el nombre del ZIP):

```text
powershell -ExecutionPolicy Bypass -File releases\pack_backup.ps1
```

(Ejecútalo desde la carpeta raíz del addon `Chukie_Ui`, o con ruta absoluta al `.ps1`.)

El ZIP queda en **`Chukie_Ui\releases\`** con nombre `Chukie_Ui_v0.1.0_backup_YYYY-MM-DD.zip`. Para cambiar la versión del nombre, edita la variable `$ver` en `releases\pack_backup.ps1` o alinea con `## Version:` del `.toc`.
