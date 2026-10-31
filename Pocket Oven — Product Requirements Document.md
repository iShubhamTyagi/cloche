# Pocket Oven — Product Requirements Document

Oct 31, 2026 · @Shubham

## 1. Summary

Pocket Oven is a free-to-start iPhone focus timer where the phone is the oven: prep a bake with the phone open, close it and work while it bakes, then open it to a 5–10 minute decorating break that produces a shareable dish. The fold is the premium experience; a face-down mode makes it work on every iPhone.

**Three ways to play, one app.** Pocket Oven ships as one universal app with three surfaces: the fold edition on the iPhone Duo (the hinge closes the door), the regular-iPhone edition (no hinge needed: place the phone face down), and an Apple Watch companion that shows the bake timer in real time with nothing to tap. Players never pick an edition; the app detects the device, and a Duo owner can still choose face-down play.

**The bet.** Foldable iPhone owners will pay for fold-native apps, and a focus app whose reward is a creative break (not coins) can out-retain the crowded gamified-timer category. Toastie has already shown the close-to-cook mechanic sells; nobody has combined it with a focus loop and a deep collection system.

**Calls this PRD makes that differ from, or sharpen, the brief:**

- **Native SwiftUI, not Unity or a cross-platform tool.** The hinge APIs are SwiftUI/UIKit only, and Claude Code works best with one native codebase (section 11).
- **Running over time never burns the bake.** A focus app must not punish someone for staying in flow, so a finished bake "keeps warm" with no penalty. Only opening early costs you (section 5).
- **Test a lower unlock price first.** Fold-native games sell for $2.99–$4.99 once, so a $20–30 unlock is a 4–8x premium over them; Fold Focus Pro, the nearest focus competitor, costs $29.99 a year. Launch the unlock at a test price of $6.99–$9.99 and treat $20–30 as a later bundle (section 12).
- **Non-Duo play must stand alone.** Few testers will own a $1,999 Duo, so most Gate 1 data will come from face-down mode.
- **Submit after the Gate 1 build, with a limited-territory release,** rather than waiting for a separate soft-launch build.

**Decisions needed from you before build starts:**

- [ ] Do you have an Apple silicon Mac on macOS 26.6 or later (needed for Xcode 27.1), and an Apple Developer Program account ($99 per year)? Both are required. Mac Yes, ADP account not yet
- [ ] Do you have access to a real iPhone Duo for filming and testing? If not, Gate 0 uses the Xcode simulator and must say so. → No
- [ ] Approve the "never burns on overtime" rule and the lower launch price test above. → Yes
- [ ] Approve native SwiftUI as the stack. → Yes

## 2. Problem, opportunity and users

**Problem.** People who want to stay off their phones get gamified timers that run on guilt (a dead tree, a lost coin) and give them nothing to look forward to when the block ends. Foldable iPhone owners, meanwhile, have very few apps that use the fold for something meaningful.

**Opportunity.** The iPhone Duo shipped on October 23, 2026 at $1,999, with a 5.4-inch outer display and a 7.6-inch inner display. Fold-native indie apps got press within days of launch, so the window for a polished entry is open now but short.

**Product principle.** Closed to commit, open to create. Closing the phone is the commitment; opening it is the reward.

**Job stories**

- When I sit down to work, I want to commit to a block of time with a physical action, so I stay off my phone without willpower.
- When a block ends, I want a short creative break that ends by itself, so I return to work refreshed instead of lost in a feed.
- When I make something I like, I want to share it in one tap, so friends see what I made.

**Target users**

| Persona | Who they are | Device | What they want | Role for the business |
| --- | --- | --- | --- | --- |
| Fold early adopter | Tech-curious Duo owner who likes showing off the fold | iPhone Duo | A fold-native app worth filming | Marketing engine: shares clips, drives press |
| Study and work sprinter | Student or remote worker who already uses pomodoro | Any iPhone | A timer that keeps the phone out of reach | Volume: the largest early audience |
| Cozy-game casual | Plays cooking and cozy games, wants guilt-free focus | Any iPhone | A calm routine with a pretty reward | Paying core: buys recipe packs and skins |

The Duo installed base is small (about 6 million units estimated for 2026, from the brief), so the second and third personas decide whether the app survives. Face-down mode is therefore a first-class feature, not a fallback.

**Apple Watch.** The companion matters most to the second and third personas. With the phone face down, a glance at the wrist shows the time remaining, so checking the clock never costs the player the bake.

## 3. Market and competition

The fold-native category is weeks old and thin; the focus-timer category is crowded and shallow. Pocket Oven sits where they overlap, and the gap is content depth plus a reward that is a creation, not a counter.

