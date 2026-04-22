# LunaUITweaks Widget Ideas & Improvements

_Daily brainstorm. No prior `widgets.md` existed — this is the initial baseline._

## Existing Widgets (as of 2026-04-19)

Shipped widgets live under `widgets/`. Do not propose duplicates of these:

`AddonComm`, `Bags`, `BattleRes`, `Combat`, `Coordinates`, `Crit`, `Currency`,
`DarkmoonFaire`, `Durability`, `FPS`, `Friends`, `Group`, `Guild`, `Haste`,
`Hearthstone`, `ItemLevel`, `Keystone`, `Lockouts`, `Mail`, `Mastery`,
`MythicRating`, `PullCounter`, `PullTimer`, `PvP`, `ReadyCheck`, `SessionStats`,
`Spec`, `Speed`, `Teleports`, `Time`, `Vault`, `Vers`, `Volume`,
`WaypointDistance`, `WeeklyReset`, `WheeCheck`, `XPRep`, `Zone`.

Notable existing coverage: FPS/latency/memory (`FPS`), secondary stats (`Crit`,
`Haste`, `Mastery`, `Vers`), session tracking (`SessionStats`), gold/currencies
(`Currency`), keystone + teleports, great vault, lockouts, raid readiness.

## Baseline Status Legend

- **New:** suggested for the first time in this pass.
- **Kept:** carried over from a prior pass, still worth building.
- **Shipped:** already implemented — delete from this list.
- **Removed:** dropped (duplicate / unfeasible / taint-blocked).

All items below are **New** for this first pass.

---

## Enhancements to Existing Widgets (10)

### 1. Durability repair budget threshold (enhance `Durability`)

- **What:** Colour the main text red + pulse when estimated repair cost exceeds
  a user-configured gold threshold (e.g. 500g), not just when durability % is
  low. Uses the already-cached `cachedRepairCost`.
- **Why:** Cost-based warnings catch expensive repair bills (high ilvl gear,
  many broken slots) that low-% warnings miss.
- **Ease:** Easy. All data already cached in `Durability.lua`.
- **Taint notes:** None — addon-owned frame, text colouring only.

### 2. FPS jitter indicator on the widget itself (enhance `FPS`)

- **What:** Already computed in the tooltip — surface a small coloured dot or
  append a `j:12` suffix on the main widget text when jitter exceeds threshold.
  Today the jitter calc is tooltip-only.
- **Why:** Users who care about network quality want an at-a-glance indicator
  without hovering.
- **Ease:** Easy. The latency history + variance math is already in `FPS.lua`;
  just write to `self.text`.
- **Taint notes:** None.

### 3. Session stats: per-hour items looted + loot-by-quality breakdown (enhance `SessionStats`)

- **What:** Add `itemsLooted/hr` and a quality-bucket breakdown (greys,
  greens, blues, purples) to the session tooltip using the existing
  `CHAT_MSG_LOOT` hook. Detect quality by parsing the hyperlink colour code.
- **Why:** Lets farmers and M+ runners evaluate loot density across runs.
- **Ease:** Medium. `CHAT_MSG_LOOT` payload may hold a secret value during
  combat (already guarded with `issecretvalue`); parse the `|c` prefix of the
  item link for colour.
- **Taint notes:** Keep the existing `issecretvalue` guard in place; never use
  loot msg strings as table keys or compare with `<`/`>`.

### 4. Keystone widget: show party keystone ranges & highest-available key (enhance `Keystone`)

- **What:** Next to each party member's key, show the estimated rating gain
  from *running their key* (not just your own). Highlight the party key that
  yields the largest score gain for *you* (the "best key to run").
- **Why:** Groups spend time negotiating which key to run — this answers it
  instantly.
- **Ease:** Medium. Party keystones already received via `AddonVersions`
  data; feed each into `Widgets.EstimateRatingGain` with caller's own best
  scores.
- **Taint notes:** All addon-side math, no Blizzard frame touches.

### 5. Vault: show score delta to next slot (enhance `Vault`)

- **What:** For M+ vault slots, display how many levels/runs until the next
  reward tier *and* the estimated rating cap for the current slot's tier.
- **Why:** Users can't remember the 1/4/8 M+ run thresholds and which slot
  corresponds to which level.
- **Ease:** Easy. `C_WeeklyRewards.GetActivities` returns `threshold` fields.
- **Taint notes:** None.

