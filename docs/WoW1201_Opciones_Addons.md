# Opciones de addons en World of Warcraft Retail 12.0.1

Referencia **acotada a Midnight / Retail** con número de interfaz **120001** (comprueba el tuyo con `/dump select(4, GetBuildInfo())` o `lastAddonVersion` en `_retail_\WTF\Config.wtf`).

Blizzard sustituyó el antiguo panel «Interfaz» por **Opciones** (`Settings`) en 10.0. Muchas plantillas XML/Lua antiguas (`InterfaceOptionsSmallCheckButtonTemplate`, `InterfaceOptionsCheckButtonTemplate`, etc.) **ya no existen** en el cliente actual: si `CreateFrame(..., "EsaPlantilla")` falla, hay que migrar.

---

## Dos formas soportadas

### 1. Layout vertical (recomendado para casillas, sliders, desplegables)

Flujo típico (igual que addons base como BugSack en tu instalación):

1. `local category, layout = Settings.RegisterVerticalLayoutCategory("Nombre en la lista")`
2. **Subcategorías** (árbol en la lista lateral, p. ej. «MiniMapa» bajo el nombre del addon):

```lua
Settings.RegisterAddOnCategory(rootCategory)
local sub = Settings.RegisterVerticalLayoutSubcategory(rootCategory, "MiniMapa")
local subLayout = SettingsPanel:GetLayout(sub)
subLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Barra de iconos"))
-- RegisterProxySetting / CreateCheckbox(..., sub, ...) usan `sub` como categoría.
```

3. Opcional: `layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Título de sección"))`
4. Definir ajustes con **`Settings.RegisterAddOnSetting`** (lectura/escritura directa en una tabla) **o** **`Settings.RegisterProxySetting`** (funciones `Get`/`Set` propias; útil para efectos secundarios, p. ej. refrescar otra UI).
5. Crear el control: **`Settings.CreateCheckbox`**, **`Settings.CreateSlider`**, **`Settings.CreateDropdown`**, etc.
6. `Settings.RegisterAddOnCategory(rootCategory)` una vez (categoría raíz); las subcategorías cuelgan de la raíz y no suelen requerir otro `RegisterAddOnCategory` por separado (comportamiento del cliente 12.x).
7. Abrir: `Settings.OpenToCategory(category:GetID())` (raíz o subcategoría).

**Booleanos con tabla guardada (ejemplo):**

```lua
local setting = Settings.RegisterAddOnSetting(
  category,
  "MIADDON_OPCION_MAIL",
  "mostrarCorreo",
  MiAddOnDB,
  Settings.VarType.Boolean,
  "Mostrar aviso de correo",
  Settings.Default.True
)
Settings.CreateCheckbox(category, setting, "Texto del tooltip.")
```

**Booleano con efecto extra (proxy):**

```lua
local function Get() return MiAddOnDB.activo ~= false end
local function Set(v) MiAddOnDB.activo = v; MiAddOn:Refrescar() end
local s = Settings.RegisterProxySetting(
  category,
  "MIADDON_ACTIVO",
  Settings.VarType.Boolean,
  "Activar función",
  Settings.Default.True,
  Get,
  Set
)
Settings.CreateCheckbox(category, s, "Tooltip.")
```

**Slider numérico (proxy + opciones):**

```lua
local function Get() return MiAddOnDB.escala or 100 end
local function Set(v) MiAddOnDB.escala = v end
local s = Settings.RegisterProxySetting(
  category,
  "MIADDON_ESCALA",
  Settings.VarType.Number,
  "Escala (%)",
  100,
  Get,
  Set
)
local opts = Settings.CreateSliderOptions(50, 200, 5)
Settings.CreateSlider(category, s, opts, "Tooltip del slider.")
```

Constantes útiles: `Settings.VarType.Boolean`, `Settings.VarType.Number`, `Settings.VarType.String`, `Settings.Default.True`, `Settings.Default.False`.

Documentación comunitaria ampliada: [Settings API (Warcraft Wiki)](https://warcraft.wiki.gg/wiki/Settings_API).

---

### 2. Layout canvas (marco propio pintado a mano)

- `local category = Settings.RegisterCanvasLayoutCategory(miMarco, "Nombre en la lista")`
- `Settings.RegisterAddOnCategory(category)`
- Subcategorías: `Settings.RegisterCanvasLayoutSubcategory(categoriaPadre, otroMarco, "Subtítulo")` (árbol en la lista lateral).

Sirve para UI totalmente custom. **No** reutilices plantillas `InterfaceOptions*`: si necesitas un checkbox dentro del canvas, usa plantillas del sistema **actual** enlazadas a `Settings` (p. ej. controles generados vía API de arriba) o construye el control a mano sin heredar plantillas obsoletas.

---

## Qué evitar en 12.0.1

| Evitar | Motivo |
|--------|--------|
| `InterfaceOptionsSmallCheckButtonTemplate`, `InterfaceOptionsCheckButtonTemplate`, etc. | Ausentes o no garantizadas; error `Couldn't find inherited node`. |
| `InterfaceOptions_AddCategory` | Obsoleto; usar `Settings.RegisterAddOnCategory`. |
| `InterfaceOptionsFrame_OpenToCategory` | Sustituido por `Settings.OpenToCategory(id)` con el `id` devuelto por `category:GetID()`. |

---

## Comprobación rápida en el juego

1. `/reload` tras cambiar `.lua` del addon.
2. **Esc → Opciones → AddOns →** tu addon.
3. Si algo falla, BugSack / consola: mensaje y línea de `CreateFrame` / `Settings.*`.

---

## Chukie UI (este repositorio)

- Panel de opciones implementado con **`RegisterVerticalLayoutCategory`** + **`RegisterVerticalLayoutSubcategory`**, **`RegisterAddOnSetting`** / **`RegisterProxySetting`** y **`CreateCheckbox`** / **`CreateSlider`** / **`CreateDropdown`** (Retail 12.x).
- `## Interface: 120001` en `Chukie_Ui.toc` debe coincidir con el cliente para no marcar el addon como desactualizado.

### Guardado `ChukieUiDB` y perfiles

- **`ChukieUiDB.currentProfile`**: nombre del perfil activo (string).
- **`ChukieUiDB.profiles`**: tabla `{ [nombre] = { enabled, minimapBar = {...}, cvars = {...} } }`. El perfil **`Default`** es el que recibe la migración desde el formato antiguo y los valores por defecto del addon.
- Las opciones de juego **no** van duplicadas en la raíz de `ChukieUiDB`: todo lo configurable vive dentro del perfil activo salvo `currentProfile` y `profiles`.

Última revisión orientada a **interface 120001** (documento pensado para ir afinándolo cuando cambie la API en parches posteriores).
