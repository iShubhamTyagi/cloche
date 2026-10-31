# Cloche · Design handoff

Oct 31, 2026 · @Shubham

## Overview

The oven door opens from a bottom hinge on every device: the iPhone flips up, the Duo folds shut like a lid. This spec covers Stage 1 (prep to grade) and Stage 2 (decorate, serve, early open) for the iPhone and for the iPhone Duo held in portrait. Every screen is on the [Cloche design canvas](https://claude.ai/artifact/MDSEN2XYYDQnRpU4vM3tsK); board names below match the canvas titles.

| Area | Canvas boards | Status |
| --- | --- | --- |
| Foundations and shared pieces | Foundations, Dish, Wide OTG oven, Stars, Grade card | Final |
| iPhone core loop | 1 Prep, 2 Preheat, 3 Bake face-down, 4 Reveal, 5 Grade | Final |
| iPhone Stage 2 | S2 1 to S2 8 | Final |
| Duo portrait core | Duo 1 to Duo 6 | Final |
| Duo portrait Stage 2 | Duo S2 1 to Duo S2 5 | Final |
| Duo landscape, side-hinged door | Backup row, far right | Reference only, do not build |
| Palette options A to E | Palettes | Reference; E (Ivory and ink) was chosen |

**Reference frames.** iPhone 390 by 844 pt. Duo inner display 620 by 880 pt in portrait, split by the hinge into two 620 by 440 halves. Duo cover display 500 by 400 pt. The Duo sizes are design assumptions; confirm against the real device before layout is locked.

**Fold model.** The hinge line is the oven's bottom hinge. Unfolded, the top half is the oven (or the decorating table) and the bottom half is the open door lying flat. Folded shut, the cover display shows the closed oven front.

## Design tokens

The interface has no hue: ivory on near-black. All colour lives on the food (icing, toppers, crust) and, for one moment only, the last-30-seconds ring. Ember orange and raspberry were rejected and must not appear in the interface. The orange heating rods exist only inside the oven artwork.

### Colour

| Token | Value | Usage |
| --- | --- | --- |
| `color-ground` | #0E0E0D | Screen background |
| `color-surface` | #1A1917 | Topper tiles, door and tray panel base |
| `color-text` | #F6F1E7 | Primary text, icons |
| `color-muted` | #AEA89B | Eyebrow labels, secondary text (4.5:1 or better on ground) |
| `color-subtle` | #8C877C | Hints, tab numerals, tertiary notes |
| `color-accent` | #F2E6CD | Primary button fill, ring progress, selected outline |
| `color-sand` | #CDB58A | Serif voice lines, values, active tab underline |
| `color-honey` | #E3C07D | Last-30-seconds ring and note only |
| `line-1` | rgba(246,241,231,0.12) | Hairlines, table rules |
| `line-2` | rgba(246,241,231,0.16) | Chip, pill and input borders |
| `line-3` | rgba(246,241,231,0.24) | Outline button border |

### Food colour

| Token | Value | Notes |
| --- | --- | --- |
| `icing-rose` | #F3B7AE | Default frosting |
| `icing-pistachio` | #BFD9A0 |  |
| `icing-lilac` | #CDB4EA |  |
| `icing-butter` | #F4E3A1 |  |
| `icing-sky` | #A9CDEB |  |
| `icing-cocoa` | #6B4330 | Needs a 1 px `line-2` border on dark surfaces |
| `sprinkle-1` to `sprinkle-5` | #F29AB5, #8FD0C4, #F4D77A, #A9B7F0, #FFFFFF | Sprinkles and topper accents |
| `bake-pale`, `bake-golden`, `bake-dark` | #E4C98F, #CC8A3E, #5E3115 | Browning bar gradient stops |

Topper fills: cherry #8E2B3A, star #F4D77A, pearl #E6DFD0, heart #F29AB5, mint leaf #8FD0C4, candle #A9B7F0 with a #F4D77A flame.

### Type

Fonts: **Instrument Sans** 400, 500, 600 for interface; **Newsreader** 300 to 500 for numerals and the italic "voice". Timers and counts use tabular figures. No text below 11 pt.

| Token | Spec | Used for |
| --- | --- | --- |
| `type-eyebrow` | Sans 11, caps, tracking 0.14em, `color-muted` | Labels above values, section labels |
| `type-body` | Sans 15/22, `color-muted` | Helper paragraphs |
| `type-button` | Sans 17/600, tracking 0.02em | Primary button |
| `type-control` | Sans 14/500 | Tabs, chips, text buttons |
| `type-hero` | Serif italic 300, 76/80 on iPhone, tracking -0.02em, `color-sand` | "Prêt." |
| `type-title` | Serif italic 300, 42/46 (38/42 on ajar) | Screen headlines |
| `type-name` | Serif 400, 32/36 (30/34 on saved) | Dish name |
| `type-numeral` | Serif 300, up to 88/88, tabular | Bake timer, ajar countdown |
| `type-voice` | Serif italic 15 to 20 | Captions, grade lines, collection number |

### Spacing, radius, effects

| Token | Value | Usage |
| --- | --- | --- |
| `space-1` to `space-4` | 4, 8, 12, 16 | Gaps inside controls and trays |
| `space-margin` | 24 | Screen side margin on iPhone and Duo decorate |
| `tap-min` | 44 | Minimum hit height for every control |
| `button-primary` | 58 high, radius 29 | Full-width pill, `color-accent` fill |
| `button-outline` | 54 high, radius 27, `line-3` | "Done" |
| `radius-screen` | 44 (iPhone), 28 (Duo inner), 36 (cover) | Frame corners |
| `radius-card` | 28 | Decorating canvas |
| `radius-tile` | 14 | Topper tiles, temperature segments |
| `radius-chip` | 12 | Finish chips |
| `glow-primary` | 0 10 30 rgba(242,230,205,0.28) | Primary button shadow |
| `grain` | 4 px dot grid, rgba(246,241,231,0.05) | Over every dark screen |
| `shadow-plate` | ellipse, rgba(0,0,0,0.38), blur 14 | Under the plate on the canvas |

## Components

Each component below is one reusable view with the listed parameters. Names match the canvas component boards.

| Component | Parameters | Variants and states | Behaviour notes |
| --- | --- | --- | --- |
| Dish | dish (cupcake now), progress 0 to 1, tone, frosted, icing, plate, size | Raw below 0.6, baked from 0.6; frosted uses one of six icing renders | Code-drawn in production (parameters, not four swapped images). The cupcake art on the canvas is a 3D reference render. |
| Wide OTG oven | width, angle (0 closed, 90 door dropped), progress, plate text, plate italic | Closed raw (below 0.3), baking (0.3 to 0.95), ready (0.95 and up); open raw, half (0.2 to 0.6), done (0.6 and up) | Door hinges on the bottom edge. Display plate sits top right of the control column and carries a timer or word. |
| Stars | count 0 to 3, size | Filled `color-sand`, empty outline | Three stars: bake, temperature, serve. Half-baked caps at one. |
| Grade card | dish name, stars, doneness percent and label, browning label and position, caption | Fully baked, half-baked | 344 pt wide; Decorate and Serve plain buttons inside. |
| Ring clock | size, time text, progress (time remaining as 0 to 1), amber | Normal (`color-accent`, 6 stroke), amber (`color-honey`, 8 stroke, pulse) | Text size is 29% of ring size. Ring depletes clockwise from 12 o'clock. |
| Tab bar | active 0 to 2, width, family | Base, Toppings, Plate and finish; active shows `color-text` and a 2 pt `color-sand` underline | Three links, each 44 high, equal width. Free movement between tabs at all times. |
| Finishing canvas | width, height, dish size, icing, topped (none, some, full), plate 0 to 5, backdrop 0 to 5, caption, selection | One dish on a plate over a backdrop; selection frame shows on the cherry | Rendered from an ordered operations list, not pixels (see Assets). |
| Topper | kind (cherry, star, pearl, heart, leaf, candle), size, rotate | Six kinds | Placed items scale and rotate; up to 12 on a dish. |
| Tray, base | active icing 0 to 5, finish 0 to 2 | Six swatches (44 pt circles), chips Swirl, Spread, Rosette | Selected swatch has a 2 pt `color-accent` ring offset 2 pt. Undo and Clear at the bottom. |
| Tray, toppings | active tile 0 to 6, placed count | Six topper tiles plus Sprinkles; tiles 60 high in an auto-fill grid, 64 pt minimum | Tap to place, pinch to resize, hold to scatter sprinkles. Counter reads "n of 12 placed". |
| Tray, plate and finish | plate 0 to 5, backdrop 0 to 5, caption | Plates: Porcelain, Sand, Slate, Gilded, Board, Glass. Backdrops: Linen, Marble, Walnut, Slate, Blush, Night | Caption is one line, 40 characters, shown on the share card. |
| Duo stack | angle 0 to 80, cavity (raw, half, done), dim, steam | Door flat, or lifting about the hinge in perspective | Hinge barrels stay fixed while the door rotates. |

**Backdrop and plate values** are listed in the canvas component boards. Backdrops are the only light surfaces allowed in the app; text laid over a light backdrop (the caption) switches to `color-ground`-toned ink (#2A2623).

## iPhone core loop

Five screens, 390 by 844 pt, all on `color-ground` with `grain`. Safe area: content starts 56 pt from the top and keeps 30 pt at the bottom.

| Screen | Layout, top to bottom | Controls and behaviour |
| --- | --- | --- |
| 1 Prep | Header: "Cloche" in `type-voice` 22 left, Recipe book and Settings icon buttons (44 by 44) right. Hero dish on plate, 236 pt. Dish name `type-name` 34/38. Eyebrow with minutes and region. Five recipe circles (58 pt, 10 pt gap). Temperature segments (Low, Medium, High). Optional label field. Primary button. | Recipe circle: tap selects (1.5 pt `color-sand` border and soft glow). Locked dishes are greyscale at 60% brightness with a lock badge; selecting one swaps the button to "Part of the Full Kitchen" (outline, `color-sand`) with the note "Cupcakes and naan are always free". Temperature segments: 48 high, radius 14, three bars show heat level, selected has `color-surface` fill and 0.6 `color-sand` border; a `type-voice` 14 hint sits right of the label ("Golden at Medium last time"). Label field: 44 high, italic serif 18, hint "Stays on this phone". Primary "Preheat" goes to Preheat with the note "Then place the phone face down". |
| 2 Preheat | Back arrow (44 by 44) and eyebrow "Preheating". Wide oven closed, 342 pt wide, display plate reads "Ready". Headline "The oven is ready." `type-title`. Helper paragraph. Status pill "Waiting for a flat, face-down phone" with a pulsing dot. Three-cell summary (Recipe, Oven, Bake). Text button "Close the door another way". | Starting the bake is the player placing the phone face down; there is no start button. The pill dot pulses 2.4 s. Footer note: "The screen stays dark with a faint glowing line". |
| 3 Bake, face-down | Pure black (#000) screen, centred stack: eyebrow "Vanilla cupcakes · Medium", remaining time `type-numeral` 76 in `color-subtle`, a 220 by 1 pt `color-accent` glow line that breathes. | Burn-in guard: the stack drifts 16 pt vertically over 90 s. No other UI. Keeps the screen awake while baking (setting, default on). A stored end timestamp drives the timer so a suspended app still ends the bake correctly. |
| 4 Reveal | Eyebrow with dish name, "Prêt." in `type-hero`, wide oven with the door dropped open and steam over the cupcakes, primary button "See how it turned out". | Plays when the phone is flipped up after a finished bake. Door drop animation: see Interactions. Steam: three blurred ellipses rise 14 pt and fade, 5 to 6 s loops, staggered. |
| 5 Grade | Eyebrow "Fresh from the oven", dish 210 pt on plate, name `type-name` 32, three stars (34 pt), a `type-voice` 16 line, Doneness and Browning bars, primary "Decorate · 5 min", text button "Serve plain". | Doneness bar: 3 pt, fill `color-sand`, percent of time baked over target. Browning bar: gradient `bake-pale` to `bake-dark` with an 11 pt marker (ring `color-ground` 3 pt). Break length shown on the button follows the bake length (5, 8 or 10 min). "Serve plain" skips the break and forfeits only the serve star. |

## iPhone break and decorate

The break is one canvas, three tool tabs and one clock. It has no score, no fail state and no extension. Break length is 5, 8 or 10 minutes for 25, 50 or 90 minute bakes.

**Decorating layout (screens S2 1 to S2 4).** All four share one frame, so only the canvas contents, tab and tray change.

| Zone | Position (pt) | Content |
| --- | --- | --- |
| Header | x 24, y 58, 342 by 56 | Ring clock 56, then eyebrow (dish name) and "Finishing table" in `type-voice` 22, then "Serve now" (44 high, radius 22, `line-3`) |
| Canvas | x 24, y 128, 342 by 372, `radius-card` | Finishing canvas, dish 260 pt |
| Tab bar | x 24, y 512, 342 by 44 | Base, Toppings, Plate and finish |
| Tray | x 24, y 568, 342 wide, up to 248 high | Changes with the tab |

| Screen | What changes |
| --- | --- |
| S2 1 Base | Tray shows six icing swatches and three finish chips (Swirl, Spread, Rosette). Ring at 4:12 of a 5:00 break. Dish has frosting only. |
| S2 2 Toppings | Tray shows seven tiles and the "n of 12 placed" counter. The last placed topper shows a dashed selection frame with four corner handles. Ring at 3:05. |
| S2 3 Plate and finish | Tray shows six plates, six backdrops and a caption field. Caption renders on the canvas in `type-voice` 20, bottom centre. Ring at 1:40. |
| S2 4 Last 30 seconds | Ring and time switch to `color-honey` and pulse (1.6 s). A "30 seconds left" note appears at the top of the canvas (34 high, `color-honey` border, #0E0E0D at 82% fill). A soft chime plays at 30 s and a second at 5 s. |
| S2 5 Served | Eyebrow "Served", "Bon appétit." in `type-hero` 56, canvas 342 by 400, three stars (34), line "Baked, finished and served." A 2 pt line at the bottom drains over 5 seconds, then the screen advances to S2 6. Tapping anywhere advances early. |
| S2 6 Saved | Eyebrow "Saved to your recipe book", canvas 342 by 340, dish name, three stars (30), "No. 1 in your collection". Exactly two buttons: "Bake again" (primary, with the note that it asks for a face-down phone) and "Done" (outline, 54 high). No interstitials, no ads. |
| S2 7 Door ajar | Shown when the phone is flipped up during a bake. Open oven at 38% opacity behind a dark gradient. Pill "Door ajar", 190 pt ring with a 15 to 0 second countdown (`type-numeral` 88), headline "Shut the door.", helper "Place the phone face down to keep baking. Left up, this bake ends as half-baked." |
| S2 8 Half-baked grade | Same layout as Grade with: eyebrow "Opened early", dish at progress 0.3, one star, line "Nothing is lost. It still goes in your recipe book.", doneness 62% "Half-baked", browning "Pale". Decorate and Serve plain still work. |

**Rules that apply to every decorating screen.** A break cannot start without a bake. Serve now is always visible and loses nothing. When the stored end time passes, the tools fade, the dish slides to the table, a flash snaps the share card, and the dish is saved, even if the app was in the background. Undo and Clear apply within the current tab only.

## iPhone Duo, portrait

Held in portrait, the Duo's hinge runs horizontally at y = 440 of the 880 pt inner display. The top half is the oven or the decorating table; the bottom half is the open oven door lying flat. Closing the phone lifts the door over the oven; the cover display then shows the closed oven. Nothing important, and no text, sits across the hinge band.

**Hinge details (all Duo inner screens).** Crease shadow: 24 pt band centred on y = 440, black at 62% in the middle, fading to clear. Two chrome hinge barrels, each 86 by 16 pt, at x = 34 and x = 500, y = 432. Barrels never move; only the door rotates. Door panel starts at y = 441, 502 pt wide in core states (matches the oven body width) and 612 pt wide in decorating states, where it doubles as the tool tray. Use the hinge angle only for effects; layout never depends on it.

| Screen | Top half (y 0 to 440) | Bottom half (door, y 441 to 872) | Behaviour |
| --- | --- | --- | --- |
| Duo 1 Unfolded, armed | Oven cavity, raw cupcakes, rods glowing | Door glass window 409 by 330 pt at x 50, y 485. Fold icon, headline "Close the door to start your bake." (`type-title` 30), pill "Waiting for the fold", Recipe, Oven, Bake cells, text button "Use face-down instead". Chrome handle bar 380 by 12 pt at the far edge. | Folding the phone shut starts the bake. Face-down works as the fallback. |
| Duo 2 Door ajar | Cavity dimmed to 20% (scrim at 80%): pill "Door ajar", 150 pt ring with 15 to 0 s countdown (`type-numeral` 68), headline "Lift the door shut." (32), helper text | Door rotated about its top edge (the hinge) by the hinge angle, in 1700 pt perspective, with a downward shadow | Door angle follows the real hinge angle (design shows 34 degrees). Closing within 15 s resumes the bake; at 15 s the bake ends as half-baked. |
| Duo 3 Closed, baking (cover 500 by 400) | Closed wide oven, 476 pt wide at x 12, y 10. Timer on the oven display plate. | Eyebrow "Baking · Vanilla cupcakes" at y 362, progress line 2 pt at the bottom (inset 60) | Runs on the cover display while closed. Drifts 7 pt over 60 s as burn-in protection. |
| Duo 4 Closed, ready (cover) | Same oven, ready art with brighter rods; plate reads "Prêt." in italic `color-sand` | Line with chevron icon: "Vanilla cupcakes are ready. Lift the lid to open the door" | Ready waits indefinitely until the phone is unfolded. Background glow pulses over 4 s. |
| Duo 5 Unfolded, reveal and grade | Cavity with golden cupcakes and steam | Grade layout inside the 409 by 330 glass: dish 124 pt, eyebrow, "Prêt." 48, three stars (22), caption, Doneness and Browning bars side by side (22 pt gap), "Decorate" (48 high) and "Serve plain" | Door swings open with the unfolding hinge. Decorate goes to Duo S2 1. |
| Duo 6 Opened early | Cavity with part-baked cupcakes, rods hot, no steam | Same grade layout: "Opened early", "Half-baked." 40, one star, doneness 62%, browning "Pale" | Nothing is lost. |

### Duo decorating (Duo S2 1 to 5)

Top half: Finishing canvas 620 by 436, no corner radius, dish 300 pt (240 pt when served), a 96 pt top scrim for the header. Header at x 24, y 24: ring clock 56, "Finishing table", "Serve now". Bottom half (the door as tray): tab bar at x 24, y 462, 572 wide; tray at x 24, y 524, 572 wide; the handle bar stays at y 850. Tray tiles use the same auto-fill grid, so seven topper tiles sit in one row.

| Screen | Content |
| --- | --- |
| Duo S2 1 to 3 | Base, Toppings, Plate and finish, same tray components as the iPhone at 572 pt width |
| Duo S2 4 | Last 30 seconds: ring amber, "30 seconds left" note at y 92, centred |
| Duo S2 5 Served | Top: "Served" and "Bon appétit." (44) over the canvas. Bottom: "Saved to your recipe book", three stars (34), name and number, two side-by-side buttons 58 high ("Bake again", "Done"), note that Bake again asks you to close the phone like an oven door |

## Interactions, state machine and motion

The oven door is the only control. Placing the phone face-down (iPhone) or folding the Duo shut starts the bake; reversing that opens the door. Every screen state below is driven by that one signal plus the timers.

&#91;embedded content: bake state machine · 12 states, 2 loops back\]

From Baking, opening the door starts a 15 s grace. Closing it in time resumes the bake; letting it run out ends the bake as half-baked. A finished bake waits in Ready until the door is opened.

**Motion**

Easing curves are proposed throughout. Durations marked proposed were not fixed in the designs.

| Element | Trigger | Motion | Duration | Easing | Reduced motion |
| --- | --- | --- | --- | --- | --- |
| Oven door | Ready to Reveal, and closing again | Drops about the bottom hinge (rotateX, perspective 1700 px) | 700 ms (proposed) | ease-in-out | Cross-fade to the open art, 150 ms |
| Ajar door | Door opened during a bake | Rests at 34 degrees, cavity dimmed to 0.8 on Duo | 300 ms (proposed) | ease-out | Snap to 34 degrees |
| Steam | Door open, Reveal | Three soft puffs rise about 50 pt and fade, staggered | 5 s, 5.5 s and 6 s, looping | ease-out | Off |
| Progress ring pulse | Baking | Slow pulse on the ring head | 1.6 s | ease-in-out | Static ring |
| Ready glow | Ready | Slow breathing glow behind the oven | 4 s | ease-in-out | Static glow |
| Status pill dot | Baking | Dot fades in and out | 2.4 s | ease-in-out | Static dot |
| Burn-in drift | Screen on during a bake | Layout shifts a few points in small steps | 90 s iPhone, 60 s cover | linear | Keep; too slow to read as motion |
| Served line | Served | Line drains from full to empty | 5 s | linear | Static line; the screen still ends after 5 s |

## Content rules and edge cases

The app is local-only (no server in v1), so there are no loading or network error states. Rows marked **Proposed** are design decisions made here that the PRD does not state; confirm them.

| Case | Rule |
| --- | --- |
| Dish name length | One line in the Prep and Saved screens; Grade card wraps to two lines at most, then truncates with an ellipsis. Longest shipped name: "Chocolate drip cake" (19 characters). Leave room for 30 characters in other languages. |
| Work label (Prep) | Optional, 40 characters, never leaves the device. Empty is valid and shows the italic placeholder. |
| Caption (Plate tab) | One line, 40 characters, counter "n/40" beside the field. Appears on the canvas and the share card. Empty means no caption block. |
| Toppers | 12 per dish. At 12, tiles stay visible but ignore taps and the counter reads "12 of 12 placed". Undo frees a slot. Sprinkles do not count against the cap. |
| Undo and Clear | Operate within the current tab only. Clear asks nothing and can be undone once. |
| Empty canvas | A dish with no decoration is valid; it is served and saved plain with the serve star. |
| Locked recipe | Selectable for preview only; the primary button becomes "Part of the Full Kitchen". No dead taps. |
| App suspended or killed during a bake or break | End times are stored timestamps plus a local notification. On return the app shows the correct phase (ready, grade or served) with no loss. |
| Device clock changes mid-session | Use a monotonic elapsed time as the source of truth, with the stored end time as the check. **Proposed.** |
| Incoming call or notification while baking on the iPhone | A glance that lasts under 15 s does not end the bake (the ajar grace applies). **Proposed:** a call does not count as ajar. |
| Break ends while a topper is being dragged | The dragged item snaps to where it was last placed and the dish is served. |
| Break length | 5, 8 or 10 min after 25, 50 or 90 min bakes. Optional 50% extra time (accessibility, P1). No extension button. |
| Half-baked | Stars cap at one. Decorating and the recipe book still work. |
| Save failure on serve | Retry silently; if it still fails, keep the dish on screen with a one-line note and a Retry text button. **Proposed.** |
| Long or translated strings | Buttons and tabs may grow to two lines only on Duo; on iPhone, tab labels shorten ("Plate" for "Plate and finish"). Numerals and hero lines never wrap. |

## Accessibility

Every text pair passes 4.5:1. Measured contrast: `color-text` on ground 17.2, `color-muted` 8.2, `color-subtle` 5.4 (4.9 on `color-surface`), `color-sand` 9.7, `color-honey` 11.1, ground ink on the accent button 15.6, caption ink (#2A2623) on the lightest backdrops 6.3 or better.

**Labels and roles**

- Ring clock: image role, label "4:12 left in the break", with ", last 30 seconds" appended in the amber state. The 15 s ajar ring is labelled "11 seconds left".
- Tab bar: tablist with three tabs, `aria-selected` on the active one. Tabs are real links, so they work with Switch Control and keyboards.
- Swatches, plates and backdrops: buttons with a name label ("Rose", "Gilded plate", "Walnut backdrop") and a pressed state. Never colour alone: the selected item also gets a ring.
- Topper tiles: buttons labelled by topper name; the canvas items are labelled the same way and are focusable so they can be moved by actions, not only by drag.
- Caption field: label "Caption for the share card, optional".
- "30 seconds left" note: status role, announced once. Decorative glows, grain, steam and the hinge art are hidden from assistive tech.

**Focus order**

1. Decorate screens: ring clock, Serve now, tab bar (Base, Toppings, Plate and finish), canvas items, tray controls top to bottom, Undo, Clear.
2. Prep: recipe book, settings, recipe circles, temperature, label field, primary button.
3. Duo: top half first, then the door (tray) top to bottom. Nothing focusable sits on the hinge band.

**Motion and input**

- Reduced Motion: stop the ring pulse, ready glow, pill dot pulse, burn-in drift and steam; keep a static amber ring and the 30 second note. The door still changes state, with a cross-fade instead of the swing.
- Tap to place and tap to select replace dragging everywhere; pinch has a stepper alternative (grow, shrink, rotate) in the selected item's actions.
- Every control is at least 44 pt high; adjacent controls have at least 8 pt between them.
- Haptics (proposed; device only, cannot be tested in the simulator): door latch on bake start, tick at 30 s, double tick at 5 s, soft thud on serve. Chimes at 30 s and 5 s are paired with the visual change so neither carries meaning alone.
- Announcements: "Bake started" when committed, "Door ajar, 15 seconds" at start of grace, "Bake ready" on completion, "Served. Three stars" at serve.
- Dynamic Type (**proposed**): helper text, tabs, chips and buttons scale to 130%; numerals, hero lines and ring text stay fixed.

## Assets and implementation notes

The canvas is an HTML prototype. Use it for look, spacing and behaviour; do not port its markup. Production views are SwiftUI per the PRD.

**Art**

| Asset | Source | Production plan |
| --- | --- | --- |
| Cupcake: raw, baked, six frosted variants | Self-rendered 3D stills (800 by 800, transparent) | Reference for a code-drawn SwiftUI cupcake driven by progress and browning. Stills are an acceptable v1 fallback. |
| Wide OTG oven: closed raw, baking, ready; cavity raw, half, done; door open raw, half, done | Self-rendered 3D stills, 1120 by 800 (open: 808 by 832 after crop) | Same: keep the orange rods and lamp glow as a light layer so the rods can brighten with bake progress. |
| Tall oven set (side door) | Self-rendered stills | Backup layout only. |
| Toppers (6), plates (6), backdrops (6) | Placeholder vector and gradient art | Replace with final art; keep the slot and colour contracts below. |
| Fonts | Instrument Sans, Newsreader (both open licence) | Bundle both; fall back to system sans and New York serif. |

**Oven display plate.** On the closed wide oven the plate rectangle is x 80.17%, y 14.58%, width 14.27%, height 12.71% of the image. Plate text is `color-text` Newsreader 300; size = 36% of plate width for up to 3 characters, shrinking so the text uses at most 84% of the plate width. Italic `color-sand` for "Prêt.".

**Canvas geometry.** For a dish drawn in a square of side *d*: the plate is an ellipse 1.2 *d* wide and 0.27 *d* high centred 0.93 *d* below the dish top; an inner well is 72% of the plate in both directions. The dish is centred horizontally and sits 0.08 *d* above vertical centre. Toppers are placed in normalised dish coordinates (x, y from the dish top-left, size as a fraction of *d*).

| Slot | Kind | x | y | Size | Shows in |
| --- | --- | --- | --- | --- | --- |
| 1 | Cherry | 0.50 | 0.15 | 0.17 | Some, full |
| 2 | Star | 0.35 | 0.31 | 0.15 | Full |
| 3 | Pearl | 0.63 | 0.29 | 0.10 | Some, full |
| 4 | Pearl | 0.30 | 0.44 | 0.09 | Full |
| 5 | Pearl | 0.72 | 0.43 | 0.09 | Full |
| 6 | Heart | 0.53 | 0.385 | 0.12 | Full |

These slots only fix the mock-ups. In the app the player places items anywhere on the frosting.

**Decoration data.** Store each dish as an ordered list of operations, not pixels: stroke (colour, points), stamp (kind, x, y, scale, rotation), plate (id), backdrop (id), caption (text, 40 characters). Coordinates are normalised to the dish square. The recipe book and the 1080 by 1350 share card re-render from this list at any size.

**Timing model.** Every phase stores an end timestamp and schedules a local notification. Phases: preheat, bake, ready, reveal, break, served. The 15 s ajar grace is its own timer: if it expires, the bake ends as half-baked, with doneness equal to time baked divided by target time.

**Fold and face-down.** Duo uses the hinge adapter and reserved-region APIs; every other iPhone uses the face-down adapter. A mock adapter plays scripted states for tests. Haptics and thermal behaviour need a real device pass.

## Not designed yet and open questions

**Not designed**

- Stage 3: recipe book, dish detail, share card (1080 by 1350 still, clip), once-only Full Kitchen unlock.
- Stage 4: settings, first-launch door detection, Live Activity, Apple Watch states (baking, ready, break, served).
- Duo portrait Prep and Preheat screens (the Duo core states start at Duo 1, armed).
- Naan, chocolate drip cake, cinnamon roll and dum biryani: only simple placeholder drawings exist; no 3D stills, base options or topping sets.
- Raw, golden and dark bake-state art beyond the cupcake; the dark (overbaked) state is not drawn.
- The Duo landscape set (side-hinged door) is kept as a backup only.

**Open questions**

- Last-30-seconds colour: honey (#E3C07D) as drawn, or stay inside ivory and ink with a thicker pulsing ring? Honey is the only non-ivory interface colour.
- Duo screen sizes: inner 620 by 880 pt portrait and cover 500 by 400 pt are assumptions.
- Does an incoming call or Siri interruption count as ajar? Proposed answer: no.
- Should finishing a break chain into the next bake? The PRD chooses a calm home screen; the saved screen follows that with "Done" as the second button.
- Which plates, backdrops and toppers are free, and which belong to the Full Kitchen unlock?
- Ship 3D stills in v1, or code-draw the dishes first? The PRD prefers code-drawn.
