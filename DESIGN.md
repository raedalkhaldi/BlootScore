---
version: alpha
name: Majlis
description: Warm, minimal, Khaleeji-premium scorekeeper identity for BlootScore. Arabic/RTL-first.
colors:
  primary: "#1A1A1D"
  ink: "#1A1A1D"
  muted: "#6B7280"
  surface: "#FFFFFF"
  canvas: "#FAF8F5"
  border: "#E7E3DC"
  team1: "#1E3A8A"
  team2: "#B1222B"
  accent: "#96510C"
  on-accent: "#FFFFFF"
  success: "#046B48"
  warning: "#B85A10"
  dobble: "#5A3C91"
  mic-active: "#A62421"
typography:
  display-xl:
    fontFamily: SF Pro Rounded
    fontSize: 64px
    fontWeight: 800
    letterSpacing: -0.02em
  display-lg:
    fontFamily: SF Pro Rounded
    fontSize: 38px
    fontWeight: 700
    letterSpacing: -0.01em
  title:
    fontFamily: SF Pro
    fontSize: 17px
    fontWeight: 600
  body:
    fontFamily: SF Pro
    fontSize: 15px
    fontWeight: 400
    lineHeight: 22px
  label:
    fontFamily: SF Pro
    fontSize: 13px
    fontWeight: 600
  caption:
    fontFamily: SF Pro
    fontSize: 12px
    fontWeight: 400
  micro:
    fontFamily: SF Pro
    fontSize: 11px
    fontWeight: 500
    letterSpacing: 0.04em
rounded:
  xs: 6px
  sm: 10px
  md: 14px
  lg: 18px
  xl: 24px
  pill: 999px
spacing:
  xxs: 2px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
components:
  score-card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: 20px
  score-number:
    textColor: "{colors.primary}"
    typography: "{typography.display-xl}"
  score-team1:
    textColor: "{colors.team1}"
    typography: "{typography.display-xl}"
  score-team2:
    textColor: "{colors.team2}"
    typography: "{typography.display-xl}"
  badge-success:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.success}"
    typography: "{typography.micro}"
    rounded: "{rounded.xs}"
    padding: 4px
  badge-warning:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.warning}"
    typography: "{typography.micro}"
    rounded: "{rounded.xs}"
    padding: 4px
  badge-dobble:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.dobble}"
    typography: "{typography.micro}"
    rounded: "{rounded.xs}"
    padding: 4px
  input-field:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: 12px
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    typography: "{typography.title}"
    rounded: "{rounded.md}"
    padding: 14px
  button-secondary:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.title}"
    rounded: "{rounded.md}"
    padding: 14px
  toggle-chip:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: 8px
  toggle-chip-active:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.surface}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: 8px
  mic-idle:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.pill}"
    size: 84px
  mic-listening:
    backgroundColor: "{colors.mic-active}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.pill}"
    size: 84px
  row-divider:
    backgroundColor: "{colors.border}"
    height: 1px
---

## Overview

BlootScore keeps score for Baloot — a card game played in living rooms across the Gulf, usually late into the night over karak and laughter. The UI should feel like its natural habitat: a well-loved scorebook on a wooden majlis table, not a clinical app screen.

The brief is "very simple, best UI/UX, without losing features." That translates to: hide everything secondary, make the two scores enormous and the mic reachable with a thumb, let color do the work of labels, and keep the game's specialist vocabulary (كبوت، دبل، مشاريع، صن، حكم) one tap away — never on the main surface when it isn't needed.

## Colors

The palette is a quiet foundation with two strong team voices and a single warm accent that means "do the thing."

