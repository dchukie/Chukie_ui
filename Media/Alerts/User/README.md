# Media de usuario (alertas)

1. Copiá texturas **`.tga`** o **`.blp`** (con transparencia) a esta carpeta.
2. Editá `AlertsUserMedia.lua` en la raíz del addon y agregá el nombre del archivo a `textures` / `fonts` / `sounds`.
3. `/reload`.

WoW no permite listar el contenido de una carpeta desde Lua: hace falta el registro explícito.

Si tenés **LibSharedMedia-3.0** / **SharedMedia** (u otro pack que registre en LSM), el picker de arte también muestra backgrounds, statusbars y borders compartidos.