### 6. Currency icons and per-cap colouring (enhance `Currency`)

- **What:** Prepend the currency's texture icon to each tracked currency in
  the tooltip; colour the value red when at cap, yellow when ≥90% cap.
- **Why:** Cap-watching is the main reason to track currencies.
- **Ease:** Easy. `C_CurrencyInfo.GetCurrencyInfo` already returns
  `maxQuantity` and `iconFileID`; add `|T<iconID>:14|t` inline.
- **Taint notes:** None.

### 7. Lockouts: instance-lockout timer tooltip (enhance `Lockouts`)

- **What:** Show raid-lockout remaining time for each instance (e.g. "2d 14h"
  until reset) alongside bosses killed. Useful for groups planning split runs.
- **Why:** Currently shows kills but not how long the save persists.
- **Ease:** Easy. `GetSavedInstanceInfo(i)` returns `reset` seconds.
- **Taint notes:** None.

### 8. Bags: free-slot-type breakdown (enhance `Bags`)

- **What:** Tooltip listing free slots by bag type (regular, reagent, herb, ore,
  leather, etc.), plus "largest item I could pick up" line.
- **Why:** Crafters and gatherers care about profession-bag space separately
  from regular inventory.
- **Ease:** Medium. `C_Container.GetContainerNumFreeSlots(bag, bagFamily)` and
  `GetItemFamily` handle this.
- **Taint notes:** None.

### 9. PullTimer: loud-mode big countdown overlay (enhance `PullTimer`)

- **What:** Optional large centred countdown (`3` `2` `1` `GO`) when a pull
  timer is received, not just the small widget text.
- **Why:** Raiders currently use DBM or BigWigs for visible pull timers; this
  would cover the gap for users who don't run those addons.
- **Ease:** Easy. Standalone FontString on a new addon frame — no taint.
- **Taint notes:** Purely addon-owned frame.

### 10. Hearthstone: random toy mode + cooldown swap (enhance `Hearthstone`)

- **What:** Option to cycle a random known hearthstone toy on each click (when
  not on cooldown). Show the currently-selected toy's icon on the widget.
- **Why:** Players collect dozens of hearth toys and rarely see them.
- **Ease:** Medium. Toy list + `C_ToyBox.PickupToy` under a
  `SecureActionButtonTemplate`.
- **Taint notes:** Must be a secure button; switching `type`/`toy` attributes
  must happen outside combat (guard with `InCombatLockdown`).

---

## Brand-New Widget Ideas (10)

### 11. Reputation Watch widget (paragon / renown / delve rep aware)

- **What:** Show the player's *currently-watched* faction name + bar-style
  progress (`24,567 / 41,000` + %), plus nearest paragon chest when applicable.
  Click cycles through recent reps.
- **Why:** `XPRep` exists as a bar, but a compact text widget for the
  specifically-tracked rep is missing.
- **Ease:** Easy. `GetWatchedFactionInfo` + `C_Reputation.GetFactionParagonInfo`.
- **Taint notes:** None.

### 12. Buff/Consumable Checker widget

- **What:** Traffic-light widget: green when flask + food + rune + weapon oil
  + augment rune are all active; lists missing ones in the tooltip.
- **Why:** Raiders lose pulls to missing consumables; this is a visible
  pre-pull checklist.
- **Ease:** Medium. `AuraUtil.ForEachAura` scan. Maintain a user-editable
  list of "required" buff SpellIDs per spec.
- **Taint notes:** Aura scanning is read-only, no taint. Don't write anything
  back to Blizzard aura frames.

### 13. Stat weight / "delta on equip" helper

- **What:** When hovering a gear piece in bag/loot window, show
  `+Δilvl` and `+Δ secondary-stat-of-interest` compared to currently-equipped.
  Small HUD readout next to cursor-anchored tooltip.
- **Why:** Quick upgrade check without opening a character panel.
- **Ease:** Hard. Needs tooltip-scan pipeline and cached equipped-stats table.
- **Taint notes:** Read via `C_TooltipInfo.GetInventoryItem`/`GetBagItem` and
  watch for secret values on line text — guard with `issecretvalue`.

### 14. Cooldown Tray widget (personal CDs)

- **What:** Row of icons for player's major offensive/defensive CDs, greyed +
  numeric countdown when on cooldown. User chooses which SpellIDs to track.
