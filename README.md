# Chukie UI

Addon de interfaz para **World of Warcraft Retail** (TOC `## Interface: 120001`).

## Instalación

Copia la carpeta `Chukie_Ui` en:

`_retail_\Interface\AddOns\`

Activa **Chukie UI** en el selector de addons. Opcional: **Masque**.

## Contenido principal

- Minimapa: posición, escala, rotación (`rotateMinimap`), flecha del jugador, zoom preferido (límites del motor).
- Barra de iconos con proxies (LibDBIcon, etc.) y Masque.
- Opciones: *Esc → Opciones → AddOns → Chukie UI*.

## Publicar en GitHub (desde tu PC)

1. **Instala [Git for Windows](https://git-scm.com/download/win)** y abre **Git Bash** o PowerShell donde `git` funcione.

2. En [GitHub](https://github.com/new) crea un repositorio **vacío** (sin README ni .gitignore si vas a subir este proyecto tal cual), por ejemplo `Chukie_Ui`.

3. En la carpeta del addon ejecuta (cambia `TU_USUARIO` y el nombre del repo si hace falta):

```bash
cd "/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/Chukie_Ui"
git init
git add .
git commit -m "Initial commit: Chukie UI"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/Chukie_Ui.git
git push -u origin main
```

Si GitHub exige autenticación, usa un **Personal Access Token** como contraseña (no la contraseña de la cuenta) o configura **SSH** y usa `git@github.com:TU_USUARIO/Chukie_Ui.git`.

### Alternativa: GitHub CLI

Si tienes [`gh`](https://cli.github.com/) autenticado:

```bash
cd "/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/Chukie_Ui"
git init && git add . && git commit -m "Initial commit: Chukie UI"
gh repo create Chukie_Ui --private --source=. --remote=origin --push
```

Ajusta `--public` o `--private` según prefieras.

## Nota sobre `Media/`

Las texturas PNG de `Media/` **no** deben listarse en el `.toc` (el cliente las cargaría como Lua/XML). Se referencian por ruta desde Lua (`SetPlayerTexture`, etc.).
