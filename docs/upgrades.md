# Career and upgrades — research and plan

Status: research, nothing built. Builds on the three upgrades already queued in
`to-check.md` (wheels and tires, roll cage, skid plate).

## What real builders do

Forum and shop advice agrees on the start and argues about the rest:

1. **Tires first** — the single change that adds the most beyond stock.
2. **Suspension / lift** — mostly so bigger tires fit and the belly clears.
3. **Then it depends on what stops you**: lockers (spinning one wheel), armor
   (hanging or bashing on rock), recovery gear (stuck with nothing to pull on).
   The common advice is "fix what fails you on the trail", not "buy in catalog
   order".

That last point is the design rule for career mode: **each stage should show
the player what they're missing.** Hung on a rock means a skid plate or sliders.
A drowned intake means a snorkel. Lifting a wheel and spinning it means a locker.
Too fast to crawl a ledge means a regear or a 4:1 transfer case.

Rough Philippine prices, for scale (Philkotse/AutoDeal, undated): a lift kit runs
₱54–70k, one Cooper M/T tyre about ₱14k, and a set of wheels and tyres ₱60–100k.
Lockers weren't priced; ARB air lockers are imported, and a Lockright
(lunchbox) is the budget option. A full built rig runs well over ₱1M.

## Every part is a trade, not a strict upgrade

That keeps it from being a stat ladder. Every part adds mass, and most move the
centre of mass.

| Part | Tiers | Gains | Costs | Where in code |
|---|---|---|---|---|
| Tires | 31 / 33 / 35 / 37 in, A/T or M/T | clearance, ledge climbing, floatation (`wheel.gd`) | higher CoM, taller effective gearing, rub without lift; A/T clogs in mud | `tire_radius`, `tire_width`; `BodyKit.well_radius` follows |
| Wheels | steelies, beadlocks | beadlocks: air down to 8 psi without debeading | cost, weight | `wheel_color`, `PSI_STEPS`, `debeaded` |
| Lift | stock / 2.5 in / 4 in / long-travel | clearance, fits bigger tires; long-travel adds `droop`/`bump` | CoM up, tips sooner on off-camber | `wheel_mount_y`, `droop`, `bump`, `center_of_mass.y` |
| Lockers | open / rear lunchbox / selectable rear / selectable F+R | both wheels on an axle turn together | lunchbox is always locked and pushes in turns; front locked kills steering; shock loads snap axles (damage) | today `diff_locked` is a free L toggle on every rig: gate it per axle |
| Gearing | 4.56 / 4.88 / 5.13 / 5.38 final; 2.72 or 4:1 low range | crawl control, pulls big tires | lower top speed | `final_drive`, `low_ratio` |
| Winch | none / 9.5k lb steel / 12k lb synthetic | recovery anywhere there's an anchor | ~40 kg on the nose | `winch_pull_speed`, plus a pull limit |
| Snorkel | none / snorkel | intake at roof height instead of ~0.9 m | looks, cost | `rig.gd:377` hard-codes 0.75–1.05 m: make it `spec.intake_height` |
| Armor | skid plate, rock sliders, steel bumpers | slide off rock instead of hanging on it; protects underbody parts once damage exists | weight (low, so CoM drops a little) | physics material on belly colliders |
| Roll cage | none / roll bar / full cage | in a rollover the cage takes it, not the body and driver | weight up high | body builder flag, collision box |
| Compressor | none / on-board | air back up anywhere | cost | `_air_step`: no compressor means air-up only at the finish or a sari-sari stop |
| Recovery kit | shovel, boards, high-lift jack | already built (`recovery_kit.gd`) | — | sold one at a time instead of all free |

Numbers for the gearing tier: the Gera crawls at 4.02 × 2.72 × 4.56 ≈ **50:1**.
Rock crawlers want roughly 60–100:1. A 4:1 low range puts it at 73:1, and 4:1
with 5.13s at 82:1. That's the target for the gearing tiers.

Winch rule of thumb: rated pull ≥ 1.5 × rig weight. The Gera (1950 kg) needs
about 6,400 lb, so 9.5k lb is plenty and 12k is for the heavy rigs (Ronda,
Rubikon).

