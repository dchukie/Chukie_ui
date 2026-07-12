# Atribución de media de alertas

Los recursos bajo `Media/Alerts/` (texturas, PowerAuras, sonidos, fuentes) provienen principalmente del pack de arte usado por addons tipo **ThisWeeksAuras** / colecciones similares, redistribuidos con los textos de licencia que acompañan cada conjunto.

## Archivos de licencia en el addon

Revisá estos archivos en `Media/Alerts/` antes de una distribución pública:

| Archivo | Contenido |
|---------|-----------|
| `Provided by.txt` | Inventario de sonidos y orígenes (p. ej. soundbible.com, OpenGameArt) |
| `Creative Commons - Attribution 3.0.txt` | CC BY 3.0 |
| `Creative Commons - Attribution-NonCommercial 3.0.txt` | CC BY-NC 3.0 (**no comercial**) |
| `Creative Commons - Sampling Plus 1.0.txt` | Sampling Plus 1.0 |
| `Creative Commons - CC0 1.0.txt` | Dominio público / CC0 |
| `PT Sans License.txt` | Fuente PT Sans |
| `Fira License.txt` | Fuente Fira |

## Notas para distribución

- Hay sonidos bajo **CC BY-NC** y **Sampling Plus**: pueden restringir uso comercial o exigir atribución.
- Conservá estos `.txt` al empaquetar el addon.
- El módulo de alertas referencia las rutas vía `AlertsMedia.lua` (`Interface\AddOns\<Addon>\Media\Alerts\...`).

Si redistribuís el addon de forma pública, auditá este directorio y el inventario de `Provided by.txt` para cumplir atribución y restricciones NC.

## Agregar arte propio

1. Archivos **`.tga`** / **`.blp`** (alpha) en `Media/Alerts/User/`.
2. Listarlos en `AlertsUserMedia.lua` (WoW no escanea carpetas).
3. `/reload`.

## LibSharedMedia

Con **LibSharedMedia-3.0** / **SharedMedia** instalado, el picker de alertas incluye backgrounds, statusbars y borders registrados por otros addons. Chukie también publica parte de su media local en LSM (prefijo `Chukie:`).