| Product | What it is | Price | Fold use | What it lacks |
| --- | --- | --- | --- | --- |
| [Toastie](https://www.ithinkdiff.com/toastie-iphone-duo-toaster-game/) | Arcade game: build a grilled cheese, close the phone to toast, open before it burns | $2.99 once, no ads or in-app purchases | Close to cook | No focus timer; short rounds; limited progression |
| [Fold Focus](https://www.ithinkdiff.com/fold-focus-iphone-duo-pomodoro-timer/) | Pomodoro timer that grows a city (sessions of 10–120 minutes); opening early knocks a building down | Free download; Pro at $5.99 per month or $29.99 per year | Closed phone runs the timer on the outer screen; 10-second grace for accidental opens | Guilt mechanic; no creative break |
| Flip-to-focus timers ([Focus Flip](https://apps.apple.com/mx/app/focus-flip-study-timer/id6756534301), [Flipocus](https://apps.apple.com/us/app/flipocus/id6759856814), [Pocket Focus](https://apps.apple.com/app/id6756441200)) | Minimal timer that starts when the phone is face down | Mostly free with in-app purchases | None | No game, no collection, no reason to return |
| Forest, Flora, Focus Friend, Study Bunny | Gamified focus apps with plants and pets | Free to subscription (from the brief) | None | Guilt loops; reward is a counter |
| Bakery Study Timer | Baking-themed study timer | From the brief, not checked | None | Not fold-aware; no decorating |

**Price anchors from other fold-native apps:** [Deck-Man](https://appshunter.io/blog/best-iphone-duo-games.md) at $4.99, Tiny Computers at about $4, ArcFlush at $2.99. No fold-native game yet sells above $5 once, and Fold Focus is priced like software, at $29.99 a year. Both facts matter for section 12.

**Positioning.** For people who want to put the phone down, Pocket Oven turns every focus block into a bake and every break into a short decorating game, so the reward is something you made and can share.

**Defensibility.** The close-to-cook mechanic is easy to copy, and Toastie could add a timer in one update. The durable edges are recipe depth, regional content (Indian dishes first), the decorating game's quality, a collection people want to complete, and a distinct look and sound. Mechanics are not a moat; content and craft are.

## 4. Goals, non-goals and success metrics

The v1 goal is to prove that the close-and-open moment gets attention, that the loop retains people, and that a share-worthy dish brings in new players, in that order and at the lowest possible cost.

**Goals**

1. Make the close and reveal moment feel good enough to film and share.
2. Make the focus-then-decorate loop a daily habit, with no guilt mechanics.
3. Make every finished dish worth sharing in one tap.
4. Reach the App Store fast, with a first build small enough for one person plus Claude Code.

**Two further goals.** Make the regular-iPhone edition as good as the fold edition, because most players will not own a Duo. And let a player read the timer on an Apple Watch without touching anything.

**Non-goals for v1**

- Android, and iPad-specific layouts beyond what the system gives for free. (The Apple Watch companion is in scope; see section 6.)
- Music of any kind, and anything built on book content (copyright).
- Leaderboards, friends feeds, streak loss, energy walls or any other pressure mechanic.
- Subscriptions, user-made recipes, multiplayer.
- Other crafts such as coffee or pottery. They come after the engine proves itself.

**Success metrics.** Bars for the three gates come from the brief; rows marked *proposed* are my additions.

| Gate | Window | What must be true | Bar |
| --- | --- | --- | --- |
| 0: close and reveal clip | 1 week | A clip of only the close and reveal moment gets attention | A clip passes about 50,000 views, or 500 waitlist sign-ups |
| 1: playable loop | 4–6 weeks | About 5 dishes, about 20 testers | Day 1 ≥ 35%, day 7 ≥ 15%, day 30 ≥ 5% retention |
| 1 guardrail (*proposed*) | 4–6 weeks | Players finish what they start | At least 70% of bakes complete without opening early |
| 2: soft launch | After submission | People pay and share | ≥ 2% of installs pay, ≥ 5% share a dish |

**Read Gate 1 as directional.** With 20 testers, one person is 5 percentage points: day 1 at 35% means 7 people, day 7 at 15% means 3, day 30 at 5% means 1. Recruit 30 or more if you can, and read session counts per tester alongside the percentages. Most testers will not own a Duo, so Gate 1 mostly measures face-down mode.

**Read each edition separately.** Tag every event with its door source (hinge, face-down, covered or honor) and whether a Watch was paired, and report the gate bars for regular-iPhone players on their own. Proposed guardrail for the regular edition: fewer than 5% of bakes should end early within 20 seconds of starting, since that pattern points to false face-down detection.

**Waitlist for Gate 0.** Counting sign-ups needs a landing page with an email form before the clip goes out. Put the page link in every post.

## 5. Core experience and user flows

One session is five steps, and the player controls only the first. Everything after "close the phone" runs on timers so the break can never grow into a distraction.

1. **Prep (phone open).** Pick a recipe (which sets the session length: 25, 50 or 90 minutes) and an oven temperature of low, medium or high. Each recipe has one ideal temperature, learned over time. Optionally type a one-line label for what you are working on; it stays on the device. Tap Preheat.
2. **Bake and work (phone closed or face down).** The timer starts when the phone closes (Duo) or lies face down (other iPhones). The outer screen shows the oven door, a glow and the countdown. Nothing on it asks for a tap.
3. **Reveal (phone opened).** When the bake is finished, opening the phone swings the oven door open. A grade card shows doneness and browning and awards one to three stars.
4. **Break and decorate (5–10 minutes).** A timer-bound decorating game (section 8). It ends by itself.
5. **Collect and share.** The finished dish goes into the recipe book. One tap exports a still image or a short clip.

**What happens to the bake**

| Situation | Result |
| --- | --- |
| Closed for the full time, opened at any later point | Fully baked. It keeps warm with no penalty, however long you keep working. |
| Opened early, then closed again within 15 seconds | Nothing happens (accidental-open grace). |
| Opened early and left open | The bake ends as half-baked. Doneness equals time baked divided by target time; stars are capped at one. |
| Temperature differs from the recipe's ideal | Browning is pale (too low) or dark (too high); stars drop by one. No effect on doneness. |
| Phone sleeps, a call comes in, or the app is force-quit | The bake continues. The timer is stored as an end timestamp, never counted by ticking, and recovers on relaunch. |
| Bake finishes while you are away | A local notification and the outer-screen glow tell you it is ready. |

**Design rules that follow from the brief**

- **No guilt.** Nothing is lost, reset or shamed. A half-baked dish is still decorated and still lands in the recipe book, just with fewer stars.
- **Skill is knowledge, not reflexes.** The only decision is recipe and temperature, so you never need to look at the phone during a bake.
- **The break belongs to the bake.** There is no way to start the decorating game without finishing, or abandoning, a bake.

## 6. Editions: fold, regular iPhone and Apple Watch

One question drives the bake, "is the door closed?", and one component answers it: a `FoldStateService` that reads the hinge on the Duo and the phone's orientation everywhere else. The rest of the app never asks which device it is on.

**How the Duo's states are detected (open question 2).** On iOS 27.1 and Xcode 27.1, SwiftUI's `onHingeChange` reports a hinge context with a discrete status (`.closed`, `.partiallyOpen`, `.fullyOpen`) and a continuous angle; UIKit has the equivalent `UIHingeInteraction`. On iPhones without a hinge the context's `hinge` is `nil`, so one code path handles both. UIKit adds an unknown status; treat it as fully open. Apple advises using the hinge APIs only where the folding motion itself matters, and here it is the whole feature.

| Hinge status | Door state in the game | During a bake |
| --- | --- | --- |
| `.closed` | Closed | Timer runs |
| `.partiallyOpen` | Ajar | Starts the 15-second grace; if still ajar at 15 seconds, the bake ends early |
| `.fullyOpen` | Open | Ends the bake early (after grace) or triggers the reveal if the bake is finished |
| unknown or `nil` hinge | Open, then fall back to face-down detection | Same as above |

A phone propped half-open on a desk counts as ajar, never closed, so the player cannot cheat the timer by leaving it in a tent shape.

&#91;embedded content: bake states · closing starts it, opening early ends it\]

A bake runs only while the door is closed; a door left ajar for more than 15 seconds ends it as half-baked, and a finished bake waits as ready until the player opens the phone.

**Three implementations behind one protocol:** a hinge adapter, a face-down adapter, and a mock that can play back a scripted sequence of states. The mock matters because the Xcode simulator can open, close and fold a virtual Duo, but its posture is switched by hand in Device Hub and is not scriptable, so automated tests need the mock. The simulator also cannot reproduce haptics, camera transitions or thermal behavior, so a real-device pass is required before submission.

**Outer display.** While the phone is closed, the bake screen must keep running on the 5.4-inch outer display. Fold Focus does this, so it is possible; confirm it in Gate 0 on the simulator and on a real device.

**Layout on the inner display (7.6 inch).** Use the reserved-region and arrangement APIs to keep tools and text off the hinge and cameras, and let the decorating canvas use the full space. Use hinge angle only for effects, such as the door swinging with the fold, not for layout.

**Without a Duo (open question 5).** Face-down is the equivalent action, and the rest of the experience is the same.

| Moment | iPhone Duo | Any other iPhone |
| --- | --- | --- |
| Commit | Close the phone | Place the phone face down |
| While baking | Oven door on the outer screen | Dim, full-screen oven glow; auto-lock disabled during the bake |
| Reveal | Unfold: the door swings with the hinge | Flip the phone up: the door swings on a timed animation |
| Early open | Hinge leaves closed | Phone leaves face-down |
| Decorating | Large canvas, tools in a vertical bar | Standard canvas, tools in a bottom tray |
| Sharing | Same | Same |

Face-down detection (device orientation or accelerometer) and whether the app can stay active with the screen dimmed must be proven in Gate 0. If the app is suspended, the stored end timestamp and a local notification still deliver a correct result; only the glow is lost.

### Regular iPhone edition (no hinge)

**One app, chosen automatically.** At launch the app asks the system whether a hinge exists (it is `nil` on every other iPhone) and picks the door mode. Nobody downloads a second app, pays twice or sees a second App Store listing. A setting lets Duo owners choose face-down play too, for example when the phone is on a desk and the fold is awkward.

| Door mode | How the door closes | Best for | Default |
| --- | --- | --- | --- |
| Hinge | Close the phone | iPhone Duo | Yes on a Duo |
| Face-down | Phone lies screen-down on a flat surface | Desk or table | Yes on every other iPhone |
| Covered | Phone in a pocket, a bag or under a folio case, read by the proximity sensor | Commutes and meetings | Option |
| Honor door | Drag the on-screen oven door shut; dragging it open ends the bake | No flat surface; accessibility | Option, never the default |

**What changes in the design on a regular iPhone**

- **The hero moment moves from the fold to the flip.** Turning the phone face up plays the door swing with a haptic thunk, timed so it feels like opening an oven.
- **The bake screen matters before and after the bake, not during it.** A face-down screen is never seen, so the player is told through the Apple Watch, a soft end chime and a notification instead of a glow.
- **Keep screen awake while baking** is on by default and shows a black screen with a faint ember line, so the ajar grace and detection keep working. If a player turns it off, the stored end timestamp and the notification still produce a correct result.
- **Early open** works as on the Duo: flipping the phone up is the door ajar, with the same 15-second grace, so reading one message does not ruin a bake.
- **Unreliable surfaces** (a tilted book, a soft sofa) can make face-down detection flicker. Detection requires the phone to be flat, and repeated flicker offers the honor door.
- **Demo bake.** A 15-second bake in Settings, labelled and earning no stars, so App Review and testers can see the whole loop without a Duo or a 25-minute wait.
- **One listing.** App Store screenshots lead with regular-iPhone screens; Duo screenshots are included from the first submission.

Whether the app stays active with the screen dimmed (face-down) and whether the proximity sensor keeps it running (covered) must be proven in Gate 0. If covered mode cannot keep the app active, it is dropped and face-down plus the honor door remain.

### Apple Watch companion

The watch is a quiet second window on the timer, not a second game: it shows what remains and nothing else, so a glance at the wrist replaces opening the door.

**Principles.** Read-only in v1, with no buttons during a bake. One number on screen. No animation except a slow ember pulse that stops in Always-On. One gentle tap when the bake is ready, and nothing else buzzes.

| State | The watch shows | Haptic |
| --- | --- | --- |
| Idle | Nothing; the Smart Stack stays empty | None |
| Baking | Time remaining in serif numerals inside a thin ember arch that fills with progress; recipe name in small capitals below | None |
| Ready | "Prêt" in italic over a still gold ring | One soft tap |
| Break | Break time remaining; ring turns copper in the last 30 seconds | None |
| Served | "Bon appétit" and the stars for five seconds, then clears | None |
| Always-On | Dim gold numerals on black, no animation | None |

**Look.** Oven-black background, ember and gold, New York serif numerals, one-point lines, sized for the 41, 45 and 49 mm cases. The same palette and voice as the phone, with far fewer elements.

**How it works, in two layers**

1. **Layer A: the iPhone Live Activity, mirrored (P1).** On iOS 18 and watchOS 11, an iPhone Live Activity appears in the Watch Smart Stack automatically, even with no Watch app installed, and updates sync automatically within a budget. Add a Watch-specific compact view and an Always-On variant. This alone delivers a real-time countdown on the wrist. It only works while the watch is paired and connected.
2. **Layer B: a native watchOS app and complication (P2).** It adds the ready, break and served screens, the haptic and a complication. The phone sends the phase, recipe and end timestamp once per change, and the watch counts down on its own with a self-updating timer, so nothing ticks over Bluetooth and battery use stays low.

Ship Layer A with the Gate 1 build. Build Layer B only if the data shows Watch owners among the testers.

**Limits in v1.** The watch cannot start, stop or open a bake and does not detect the door. If the phone and watch disconnect, Layer A may lag; Layer B keeps counting from the stored end timestamp.

## 7. Functional requirements

Priorities: **P0** is in the Gate 1 build, **P1** is in the launch build, **P2** is after launch. Everything here is offline-first with no account.

**Prep**

| ID | Requirement | Pri |
| --- | --- | --- |
| PR-1 | Recipe picker with dish art, session length and locked state | P0 |
| PR-2 | Temperature selector (low, medium, high) with a hint after the first bake of a recipe | P0 |
| PR-3 | Preheat button that arms the oven and prompts "Close the phone" | P0 |
| PR-4 | Optional one-line "working on" label, stored on device | P1 |
| PR-5 | Custom session length (15–120 minutes in 5-minute steps) for unlocked recipes | P2 |

**Bake**

| ID | Requirement | Pri |
| --- | --- | --- |
| BK-1 | Timer based on a stored end timestamp; survives sleep, calls and force-quit | P0 |
| BK-2 | Closed-state detection through `FoldStateService` | P0 |
| BK-3 | Oven-door bake screen with glow, countdown and a dish that rises with progress; subtle motion only, safe for OLED | P0 |
| BK-4 | 15-second door-ajar grace | P0 |
| BK-5 | Early open ends the bake as half-baked | P0 |
| BK-6 | Ready notification and glow; keep-warm with no penalty | P0 |
| BK-7 | Oven hum and timer ding, mutable, respecting the silent switch | P0 |
| BK-8 | Live Activity on the lock screen and the Apple Watch Smart Stack showing time remaining | P1 |

**Reveal and grade**

| ID | Requirement | Pri |
| --- | --- | --- |
| RV-1 | Door-swing animation tied to unfold or flip-up, with steam and a haptic thunk | P0 |
| RV-2 | Grade card with doneness, browning and one to three stars | P0 |
| RV-3 | "Serve plain" option that skips the break | P0 |

**Decorate** (full spec in section 8)

| ID | Requirement | Pri |
| --- | --- | --- |
| DC-1 | Three-stage decorating game with a visible break clock | P0 |
| DC-2 | Auto-serve at break end; locks the dish and saves it | P0 |
| DC-3 | Undo and clear within a stage | P0 |
| DC-4 | Per-dish tool sets and toppings that unlock through play | P1 |

**Recipe book**

| ID | Requirement | Pri |
| --- | --- | --- |
| CL-1 | Grid of dishes with silhouettes for ones not yet baked | P0 |
| CL-2 | Each entry stores grade, decoration snapshot, date and label | P0 |
| CL-3 | Completion percentage per recipe pack | P1 |
| CL-4 | Variants unlocked by repeat bakes (for example a golden-crust version) | P1 |
| CL-5 | iCloud sync of the book | P2 |

**Share**

| ID | Requirement | Pri |
| --- | --- | --- |
| SH-1 | Still-image share card (1080 by 1350) with dish, stars and bake time | P0 |
| SH-2 | Share sheet with no account or sign-in | P0 |
| SH-3 | Six-to-ten-second vertical clip of the decorating time-lapse and reveal | P1 |

**Platform, accessibility and data**

| ID | Requirement | Pri |
| --- | --- | --- |
| PL-1 | `FoldStateService` with hinge, face-down and mock implementations | P0 |
| PL-2 | Layouts for Duo inner and outer displays; nothing placed across the hinge | P0 |
| PL-3 | Dynamic Type, VoiceOver labels, Reduce Motion alternative for the door swing, no color-only signals | P1 |
| PL-4 | Works fully offline with no account | P0 |
| PL-5 | English first; all strings externalized so Hindi can ship in a point release | P1 |
| AN-1 | Privacy-light event log (session started, bake completed, opened early, break completed, share tapped, purchase). No ad tracking, so no tracking prompt | P0 |

**Purchases**

| ID | Requirement | Pri |
| --- | --- | --- |
| MO-1 | One-time unlock through StoreKit 2, with Restore Purchases | P1 |
| MO-2 | Regional recipe packs and cosmetic oven skins | P1 |
| MO-3 | Rewarded ads | P2, and only if testing shows they do not hurt retention |

**Regular iPhone edition**

| ID | Requirement | Pri |
| --- | --- | --- |
| DR-1 | Door mode chosen automatically: hinge if present, otherwise face-down | P0 |
| DR-2 | Face-down detection with the 15-second ajar grace | P0 |
| DR-3 | "Keep screen awake while baking" setting, on by default, with a black screen and a faint ember line | P0 |
| DR-4 | Ready notification and a soft end chime that respects the silent switch | P0 |
| DR-5 | Flip-up reveal: door swing and haptic thunk when the phone turns face up | P0 |
| DR-6 | Demo bake of 15 seconds in Settings, labelled and earning no stars | P0 |
| DR-7 | Door source (hinge, face-down, covered, honor) tagged on every analytics event | P0 |
| DR-8 | Setting to choose the door mode manually, so Duo owners can pick face-down | P1 |
| DR-9 | Covered mode using the proximity sensor, if Gate 0 shows the app stays active | P1 |
| DR-10 | Honor door: drag-to-close screen with no sensor | P1 |

**Apple Watch**

| ID | Requirement | Pri |
| --- | --- | --- |
| WT-1 | Live Activity with a Watch-specific compact view and an Always-On variant (see BK-8) | P1 |
| WT-2 | One gentle haptic when a bake is ready; no other haptics | P1 |
| WT-3 | No controls on the watch in v1 | P1 |
| WT-4 | Native watchOS app with baking, ready, break and served screens | P2 |
| WT-5 | Smart Stack widget and complication showing time remaining | P2 |
| WT-6 | Watch counts down locally from a stored end timestamp; the phone sends state once per change | P2 |
| WT-7 | Reduce Motion and Always-On luminance respected | P2 |

## 8. Decorating mini-game

The decorating game is one canvas, three tool tabs and one clock. It has no score, no fail state and no extension, which is what lets it end cleanly (open question 4). Working name: Finishing Table.

**Break length.** 5 minutes after a 25-minute bake, 8 after a 50-minute bake, 10 after a 90-minute bake.

**The three tabs** (the player can move between them freely)

1. **Base.** Spread, pipe or pour the dish's main finish with one finger: frosting on a cupcake, butter and garlic on naan, ganache on a cake, saffron milk on biryani. Two to three colors or variants per dish.
2. **Toppings.** Drag items from a tray onto the dish; tap to place, pinch to scale and rotate, up to 12 items. Sprinkles and herbs are scattered by holding a finger down.
3. **Plate and finish.** Choose a plate and a backdrop, and add an optional one-line caption that appears on the share card.

**How it ends cleanly**

- A ring clock stays visible. At 30 seconds it turns amber and a soft chime plays; at 5 seconds a second chime plays.
- At zero the tools fade, the dish slides onto the table, a flash snaps the share card, and the dish is saved. This happens even if the app is in the background, because the clock uses a stored end time.
- There is no extension, no "one more minute", and the canvas cannot be reopened after serving.
- The next screen offers exactly two buttons: **Bake again** (which asks you to close the phone) and **Done**. No interstitials and no ads.
- **Serve now** is always available. Serving early skips the rest of the break; it earns nothing extra and loses nothing.
- Decorating cannot be started without a bake, so it never becomes a standalone toy.

**Technical shape.** Store the decoration as an ordered list of operations (stroke, stamp with position, scale and rotation, plate, backdrop), not as pixels. That makes the saved dish tiny, lets the recipe book re-render it at any size, and lets the share clip replay the whole decoration as a time-lapse.

**Accessibility.** Tap-to-place replaces dragging everywhere; a setting adds 50% more break time for players who need it (P1).

**Acceptance test for Gate 1.** A first-time tester makes a recognizable decorated cupcake in under three minutes with no instructions, and 8 of 10 testers say they would show it to someone.

## 9. Content: the first five dishes

Five dishes cover three session lengths, one celebration classic and two Indian dishes, so the Gate 1 build shows the content engine and the regional difference at once (open question 3).

| # | Dish | Session | Why it is in | Decorating hooks |
| --- | --- | --- | --- | --- |
| 1 | Vanilla cupcakes | 25 min | Universal, instantly readable, easy to draw | Piped frosting swirls, sprinkles, toppers |
| 2 | Garlic butter naan | 25 min | Puts the Indian differentiator in the free tier | Char blisters, butter brush, garlic, coriander, chutney bowls |
| 3 | Chocolate drip cake | 50 min | The celebration classic that gets shared | Ganache drip, berries, candles |
| 4 | Cinnamon rolls | 50 min | Cozy and satisfying to frost | Icing spiral, glaze, sugar |
| 5 | Dum biryani | 90 min | The pot is sealed with a dough lid, so "closed to commit" is literal | Fried onions, saffron milk, mint, egg, raita |

A plain 90-minute bread, as in the brief, is the sixth dish if time allows. Later packs: Indian classics (nankhatai, kulcha, pav), everyday bakes, festive bakes.

**Recipe data (one record per dish).** Name, region, pack, session minutes, ideal temperature, four bake-state images (raw, half-baked, golden, dark), base options, topping set, unlock rule. A new dish is data plus art; no new code.

**Stars (1 to 3).**

- Bake star: the bake ran to completion.
- Temperature star: the chosen temperature matched the recipe, so browning is golden.
- Serve star: the dish was decorated and served.

A half-baked dish earns neither the bake star nor the temperature star, so it tops out at one star. Skipping the break forfeits the serve star only. Nothing is ever taken away.

**Art needed for the five dishes (estimate).** About 17 images per dish (4 bake states, 3 base options, about 10 toppings), plus shared pieces: oven door and glow, 6 plates, 6 backdrops, UI icons. That is roughly 110 images for Gate 1, which section 10 sizes against the pipeline.

## 10. Art and sound pipeline

For v1, draw the art as layered vector shapes in SwiftUI and record the sounds yourself. That costs almost nothing, keeps one style across about 110 assets, and looks nothing like Toastie. Budget figures below are my estimates, not quotes.

| Art option | Cost (estimate) | Consistency | Verdict |
| --- | --- | --- | --- |
| Vector shapes drawn in code, iterated with Claude Code | $0 plus time | High: one palette and shape grammar | **Use for v1** |
| Commissioned illustrator for the oven and five hero dishes | Get 2–3 quotes; plan on hundreds of dollars | High if one artist | Use if the Gate 0 clip shows the code-drawn look is too flat |
| AI-generated raster images | Low | Low across a full set; license terms and App Store disclosure vary by tool | Mood boards only |
| CC0 packs (for example UI icons) | $0 | Medium | Fine for icons and some sounds after checking each license |

The one fixed cost is the Apple Developer Program at $99 per year.

**Why code-drawn art fits.** Each dish becomes a SwiftUI view with parameters for bake progress and browning, so the bake animates smoothly instead of swapping four pictures; the four preset states in section 9 are just four parameter values. Toppings are small reusable shapes. The same drawing renders at any size, including the Duo's 7.6-inch display and the share card.

**Style guide.** Warm palette of about eight colors, rounded shapes, a faint paper grain, six to ten layered shapes per dish. Do not copy Toastie's name, color palette or character styling; compare screenshots side by side before each release.

**Sound.** About 15–20 effects, all original: oven door clunk, oven hum (loop), timer ding, sizzle, pop, frosting squish, sprinkle, two countdown chimes, serve whoosh, camera flash. Record them with the phone (a real door latch, a spoon in a bowl, a kettle), edit in Audacity or GarageBand, and export as short WAV or CAF files. Haptics use Core Haptics: a thunk for the door and a light tick for placing a topping.

**No music, by design.** The game has an ambient oven hum and effects only. That removes music licensing entirely and suits a focus app.

**Copyright rules.**

- No songs, no book content, no brand names or logos on packaging, no characters from existing IP.
- Dish names and recipes are generic and fine. Have someone who cooks the Indian dishes review the art for accuracy.
- Keep a `LICENSES.md` file listing the source and license of every sound and image that is not original.

## 11. Tech stack and architecture

Use native Swift 6 and SwiftUI (open question 1). The hinge APIs this product depends on are SwiftUI and UIKit APIs, the app is a mostly 2D, touch-and-timer game that SwiftUI handles well, and one native codebase is the simplest thing for Claude Code to build and fix.

| Criterion | Native SwiftUI | Unity | Flutter or React Native |
| --- | --- | --- | --- |
| Hinge and reserved-region APIs | Direct | Needs a native plugin | Needs a native plugin |
| First-time mobile developer | One toolchain (Xcode) | Two toolchains plus bridging | Two toolchains plus bridging |
| Fit for a timer plus a 2D decorating game | Good: Canvas, animations, haptics | Good for games, heavy for a timer app | Fair |
| Claude Code workflow | Builds and tests from the terminal with `xcodebuild` | Editor-driven, harder to automate | Good, but the fold layer is native anyway |
| Android later | Rewrite the UI; recipe data is shared JSON | Strongest reuse | Strong reuse |
| App size and polish | Smallest, most native feel | Larger | Medium |

Android is not a v1 goal, so its reuse advantage does not justify the bridging cost. If the decorating canvas ever outgrows SwiftUI's Canvas, embed SpriteKit in that one screen.

**Components**

| Component | Responsibility | Built with |
| --- | --- | --- |
| Session engine | The state machine for prep, bake, reveal, break and serve; stored end timestamps | Plain Swift, `@Observable` |
| `FoldStateService` | One "door closed?" signal from three implementations | `onHingeChange`, device orientation, mock |
| Recipe store | Recipes as bundled JSON | `Codable` |
| Recipe book | Saved dishes with decoration operations | SwiftData |
| Decorating canvas | Strokes and stamps rendered from operations | SwiftUI Canvas |
| Share | Still card and time-lapse clip | `ImageRenderer`, AVFoundation |
| Feedback | Sounds, haptics, ready notification | AVFoundation, Core Haptics, local notifications |
| Purchases | Unlock, packs, skins | StoreKit 2 |

No third-party dependencies and no server in v1. Local notifications need no push entitlement, so signing stays simple.

**Targets.** One Xcode project with up to three targets: the iPhone app, a widget extension for the Live Activity, and later a watchOS app. Theme, recipe data and the phase model live in a shared folder used by every target. `FoldStateService` gains two more implementations beyond hinge and mock: face-down and covered (proximity), plus the honor door as a non-sensor input. The iOS 18 minimum also matches what Live Activity mirroring to the Watch needs (iOS 18 and watchOS 11).

**Deployment target (proposal).** Build with the Xcode 27.1 SDK, set the minimum iOS version to 18 so non-Duo iPhones are included (Fold Focus also supports iOS 18), and gate the hinge adapter behind `#available(iOS 27.1, *)`. Raise the minimum if the SDK forces it.

**Working with Claude Code as a first-time mobile developer**

- Put a `CLAUDE.md` in the repo: SwiftUI only, no third-party packages, every change must build with `xcodebuild` and pass unit tests, use the mock fold service in tests.
- Build vertical slices, one per prompt: prep screen, then bake timer, then reveal, and so on. Commit after each.
- Let Xcode manage signing automatically. When Xcode shows a signing or entitlement error, paste it to Claude Code verbatim.
- Xcode 27.1 adds an agent skill for resizable layouts; run it before submission.
- Use the simulator for layout and logic, TestFlight on real devices for sound, haptics and heat.

## 12. Monetization and revenue model

Free to start, one-time unlock, optional cosmetics and packs, no pressure mechanics. The open question is the unlock price: the brief's $20–30 is 4–8 times what fold-native games charge once, although close to a year of Fold Focus Pro ($29.99), so v1 should test a lower price before committing to it.

**Structure (prices are proposals to test)**

| Tier | What it includes | Price |
| --- | --- | --- |
| Free | Cupcakes and naan, base toppings, still-image sharing, full bake loop | $0 |
| Full Kitchen unlock | All dishes in the core set, all toppings and plates, clip export, future core dishes | Test $6.99–$9.99 first |
| Regional packs | For example Indian classics: nankhatai, kulcha, pav | About $2.99 each |
| Oven skins | Cosmetic only | About $0.99–$1.99 |
| Complete Collection bundle | Unlock plus all packs, offered once there are 20 or more dishes | $20–30 (the brief's range) |

**Rules.** No energy, no timers you can pay to skip, no streak loss, no paywall during a bake or a break. Show the unlock once, after the player's first fully baked and shared dish. Rewarded ads stay out of v1; an ad in a focus app works against the promise, and they can be tested later as an opt-in way to try a locked dish.

**Editions and price.** There is one app and one price. The regular-iPhone edition and the Apple Watch companion are part of the free tier and the unlock, never a separate purchase or an upsell.

**Revenue sensitivity.** Net first-year revenue at 50,000 installs, after an assumed 15% Apple commission (the small-business rate), for three prices and three paying rates. Multiply by 5 for 250,000 installs.

| Unlock price | 1% pay | 2% pay | 4% pay |
| --- | --- | --- | --- |
| $4.99 | $2,121 | $4,242 | $8,483 |
| $9.99 | $4,246 | $8,492 | $16,983 |
| $24.99 | $10,621 | $21,242 | $42,483 |

Your base case ($19K at 50,000 installs and $94K at 250,000) works out to about $0.38 per install, which is roughly a $22 unlock at 2% paying. The gate bar of 2% paying is only realistic at that price if the audience is willing to pay 4–8 times what fold-native games charge. Nobody knows that yet, so the soft launch should change the price at fixed intervals and compare conversion, treating the result as directional because seasonality muddies it.

**Cost to run in year one:** the $99 developer program, any commissioned art, and your time. There is no server cost.

## 13. Release plan and gates

Three gates, each cheap enough to fail early, with submission folded into the end of Gate 1 so you reach the App Store as soon as the loop works. The schedule assumes a start on Monday, November 2, 2026 and is a proposal, not a forecast.

&#91;embedded content: release roadmap · 3 gates, bars marked\]

A weak result at any gate stops or reshapes the work before the next, costlier phase begins.

**Two schedule facts to plan around**

- **Day-30 retention needs 30 days of data.** The playable loop must be in testers' hands by about the end of week 3 of the plan, or the Gate 1 window closes before day 30 can be read.
- **The screenshot deadline is soft for you.** Apple has said that from April 2027 any app or game submitted must include iPhone Duo screenshots, so shipping before then does not need them, but add them from the first submission anyway because they are the fold-native shop window.

**Gate 0 prototype: the smallest thing that shows the moment (open question 2)**

1. Prep screen with one hard-coded cupcake and a Preheat button.
2. Bake screen: oven door, glow and countdown. Use a 15-second demo timer for filming and a real 25-minute timer for testing.
3. `FoldStateService` with hinge and face-down implementations, plus an on-screen debug readout of hinge status and angle, so you learn how the Duo reports a half-open posture before building more.
4. Reveal: door swing, steam, a haptic thunk and a grade card with browning and doneness.

No decorating, no recipe book, no saving, no purchases.

**Facts this prototype must settle**

- Does the bake screen keep running on the outer display while the phone is closed?
- What does the hinge report during a slow close and a slow open?
- Does face-down mode keep the app alive on a normal iPhone, or do you rely on the end timestamp and notification?
- Does the timer stay correct through lock, a call and force-quit?

**Filming.** Three vertical clips of 8–12 seconds with sound: close the phone, open it early for a half-baked result, and the full reveal. Put the visual hook in the first two seconds, add a waitlist link, and judge the result seven days after posting. If you do not have a Duo, record the simulator and say so in the caption; real-device footage is required before Gate 2. If the first clip falls short, try two more edits before deciding.

**App Store submission checklist**

- [ ] Apple Developer Program enrolled; app record created in App Store Connect.
- [ ] Built with Xcode 27.1 or later.
- [ ] Screenshots for the standard iPhone sizes, plus Duo screenshots for both displays (reported sizes: 1398 by 2034 for the outer screen and 2007 by 2853 for the inner screen, portrait). Capture them from the simulator or a device, and check the sizes in App Store Connect.
- [ ] Privacy policy URL and support URL; privacy label answers (no tracking).
- [ ] Age rating questionnaire; choose the primary category (Productivity or Games) deliberately.
- [ ] In-app purchases created and submitted with the build.
- [ ] Review notes that explain fold behavior and give a reviewer without a Duo a working path through face-down mode.
- [ ] Availability limited to the soft-launch countries.
- [ ] `LICENSES.md` complete; no music; no brand marks.

**Soft launch (Gate 2).** Release in a handful of English-speaking markets plus India, track the paying and sharing rates against the bars in section 4, run the price change from section 12, and decide at the end whether to widen, hold or stop.

**Editions across the gates.** Gate 0 proves both door sources, hinge on the simulator and face-down on a real iPhone, and the clips should show both. Gate 1 ships the regular-iPhone edition complete (every DR row marked P0) because most testers will not own a Duo, plus the Live Activity mirror to the Watch. The native Watch app waits until Gate 1 data says it matters. If a watchOS app is in the build, add Apple Watch screenshots to the submission (confirm the requirement in App Store Connect). **Enroll in the Apple Developer Program today:** TestFlight and submission both need a paid account, and enrollment can take time.

## 14. Risks, assumptions and open questions

The biggest risks are a small fold audience and a copyable mechanic. Both are answered by the same strategy: make the non-fold experience good, and win on content and craft. Likelihood and impact are my judgment.

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Toastie or Fold Focus adds a timer or more depth | High | High | Move fast; compete on dish depth, regional recipes and the decorating game; read their update notes monthly |
| The mechanic is easy to copy | High | Medium | Treat content, craft and the collection as the moat; ship packs on one engine |
| Few Duo owners (about 6 million units estimated for 2026, from the brief) | High | High | Face-down mode is first-class; use Duo clips for marketing and non-Duo players for volume |
| Art or sound falls below the bar | Medium | High | Gate 0 judges the look; commission hero art if needed; record original effects |
| A first-time mobile build stalls on signing, review or scope | Medium | Medium | Vertical slices, `CLAUDE.md`, automatic signing, strict P0 scope |
| App is suspended or dimmed while face down, or the timer drifts | Medium | High | End-timestamp timer plus a local notification; settle it in Gate 0 |
| Static glow on an OLED for 90 minutes causes burn-in worries, heat or battery drain | Medium | Medium | Subtle motion, low brightness, real-device soak test |
| A $20–30 unlock converts poorly | Medium | High | Launch the unlock at a lower test price; keep the high price for a bundle |
| Novelty fades after the first few bakes | High | Medium | Collection goals, variants, packs; day-7 gate |
| App Review cannot test fold behavior | Low | Medium | Working face-down path and clear review notes |
| Look-alike or trade-dress complaint | Low | High | Original art and sound; side-by-side check against Toastie; `LICENSES.md` |
| Gate 0 clip performance is mostly luck | High | Medium | Try three edits; count waitlist sign-ups as well as views |
| New iOS 27.1 fold APIs behave unexpectedly | Medium | Medium | Mock service, pinned Xcode version, real-device pass |

**New risks from the regular edition and the Watch**

- **Face-down detection fails on a tilted or soft surface.** Require a flat reading, offer the honor door, and test three surfaces in Gate 0.
- **The app is suspended while face down with auto-lock on.** The timer stays correct because it is an end timestamp, but detection pauses; keep-awake is on by default for this reason.
- **The proximity sensor may not keep the app active.** Prove it in Gate 0 or drop covered mode.
- **The Live Activity on the Watch depends on pairing and an update budget, so it can lag.** Promise a glance, not second-exact timing, until Layer B exists.
- **Two editions double the test surface.** Keep one code path through `FoldStateService`, test with the mock, and run a matrix of Duo simulator, regular iPhone and Watch simulator.
- **Developer Program enrollment lag.** The account is not enrolled yet; enrollment blocks TestFlight.

**Assumptions to confirm**

- You have an Apple silicon Mac on macOS 26.6 or later for Xcode 27.1, and can enroll in the Apple Developer Program.
- The Bakery Study Timer details, the descriptions of Forest, Flora, Focus Friend and Study Bunny, and the 6-million Duo estimate come from your brief; I did not verify them.
- The 15% Apple commission applies (the small-business rate).
- The schedule starts on November 2, 2026 and you can give the project roughly one focused week for Gate 0.
- The app name "Pocket Oven" is a working title; I have not checked App Store or trademark availability.

**Open questions that remain**

- [ ] Is Pocket Oven available as an app name and as a domain for the waitlist page?
- [ ] Productivity or Games as the primary App Store category? Worth testing the listing both ways if time allows.
- [ ] Should finishing a break automatically chain into the next bake, or always return to a calm home screen? This PRD chooses the calm home screen.
- [ ] When should Hindi and other localizations ship, given the Indian-dish positioning?
- [ ] Does Toastie's iCloud recipe sync (reported in its October 11 release notes) change the expectation for syncing the recipe book earlier than P2?

* [ ] Should demo bakes exist in the shipped app or only in TestFlight builds? This PRD keeps them in Settings, labelled and star-free.
* [ ] Should the Watch ever be able to start a bake? v1 says no, to keep it distraction-free.

## Sources

Pages opened and read on October 31, 2026:

- [Toastie makes the iPhone Duo the world's most expensive toaster](https://www.ithinkdiff.com/toastie-iphone-duo-toaster-game/): $2.99, no ads or in-app purchases, Duo mode on October 23.
- [Fold Focus builds a city while you keep the iPhone Duo closed](https://www.ithinkdiff.com/fold-focus-iphone-duo-pomodoro-timer/): mechanic, 10-second grace, outer-screen countdown, Pro pricing, iOS 18 minimum.
- [Apple opens App Store submissions for iPhone Duo optimized apps and games](https://www.ithinkdiff.com/apple-opens-app-store-submissions-for-iphone-duo-optimized-apps-and-games/): April 2027 screenshot requirement, $1,999 price, October 23 release.
- [iPhone Duo with Xcode 27.1: the 6 foldable APIs](https://slekens.dev/en/blog/iphone-duo-xcode-27-1-six-foldable-apis/): hinge API names, status values, angle, Xcode 27.1 and macOS requirement.

* [Bring your Live Activity to Apple Watch (WWDC24)](https://developer.apple.com/wwdc24/10068?time=215): Live Activities appear in the Watch Smart Stack automatically on iOS 18 and watchOS 11, work without a Watch app, and sync within a budget (opened October 31, 2026). The face-down, proximity-sensor and local-timer points in section 6 are my engineering judgment and are checked in Gate 0, not sourced.

Taken from search results without opening the page: the simulator posture and Device Hub limits (a GitHub design issue), the Duo screenshot sizes (press reports), the 5.4-inch and 7.6-inch display sizes, Toastie's iCloud sync (an App Store listing summary), the Deck-Man, Tiny Computers and ArcFlush prices, and the flip-to-focus app descriptions. Check these against Apple's documentation before relying on them.