- **Why:** Players not using WeakAuras want a simpler built-in CD tracker.
- **Ease:** Medium. `C_Spell.GetSpellCooldown` polled once per second (already
  in widget ticker loop).
- **Taint notes:** Render icons on addon frame only; never parent to a
  Blizzard action bar button (would taint Button prototype).

### 15. Profession Cooldown Tracker widget

- **What:** Lists daily/weekly profession cooldowns per character (Spark of
  Omens, Artisan's Acuity conversions, alchemy transmutes, tailoring imbues).
  Cross-character via `LunaUITweaks_CharacterData`.
- **Why:** Easy money sink — players forget profession CDs on alts.
- **Ease:** Medium. Track via `C_TradeSkillUI.GetRecipeInfo`, store last-cast
  timestamps in saved vars.
- **Taint notes:** None — bag/recipe APIs are safe.

### 16. Delve Tier / Bountiful-Key widget

- **What:** Shows current delve tier cap reached this week, bountiful-key
  count in inventory, and best available delve this season. Click pastes a
  chat macro with "LF delve +X".
- **Why:** Delves are a weekly rhythm with state that's currently buried in UI.
- **Ease:** Medium. `C_DelvesUI` + item-id scan for bountiful keys.
- **Taint notes:** Macro paste uses `ChatFrame_OpenChat`, safe.

### 17. Group Finder Queue Summary widget

- **What:** When queued in LFG/LFR/PvP, show compact line: `LFR: ~3m ETA  |
  Tanks 0/2  Healers 1/2  DPS 4/6`. Mirrors what the queue frame shows, but
  as a HUD so it's visible while questing.
- **Why:** Players miss queue pops because they're alt-tabbed or the tracking
  frame is hidden.
- **Ease:** Medium. `GetLFGQueueStats`, `C_LFGList.GetSearchResults`.
- **Taint notes:** Read-only.

### 18. Corpse Run widget

- **What:** Appears only while dead/ghost: shows distance to corpse, ETA at
  current run speed, and a "run timer" (time-of-death stopwatch).
- **Why:** Fun and actually useful in open-world dying.
- **Ease:** Easy. `C_DeathInfo.GetCorpseMapPosition` or `GetCorpseMapPosition`;
  use `condition = "dead"` pattern (needs new condition in `EvaluateCondition`).
- **Taint notes:** None.

### 19. Warband Bank Gold Rollup widget

- **What:** Rolls up gold across all characters registered in
  `LunaUITweaks_CharacterData`, shows grand total + top 3 richest alts in
  tooltip.
- **Why:** No built-in view for warband-wide gold; players currently open every
  character to check.
- **Ease:** Easy. Cross-character data already persists; hook `PLAYER_MONEY`
  to refresh this char's record.
- **Taint notes:** None.

### 20. Dragonriding / Skyriding Vigor widget

- **What:** Shows current vigor pips + regen time to full while skyriding is
  active. Auto-hides on ground. Numeric "next pip in 4.2s".
- **Why:** Skyriders judge jumps/whirling surges by vigor; Blizzard's default
  bar is tiny and pinned to the top.
- **Ease:** Medium. `C_UnitAuras`/`UIWidgetManager` supplies vigor power.
  Detect skyriding mount via `C_MountJournal.GetMountIDs` + `IsMounted` +
  mount flags, or via power-bar visible widget.
- **Taint notes:** Power bar widget data is read-only — safe. Do **not**
  hook Blizzard `UIWidgetTemplates`; read values, render on addon frame.

---

## Notes for implementation

- Every new widget follows the existing pattern:
  `table.insert(Widgets.moduleInits, function() … end)` in a new file under
  `widgets/`, add it to `LunaUITweaks.toc` load order, add a defaults block to
  `Core.lua` `DEFAULTS.widgets`, and register an entry in the Widgets config
  panel.
- Use `addonTable.EventBus` for all event subscriptions — never create new
  event frames.
- Secondary-stat widgets already share `Widgets.ShowStatTooltip` — reuse it.
- Remember the CENTER-anchor positioning rule for movable frames.
- For anything that hooks Blizzard frames (action bars, queue button, chat
  frames, objective tracker), prefer global-form `hooksecurefunc` + tickers;
  frame-object hooks taint the Button prototype. See project CLAUDE.md.
