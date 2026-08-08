# Chukie UI — estado del proyecto y respaldo

**Instantánea:** 2026-08-08  
**Versión en `Chukie_Ui.toc`:** 0.3.0  
**Interface WoW:** `120100, 120007` (Retail 12.1 + compat 12.0.7)

Este documento describe el estado del addon y cómo restaurarlo.

---

## Seriales / TOC

| Campo | Valor |
|-------|--------|
| `## Interface` | `120100, 120007` |
| `## Version` | `0.3.0` |
| Branch tipica | `dev` |

El TOC declara `120100` **por adelantado** (12.1 previsto tras el mantenimiento semanal; hasta entonces el cliente sigue en 12.0.7 / `120007`). Tras el update: `/reload` y comprobar:

```
/dump select(4, GetBuildInfo())
/chukieui auracheck 436336
```

En 12.1 esperable: `auraContainerAPI=true` y `displayBackend=container` para reglas aura “Presente”.

---

## Qué cambió respecto a 12.0.7 (impacto en Chukie)

| Área | Impacto |
|------|---------|
| **AuraContainer / AuraButton** | API oficial 12.1. Chukie ya tiene `AlertsAuraContainer.lua` con feature-detect + `AddAuraSlot`/`AddAuraGroup` + `includeSpellIDs`. |
| **UNIT_AURA / UnitAura secretos** | En secreto el payload/listado es más opaco. Path legacy de alertas por spellId/icon **sigue sin poder** identificar Mass Disintegrate en combate. |
| **Crear AuraContainer en combate** | Error intencional en 12.1 → Chukie difiere creación a `PLAYER_REGEN_ENABLED`. |
| **SecureAuraHeaderTemplate** | Eliminado en Mainline. Chukie no lo usaba. |
| **Private aura anchors** | Siguen siendo para private auras de encuentro, **no** para buffs personales ContextuallySecret (p.ej. Mass Disintegrate). |
| **Action bars / secret CD** | Sin cambio de diseño; ya hay guards `issecretvalue` en barras/mini barra/alertas CD. |
| **getglobal / setglobal** | Deprecados en 12.1. Chukie no los usa en código propio. |

---

## Archivos de alertas (orden TOC)

- `Alerts.lua` — reglas, evaluación legacy, host de overlays  
- `AlertsAuraContainer.lua` — motor 12.1  
- `AlertsManager.lua` — wizard `/chukie-aura`  
- Media: `AlertsMedia.lua`, `AlertsUserMedia.lua`, `Media/Alerts/`

---

## Funcionalidad actual (resumen)

- Paneles izq/der, minimapa, micromenú, RightStrip, widgets, teleports.
- Barras de acción propias (`ActionBars.lua`) + mini barra.
- Alertas: CD / proc / aura; display icono / arte PowerAuras / texto.
- En **12.1**, aura “Presente” sin filtro de stacks → AuraContainer cuando la API responde.
- En **12.0.7**, mismo código cae a legacy (auras secretas no trackeables de forma fiable).

---

## Limitaciones conocidas

1. Auras ContextuallySecret en 12.0: no hay lectura por spellId/icon.
2. PrivateAuraAnchor ≠ solución para Mass Disintegrate.
3. Preview del wizard de auras sigue en frames legacy (`forceShow`).
4. Ausente / Siempre / filtro stacks: no van por AuraContainer (legacy).
5. Zygor / proxies / taint: ver notas históricas del README.

---

## Restaurar desde ZIP

1. Cierra WoW o `/reload` tras copiar.
2. Carpeta `Chukie_Ui` → `_retail_\Interface\AddOns\`.
3. Activa el addon; SavedVariables en `WTF\...\ChukieUiDB.lua` (no van en el ZIP de código).
