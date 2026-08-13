# Research Workbench Design Tokens

Visual language for PE Ops (everything **except** the NZ packing list).  
Palette intent: **light paper canvas + fluorescent yellow accent + black ink**.

## Color

| Token | Value | Role |
|-------|-------|------|
| `canvas` | `#F4F3EE` | Lab / paper background |
| `surface` / `surfaceElevated` | `#FAFAF7` / `#FFFFFF` | Panels, cards |
| `surfaceMuted` | `#EFEDE6` | Quiet fills |
| `accent` | `#FFE500` | Sole primary highlight (selected, lamps, tracks) |
| `accentHover` / `accentDeep` | `#FFF06A` / `#E6CF00` | Hover / pressed yellow |
| `ink` | `#121212` | Borders, type, solid controls |
| `textPrimary` | `#121212` | Body titles |
| `textSecondary` / `textMutedOnDark` | `#4A4A4A` / `#6B6B6B` | Secondary copy |
| `onInk` | `#FFE500` | Text on black buttons |
| `success` / `error` / `warning` | `#1B7A3D` / `#C62828` / `#B45309` | Functional status only |

**Rules**
- Yellow is emphasis only — never large body-text backgrounds.
- Primary CTA = **black fill + yellow type** (or yellow fill + black type for selected chips).
- Strokes are black (`1.25px` default, `1.75–2px` when selected/focused).

## Typography

| Role | Font | Notes |
|------|------|-------|
| Display / title / body | **IBM Plex Sans** | `w600–w700` titles (chosen over Noto Sans SC for Flutter web perf) |
| Labels / data / tags | **IBM Plex Mono** | Uppercase, letter-spacing ≈ `1.2` for labels |

Open-source via `google_fonts`. No proprietary game/UI fonts.  
Avoid full CJK webfonts on every text style — they tank web load/jank.

## Shape

| Token | Value |
|-------|-------|
| `AppRadii.sm–lg` | `0–2` | Hard / near-square edges |
| Selected module | Yellow fill + black stroke + **left ink bar** |

## Decorative system (non-functional)

- Yellow **dashed status track** (`HudDecor.statusTrack`)
- `// TAG` mono captions (`// PAYOUT`, `// ARCHIVE`, …)
- Corner indices (`WB / 00.05`, `R / 01`)
- Status lamps (filled yellow circle, black ring)
- Faint paper **grid** on `AmbientBackground`

## Motion

| Token | Value |
|-------|-------|
| `AppMotion.snap` | `120ms` |
| `AppMotion.panel` | `180ms` |
| Curve | `easeOutCubic` |

Prefer `transform` / `opacity` / color. Respect `MediaQuery.disableAnimationsOf` / `prefers-reduced-motion` where screens already do.

## Selection pattern

1. Yellow block background  
2. Black 1.25px border  
3. 3px left ink indicator  
4. Optional `// ENG` tag under Chinese/English title  

## Source of truth

`lib/theme/app_theme.dart` + `lib/theme/hud_decor.dart`