- **ink (#1A1A1D)** — primary text, active toggle backgrounds, the big numbers when you want neutrality. Almost-black, never pure.
- **muted (#6B7280)** — labels, inactive states, supporting copy. Loud enough to read, quiet enough to recede.
- **surface (#FFFFFF)** — card backgrounds. One layer above canvas.
- **canvas (#FAF8F5)** — the page. A warm bone that takes the edge off iOS's default cold gray and references the cream of a paper scorebook.
- **border (#E7E3DC)** — hairline dividers, never shadows for separation. Warm to match canvas.
- **team1 (#1E3A8A)** — "نحن." Deep lapis — richer than iOS system blue, reads as considered rather than default.
- **team2 (#B1222B)** — "هم." Deep ruby — confident and warm, avoids the hazard-red of system red.
- **accent (#C8771C)** — the *only* call-to-action color. Mic (idle), the primary "تسجيل" button, the active microphone glow. Warm brass — Khaleeji without being costume.
- **mic-active (#C7302E)** — the mic turns red *only while actively recording*. Red here means "recording now," not "press me."
- **success (#058A5A)** — buyer-won checkmarks, positive round indicators.
- **warning (#D86A15)** — "لعبة جديدة" confirmation, raw-input over-limit warnings.
- **dobble (#6D4AA8)** — the `x2` badge and anything dobble-related. Distinct from both team colors so it reads as meta.

**Pairing rules that aren't obvious from the swatches:**
- Team colors are for *numbers and team labels only* — never for chrome, borders, or icon tints elsewhere. If every element uses team color, nothing does.
- Accent never appears twice on the same screen. One amber element at a time keeps "where do I tap next?" unambiguous.
- On a score card, the number uses the team color; everything else on that card (name, "بنط" caption) uses muted. Let the score be loud; let the frame be quiet.

## Typography

One family, SF Pro — it renders as SF Arabic natively for RTL without extra work. The numeric sizes use SF Pro Rounded because Baloot scores are the hero content and rounded numerals feel less like a spreadsheet.

- **display-xl (64pt Rounded)** — the two team scores on the main board. This is the single most important piece of data in the app and should read from across the table.
- **display-lg (38pt Rounded)** — number inputs (simple mode score fields, raw card-point fields in detailed mode). Large enough that thumb-typing feels confident.
- **title (17pt)** — primary buttons ("تسجيل"), navigation title, sheet headers.
- **body (15pt)** — the live transcript, result preview prose, round-history numbers that aren't the hero.
- **label (13pt, semibold)** — toggle chips, small buttons (صن/حكم/المشتري), column headers.
- **caption (12pt)** — helper text under score cards ("بنط"), inline hints ("سمعت: …"), game-type pills in round history.
- **micro (11pt, tracked)** — badge text like `x2`, `ج` in the history column header. Letter-spacing opens it up.

The Arabic script already has its own rhythm — avoid bold for body copy (it collapses contrast between script and numerals). Reserve weight 700+ for numbers and primary-action titles.

## Spacing & Rounded

The scale is an 8pt grid with a 4 and 12 for fine-tuning. Most screens should live at `lg` (16) for section gaps and `md` (12) for internal component padding. `xl` (24) is for the breathing room *between* conceptually different zones (scoreboard ↔ input, input ↔ history).

Radii are generous but not cartoonish:
- `sm (10)` for small pills, chips, input backgrounds.
- `md (14)` for primary buttons, input-field cards.
- `lg (18)` for score cards and main content panels.
- `xl (24)` for bottom sheets.
- `pill (999)` for the mic.

Prefer hairline borders (1px @ `colors.border`) over shadows for separation. One soft shadow, reserved for the score cards only, signals "this is the main surface" — everything else is flat.

## Components

**Score card** — The visual anchor. Team name (caption) on top, massive number in the middle, "بنط" caption below. Editable name is still a TextField but with no visible chrome until focused. One `lg` radius. One soft shadow. No border. Team color is used *only* on the number — the name is muted, the caption is team-color at 50% opacity (kept, it's a nice touch from the current design).

**Progress bar** — Stays thin (6px), sits directly under the score cards, hairline-subtle when nobody's close, gaining presence as either team crosses 100 / 140. Team colors fill from their respective sides toward the center.

**Mode switcher (مبسط / تفصيلي)** — A two-up segmented pill at the top. Active segment = `ink` background with `surface` text. Inactive = `canvas` background with `muted` text. Nothing colored — this isn't a primary action.

**Mic button** — Idle: **accent (amber) circle, white mic icon.** Listening: **mic-active (red) circle with a concentric stroke ring and a square stop icon.** Processing: accent with a spinner. The current design flips these (red at idle, dim red while listening), which makes idle look alarming; the amber-at-idle pattern makes "tap me" and "recording now" clearly distinct.

**Primary "تسجيل" button** — accent fill, white title. Disabled state: `canvas` fill, `muted` title. Full width, `md` rounded, `md` padding. Lives directly under the mic or the detailed entry section — never competes with it.

**Toggle chips (صن/حكم, المشتري, كبوت, دبل)** — Row of pill-ish chips at `sm` radius. Active = `ink`/`surface`. Inactive = `canvas`/`muted`. The exceptions are kaboot and dobble: their *active* state uses their semantic color (warning-orange and dobble-purple respectively) because they're significant game modifiers, not neutral choices.

**Declaration steppers** — The collapsed "off" state is a label chip at `canvas`/`muted`. Once incremented, it expands into `canvas`/`team-color` with a minus/plus pair. The current design does this well; keep the pattern but switch to the theme tokens.

**Round history** — A single flat card with hairline dividers between rows. Team numbers use team colors; the center column (round number + game type + dobble badge + win/loss check) uses muted + micro type. Tap a row to edit — the whole row is the hit target, no chevron needed (discoverable via the existing edit sheet).

**Result preview (detailed mode)** — Surface card, hairline border in success-green at 30% or a rose-red at 30% to telegraph the round outcome before saving. Keep the live-update behavior — it's the best teaching feature of the detailed mode.

**Winner sheet** — Full-height sheet. Warm canvas background. Winner name in `display-xl` in the winning team's color. Final scores side-by-side below. Big accent "لعبة جديدة" button at the bottom. No confetti; this is a majlis, not a slot machine.

**Sheets & dialogs** — All sheets use `xl` radius on the top corners, `canvas` background, and a short title in `title` type. The edit-round sheet should feel like a quick inline adjustment, not a modal form — one row of two number inputs, a save button, a small destructive "حذف" link.

## Notes for implementation

- These tokens should be exposed in code as a single `Theme` namespace (e.g., `Theme.Color.team1`, `Theme.Spacing.lg`) so views never reference raw hex or pt values. When you need a value that isn't in the tokens, add it to `DESIGN.md` first rather than inlining it.
- RTL is applied at the app root via `.environment(\.layoutDirection, .rightToLeft)` — this is already in place. Keep it. Do not mirror team colors or positions to match RTL; "team1 on the right" is a conscious identity choice, not a layout accident.
- Haptics: tap on a toggle chip = light impact, successful round save = success notification, game-over = medium impact. Physical feedback is part of the feel and costs nothing.
