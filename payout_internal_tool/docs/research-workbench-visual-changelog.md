# Research Workbench Visual Changelog

## Scope

Restyled **PE Ops** frontend to a light research-workbench / tech-terminal look  
(white + fluorescent yellow + black).

**Excluded (untouched):** entire `lib/screens/nz_trip/**` (NZ packing list).

## Confirmation: visual only

- No auth, API, routing, validation, or data-model changes.
- Nav still switches the same page index / same destinations.
- Forms, buttons, and menus keep the same handlers and props.
- NZ trip route, PIN gate, and theme remain isolated.

### Logic changes required? 

**None.** Decorative tags (`engTag`, `// MODULES`, status track) are display-only.

## Files touched

| Area | Files |
|------|--------|
| Tokens / theme | `lib/theme/app_theme.dart`, `lib/theme/hud_decor.dart` (new) |
| Chrome widgets | `ambient_background.dart`, `glass_surface.dart`, `status_pill.dart`, `app_section_header.dart` |
| Shell / login | `lib/app.dart`, `lib/screens/login_screen.dart` |
| Public archive | `lib/screens/public_template_library_page.dart` |
| Font alignment | `payout_renotify_screen.dart`, `template_library_screen.dart` (GoogleFonts family only) |
| Embedded HTML tools | `web/jwt-token-generator.html`, `web/coda-hosted-card.html` (CSS tokens / fonts) |
| Docs | `docs/research-workbench-design-tokens.md`, this file |

## What changed visually

- Dark zinc + indigo → **paper canvas + yellow accent + black ink**
- Soft radii → **hard edges**
- Inter / JetBrains Mono → **Noto Sans SC + Space Mono**
- Sidebar selected = yellow block + left ink bar + ENG tag
- Panels = white fill, black stroke; snackbars = black + yellow border
- Ambient grid + dashed yellow status tracks
- HTML tools CSS variables aligned to the same palette

## Follow-ups (optional polish, still visual)

Some older screens (esp. Sandbox Monitoring) still contain local dark-gradient cards with white type. They remain readable as self-contained dark modules on the light canvas. A later pass can flatten those cards into white/yellow/black panels without touching monitoring logic.