**The Gerilya is the Gera with parts on**: 37s, regear to 4.88, full cage,
sliders, more droop. In career it can be the finished build you work toward
instead of a rig you just pick, with the stock Gera as the starting point.

## Career loop

No clock on purpose, so pay can't come from times. It comes from getting
through, and from how cleanly:

- **Events, not races**: a Sunday club run (Moderate), the club challenge
  (Hard), an invitational (Extreme). They follow the shape of real Philippine
  events (NAsFOR/Maxxis Cup technical stages, King of RIOT in Baras, Rizal,
  team trophy runs like TVET in Cavinti), with our own names.
- **Pay in pesos** for a finish, scaled by `StagePlan.DIFFICULTY`. Less for
  each marshal recovery (Backspace), which is now a real cost: the marshals
  and their tow aren't free.
- **Money goes out** on parts, and once damage exists (realism plan item 3) on
  repairs: a bent tie rod, a snapped CV, a hydrolocked engine. That's what
  gives the skid plate, cage, snorkel and the risk of a front locker their
  value.
- **Unlocks**: Hard and Extreme events open after finishes. Some rigs are
  bought, not just picked.
- Free play stays as it is today (every rig, seed, weather and level), so the
  career is an extra mode, not a gate.

## How it fits the code

- `RigSpec.get_kind(i)` gives the stock spec. A new `Parts.apply(spec, fitted)`
  modifies a copy before the Rig is built, so `rig.gd`/`wheel.gd` keep
  reading the same fields. The part table above maps to fields that already
  exist, except `intake_height`, the locker layout, beadlocks, and the
  compressor flag.
- Save: `user://career.cfg` holds pesos, owned parts per rig, fitted parts and
  unlocked events, next to `look.cfg`.
- Garage: a Parts page next to paint and shirt, using the turning preview that
  already exists. Fit a part and the pad rig rebuilds: tires grow, the lift
  rises, the cage appears.
- Body builders need part flags (cage, sliders, bumper, snorkel), the way
  `build_trail` already differs from `build`.
- The HUD finish line (`hud.gd:76`) becomes a payout card: finish pay, minus
  recoveries, minus repairs.

## Suggested order to build

1. `Parts.apply` plus tires, lift and gearing. These are pure spec numbers, so
   they're quick to build and easy to feel.
2. Lockers per axle (gate the L toggle) and the snorkel (`intake_height`).
3. Career save, pesos, events and the payout card. Recoveries cost money.
4. Garage parts page with live rebuild.
5. Armor and roll cage on the bodies.
6. Damage (realism plan 3), where armor and the cage start to matter.

## Open questions for you

- Start the career in the stock Gera only, or pick any stock rig?
- Can you lose the career (broke, can't pay for repairs), or does it always
  give you enough for the next club run?
- Do parts carry over between rigs (tires, winch), or are they bought per rig?
- Any other parts you had in mind beyond these?

Sources: [Philkotse Hilux](https://philkotse.com/car-maintenance/modified-toyota-hilux-11637),
[Philkotse F-150](https://philkotse.com/car-maintenance/modified-ford-f-150-tips-and-tricks-7121/amp),
[AutoIndustriya forum on lockers](https://talkboard.autoindustriya.com/post/155111),
[Patriot Tires PH](https://goflatoutph.com/2019/09/22/patriot-tires-launches-in-the-philippines-with-its-affordable-line-up/),
[Overland Bound: first upgrade](https://overlandbound.com/forums/threads/whats-do-you-think-the-most-impactful-first-upgrade-is-to-a-rig.46288/page-2),
[Tacoma3G first mods](https://tacoma3g.com/threads/5-first-mods-for-an-off-road-build-my-opinion.7991),
[Golden Offroad build stages](https://www.goldenoffroad.com/the-ultimate-off-road-truck-build-guide-from-stock-to-trail-ready-in-5-stages),
[King of RIOT](https://mb.com.ph/2022/10/6/king-of-riot-4x4-challenge-is-back),
[Maxxis/NAsFOR series](https://www.philstar.com/business/motoring/2014/03/26/1304988/dirty-fun-maxxis-cup-nasfor-4x4-xtreme-challenge-series),
[TVET 2026 Cavinti](https://tribune.net.ph/amp/story/2026/05/31/trail-venture-epic-trophy-heads-to-cavinti).
