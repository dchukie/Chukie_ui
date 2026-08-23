# PartyGrid: Chukie UI vs standalone

Hay **dos copias** a propósito. No se mezclan.

| | Chukie UI (`PartyGrid.lua`) | Standalone (`tmp/Chukie_PartyGrid`, repo [Chukie_PartyGrid](https://github.com/dchukie/Chukie_PartyGrid)) |
|--|--|--|
| Para quién | Uso propio, pegada a Blizzard | Quien usa ElvUI u otro UF |
| ElvUI | No. Ni plugin ni candidatos `ElvUF_*` | Sí, opcional |
| Perfil | `ChukieUiDB.partyGrid` | `ChukiePartyGridDB` |
| Comandos | `/chukieui party`, `/chukie-party` | `/cpg` |

`tmp/` está en `.gitignore`. El clone vive ahí y no entra al git de Chukie UI.

## Qué es “capa ElvUI” (solo standalone)

Archivo propio, no existe en Chukie UI:

- `ElvUIPlugin.lua` — `LibElvUIPlugin-1.0`, opciones en **ElvUI → Unit Frames → Group Units → Party**. Si ElvUI no está, el archivo sale al inicio.

En `PartyGrid.lua` / `Core.lua` / `ConfigPanel.lua` del standalone, además:

- `hostFrameMode` / `hostFrameCustom` (`auto`, `elvui`, `blizzardAuto`, presets, `custom`)
- `ResolveHostFrame()`: ElvUI primero en `auto`; modos explícitos **no** caen en Blizzard
- Candidatos `ElvUF_*` dentro del recorrido común de hijos con `unit`
- Watchdog si el header de ElvUI aparece tarde
- Prefijos `ChukiePartyGrid_*`, Masque **Chukie PartyGrid → PartyGrid**
- Compartimento de addons, `OptionalDeps: ElvUI`

Eso **no** se copia a Chukie UI. El recorrido profundo por `unit`/`GetAttribute("unit")` y
`perUnitAnchor` sí son núcleo común: también sirven para layouts Blizzard horizontales.

## Qué sí se porta (núcleo común)

Comportamiento de celdas, combate 12.1 y ciclos:

- `SecureActionButton`, clic izquierdo = unidad de la fila
- Ciclo: clic derecho OOC, lista en `cycleUnitN` (nunca `unit1`/`unit2`), `/click ch-cl-<Hechizo>`
- Anclaje por jugador en los cuatro lados y escaneo profundo de marcos por `unit`
- Ventana desplazable con edición de hechizo, macro copiable y estado del ciclo
- Rechazo de config en combate, duration objects, secretos, Masque de celdas
- Guardas de secretos también al leer marcos ajenos (`frameNumber`, `frameFlag`, `sameUnit`):
  un ancho o un `UnitIsUnit` secreto aborta el recorrido, y con ElvUI pasa siempre

El nombre `ch-cl-…` es el mismo a propósito (macros). No cargar **los dos** addons con ciclos activos: el segundo no pisa el botón.

## Cómo actualizar el standalone después de un cambio en Chukie UI

No pegar `PartyGrid.lua` entero encima: se pierde el anclaje ElvUI.

1. En Chukie UI, anotar qué cambió (ciclo, visual, combate, opciones de columna).
2. En `tmp/Chukie_PartyGrid`, portar **solo ese comportamiento**, conservando `ResolveHostFrame`, `HOST_FRAME_*`, `perUnitAnchor` y nombres `ChukiePartyGrid_*`.
3. Si hay una clave nueva de perfil, agregarla en `Core.lua` (defaults), `ConfigPanel.lua` y `ElvUIPlugin.lua` (las tres UIs del standalone).
4. Probar sin ElvUI (`/cpg diag`) y, si se puede, con ElvUI (modo `elvui`, waiting frame).
5. Commit y push **en el repo del standalone**, no en Chukie_ui:

```text
cd tmp/Chukie_PartyGrid
git add -A
git commit -m "sync: … desde Chukie UI"
git push origin main
```

Instalación en el cliente: copiar esa carpeta a `AddOns\Chukie_PartyGrid` (no dejarla solo en `tmp`).
El nombre de la carpeta tiene que coincidir con el `.toc`: el ZIP de GitHub llega como
`Chukie_PartyGrid-main` y con ese nombre el cliente no lista el addon.
