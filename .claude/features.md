# LunaUITweaks — Future Feature Ideas

Date: 2026-04-19
Status: Initial draft (no prior `features.md` existed at the project root; this is a fresh
baseline. Future passes should mark entries as Kept / Shipped / Revised / Removed.)

Scope guardrails considered while compiling this list:
- WoW 12.0 retail, Lua 5.1, no external libraries, no build step.
- Must not duplicate existing modules (see TOC + File Responsibilities table in
  `.claude/CLAUDE.md`).
- Taint-sensitive surfaces to avoid: `ObjectiveTrackerFrame`, `DamageMeter*`, action-bar
  buttons, `QueueStatusButton`, `PlayerSpellsFrame`, `StaticPopup*`.
- Positioning convention: CENTER-of-UIParent anchor; `x, y` offsets.
- Any "show/hide in combat" must use `RegisterStateDriver`.

Ease key: **Easy** (≤ half day, one file) · **Medium** (1–3 days, multi-file) ·
**Hard** (week+, cross-cutting or taint-heavy).

---

## Quality-of-Life

### 1. Auto-decline duels / pet battles / party invites from strangers
One-line: Auto-decline duel, pet-battle, and party invite popups from non-guild / non-friend
players (whitelist-configurable).
Motivation: The existing Misc auto-invite accepts from the whitelist; the reverse (auto-decline
outside it) is a frequent complaint, especially for streamers and farmers.
Ease: **Easy** — hook `DUEL_REQUESTED`, `PET_BATTLE_PVP_DUEL_REQUESTED`,
`PARTY_INVITE_REQUEST` via EventBus; call `CancelDuel()` / `DeclineGroup()` before the popup
shows. No secure surface involved.
Taint: None — these are unprotected APIs.

### 2. /reload reminder after settings change
One-line: Track settings that require a reload and show a yellow "Reload recommended" banner
in the config window until the user clicks it (runs `ReloadUI()`).
Motivation: Several modules (CastBar hide-Blizzard, Minimap shape, StateDriver switches) only
fully apply after reload; users get inconsistent results without it.
Ease: **Easy** — add a `reloadPending` flag to `Config.lua` and a banner row in
`ConfigMain.lua`.
Taint: None.

### 3. Bag search / highlight
One-line: Text box that highlights bag slots matching a substring of item name.
Motivation: Built-in search exists but clears constantly; an addon-owned overlay that persists
between bag toggles is handy for cleanup / vendor runs.
Ease: **Medium** — iterate `C_Container.GetContainerItemInfo` on `BAG_UPDATE_DELAYED`,
draw borders on matching slots via a secondary overlay frame (do NOT write to the Blizzard
bag buttons — parent overlay frames to `UIParent` and anchor via `SetPoint` reads).
Taint: Low if using overlay frames; avoid `hooksecurefunc(ContainerFrame*, ...)`.

### 4. Reagent-bank deposit shortcut
One-line: One-click "deposit all reagents" button added next to the bank window when it's
open (using an addon overlay frame, not reparenting Blizzard buttons).
Motivation: Reagent bank deposit is a deep click path and a common flow.
Ease: **Medium** — global-form hook on `ToggleAllBags` / bank-shown event; iterate bag
slots and `C_Bank.DepositReagentBankItem`. Avoid `HookScript` on Blizzard's bank frame.
Taint: Low if overlay-only; DO NOT reparent the deposit button into the bank frame (same
class of bug as the `StaticPopup` issue in `Misc.lua:422`).

### 5. Screenshot-on-event
One-line: Auto-screenshot on configurable events: boss kill, achievement earned, M+ completion,
level-up.
Motivation: Common QoL; most players forget to screenshot the big moments.
Ease: **Easy** — EventBus-subscribe to `BOSS_KILL`, `ACHIEVEMENT_EARNED`,
`CHALLENGE_MODE_COMPLETED`, `PLAYER_LEVEL_UP`; call `Screenshot()`. Guard with a
debounce.
Taint: None.

### 6. "Don't pull yet" auto-respond chat macro
One-line: Slash `/luit nopull <seconds>` posts a party message, pings the minimap, and shows
a PullTimer-style bar.
Motivation: Currently PullCounter / PullTimer widgets exist, but no easy way to *initiate*
a pre-pull countdown without MRT.
Ease: **Easy** — reuses existing PullTimer widget; adds a slash handler and a `SendChatMessage`
to `PARTY`/`RAID`.
Taint: None.

### 7. Hearthstone auto-use on slash command
One-line: `/luit hs` uses the currently-set hearthstone toy/item (respects the Hearthstone
widget's selection).
Motivation: Widget already tracks selection; a slash binding removes a click.
Ease: **Easy** — `UseItemByName` or `C_Item.UseToy`; non-secure so must be hand-triggered
from a /click keybinding (not automated).
Taint: None (user-initiated).

---

## Combat & Encounter

### 8. Interrupt announcements
One-line: Post a party/say message when the player (or optionally any party member) lands an
interrupt — with spell name and target.
Motivation: Complements the existing Kick module (cooldowns) with output; popular in M+.
Ease: **Easy** — EventBus-subscribe to `UNIT_SPELLCAST_INTERRUPTED`.
Taint: `interruptedBy` GUID is a secret value during combat (already documented in CLAUDE.md)
— can't read source GUID; use `sourceGUID` from the event's arg0 unit only if non-secret, or
announce only the *target* and interrupted spell.

### 9. Combat-start / combat-end sound
One-line: Play a configurable sound cue on `PLAYER_REGEN_DISABLED` / `_ENABLED`.
Motivation: Useful for tanks checking pulls, or healers distinguishing combat states audibly.
Ease: **Easy** — EventBus + `PlaySoundFile`. Add a file picker to the Combat panel.
Taint: None.

### 10. Personal DPS/HPS overlay under the player frame
One-line: Tiny text overlay showing your live DPS/HPS pulled from `C_DamageMeter` without
opening the session window.
Motivation: DamageMeter is great but requires the window open; a one-line overlay is what
people copy from ElvUI / Details miniview.
Ease: **Medium** — polling `C_DamageMeter.GetPlayerStats` (if available) or reading the
non-secret aggregate fields. Position via widget framework (already supports it).
Taint: **Serious caveat** — per CLAUDE.md the live combat fields are secret. Any copy into a
Lua local/table breaks. Must pass values *directly* into `SetText`/`SetValue` and never
compare. Already a solved pattern in `DamageMeter.lua:474-562` — reuse it.

### 11. Taunt / Defensive CD tracker for group frames
One-line: Track tank taunts and defensive CDs on the party/raid frames (similar to the Kick
module's UI but for defensives).
Motivation: Natural companion to the existing Kick tracker.
Ease: **Medium** — reuse Kick.lua's group-frame attachment pattern; maintain a static table
of defensive/taunt spell IDs per class. EventBus: `UNIT_SPELLCAST_SUCCEEDED` + combat log
replacements via encounter events (not CLEU — that's forbidden).
Taint: Must attach overlays to unit-frame positions via `SetPoint` reads, not writes; same
pattern Kick.lua already uses safely.

### 12. Group Buff / consumable checker
One-line: On encounter start (or ready check) scan for missing buffs (flask, food, rune,
weapon enchant) and whisper / raid-warn offenders.
Motivation: Every guild reinvents this; simple version fits.
Ease: **Medium** — `UnitAura` iteration on `READY_CHECK` / `ENCOUNTER_START`; static list
of season flask/food/rune spellIDs stored similar to `MplusData.lua`.
Taint: None. Unit names in combat are secret — either fire only outside combat (ready check
always is) or use `issecretvalue` guard (pattern exists in `TalentReminder.lua:227`).

---

## Social & Group

### 13. Group ready-check summary
One-line: After a ready check, print a one-line summary ("Ready: 5 / 10, AFK: 2, Declined: 3")
with color-coded names.
Motivation: The default `READY_CHECK_CONFIRM` toasts fade fast; a persistent summary is nicer
for raid leads.
Ease: **Easy** — track `READY_CHECK`, `READY_CHECK_CONFIRM`, `READY_CHECK_FINISHED`;
print via `Core.Log`.
Taint: None.

### 14. Loot roll announcer
One-line: Announce group loot rolls with item link and roll value to the party chat, or filter
them into a private addon frame.
Motivation: Loot roll chat is a firehose; compact summary is QoL.
Ease: **Easy** — EventBus: `CHAT_MSG_LOOT`, `CHAT_MSG_SYSTEM` for rolls.
Taint: None.

### 15. Whisper-to-popup window
One-line: Pop up a small movable frame for each incoming whisper (with auto-dismiss on reply).
Motivation: Old WIM-lite feature; useful for streamers and raiders who miss whispers.
Ease: **Medium** — `CHAT_MSG_WHISPER` handler; pool reusable frames via a small framework
similar to Frames.lua.
Taint: None — addon-owned frames.

### 16. Guild online / login / logout feed
One-line: Small movable feed showing guild member logins/logouts with timestamp, toggleable.
Motivation: Guild roster chatter is useful for social guilds and raid recruits.
Ease: **Easy** — `GUILD_ROSTER_UPDATE` diffing via side-table cache.
Taint: None.

---

## Economy & Vendoring

### 17. Gold log / session gold tracker
One-line: Widget showing gold earned/spent this session, broken into vendor / quest / loot
sources if possible.
Motivation: Nice snapshot similar to the SessionStats widget but for currency.
Ease: **Easy-Medium** — `PLAYER_MONEY` diffing + categorize by most-recent event (vendor
open, quest complete, etc.). Imperfect categorization but good enough.
Taint: None.

### 18. Auto-sell item list (not just greys)
One-line: Extend Vendor.lua to auto-sell a user-maintained item blacklist (by itemID or
item name substring) on vendor open.
Motivation: Common QoL — sell known junk BoPs, low-ilvl greens, reagents the user never uses.
Ease: **Easy** — extends existing Vendor.lua; add list editor in VendorPanel.
Taint: None.

### 19. AH undercut scanner (read-only)
One-line: When player's posted auctions are shown, mark which are currently undercut.
Motivation: Simple visual; AH price tracking is a massive category but even a simple "you've
been undercut" flag is useful.
Ease: **Medium** — `C_AuctionHouse` events; compare owned item queries with the lowest
scan result.
Taint: None. AH events are not combat-secret.

### 20. Mail auto-open / collect
One-line: When the mailbox is opened, auto-collect attachments and gold from all messages
(with configurable filters).
Motivation: Current Mail widget only counts unread mail; auto-open is the next logical step.
Ease: **Medium** — `C_Mail.OpenMail` iteration; throttle between calls to avoid server kick.
Taint: None.

---

## UI & Layout

### 21. Tooltip item-source display
One-line: Append "Source: <dungeon / raid / vendor>" to item tooltips using a static lookup
table.
Motivation: Common feature in DBM-Core / HandyNotes-style addons; nice on gear inspection.
Ease: **Medium** — requires a curated source table per item (large data burden), but
hookup is trivial via `TooltipDataProcessor.AddTooltipPostCall`.
Taint: None.

### 22. Chat frame timestamp format override
One-line: Let the user pick 12h/24h, with/without seconds, colored or plain.
Motivation: Blizzard's timestamp options are minimal; common request.
Ease: **Easy** — global-form `hooksecurefunc("ChatFrame_OnEvent", ...)` or
`TooltipDataProcessor`-equivalent for chat. Actually simpler: replace `BCTimestampFormat` via
`_G["CHAT_TIMESTAMP_FORMAT"]` setting — non-secure, safe.
Taint: None when using the global constant, not frame-object hooks.

### 23. Minimap zoom step memory
One-line: Remember and restore the player's preferred minimap zoom level on login / zone change.
Motivation: Minimap zoom resets constantly, especially after boss encounters.
Ease: **Easy** — poll `Minimap:GetZoom()` on save; `Minimap:SetZoom(saved)` on restore.
Taint: `SetZoom` on Blizzard Minimap — unclear if safe. Test carefully; fall back to
`Minimap:GetZoomLevels()` logic. If it taints, abandon.

### 24. Raid Warning / Boss Emote capture frame
One-line: A separate movable frame that mirrors raid warnings and boss emotes in a larger
font.
Motivation: Blizzard's RW is easy to miss mid-fight; a dedicated large frame is a staple for
raid leads.
Ease: **Easy** — EventBus: `CHAT_MSG_RAID_WARNING`, `CHAT_MSG_RAID_BOSS_EMOTE`,
`CHAT_MSG_RAID_BOSS_WHISPER`. Addon-owned frame.
Taint: None.

### 25. Custom action-bar cooldown text
One-line: Replace default cooldown text on action buttons with configurable size / color /
decimal precision.
Motivation: OmniCC's core feature; small standalone version is well-scoped.
Ease: **Hard** — touches action buttons, which are the exact taint-heavy surface
CLAUDE.md warns about. Any frame-object hook or field write on a Blizzard action button taints
the shared prototype → `ADDON_ACTION_BLOCKED`. Would need to walk action buttons with
global-form hooks only (`hooksecurefunc("CooldownFrame_Set", ...)` etc.) and keep state in
side-tables.
Taint: **HIGH RISK.** Only attempt if willing to accept possible regressions; document
carefully.

---

## Quality-of-Life (continued)

### 26. Instance portal countdown
One-line: When you step into an instance portal, show a 10-second cancel-window timer so you
can back out.
Motivation: The lockout system is cruel; a visual countdown prevents accidental saves.
Ease: **Easy** — hook `LFG_PROPOSAL_SHOW` equivalent / `ZONE_CHANGED_NEW_AREA` transition;
just a timer widget.
Taint: None.

### 27. Portable inspect / quick armory
One-line: `/luit inspect <name>` opens the inspect window on a target if they're in range,
with a persistent history of the last 10 inspected characters (name, ilvl, spec).
Motivation: Built-in inspect is flow-heavy; remembering who you inspected is useful.
Ease: **Medium** — `NotifyInspect`, `INSPECT_READY`; cache `GetInspectSpecialization`,
`C_PaperDollInfo.GetInspectItemLevel`. History in `UIThingsDB`.
Taint: None.

---

## Flagged high-taint-risk ideas (listed so they're considered, not recommended)

These were brainstormed but are NOT recommended given the addon's commitment to being
taint-clean:

- **Objective tracker replacement / skinning** — extensively documented as untouchable in
  MEMORY.md. Leave Blizzard's tracker alone.
- **DamageMeter skinning / repositioning** — protected frame, any positioning call taints.
  MEMORY.md marks this as no-op.
- **Action button skinning / keybind text** — taints Button prototype (see MEMORY.md
  ActionBars section). Only the 2-second polling ticker approach is safe, and it's fragile.
- **Player / target unit frame reskins** — secure frames; the companion addon
  `LunaUITweaks_UnitFrames` is where any such work should live.
- **Macro / spell auto-cast automation** — all protected; not feasible from addon code.
- **Automatic bag sort** — Blizzard's `C_Container.SortBags` works but triggers taint when
  called in combat; needs a combat-lockdown guard at minimum.

---

## Summary of counts

- Quality-of-Life: 9 ideas (entries 1–7, 26, 27)
- Combat & Encounter: 5 ideas (8–12)
- Social & Group: 4 ideas (13–16)
- Economy & Vendoring: 4 ideas (17–20)
- UI & Layout: 5 ideas (21–25)
- Total feasible: 27 (exceeds the 15–25 target; trim/defer as needed)
- High-risk flagged for avoidance: 6

Next-pass instructions: keep this file's structure; when an idea ships, change the heading
to "### N. [SHIPPED vX.Y] …" and keep the entry for history. When an idea is abandoned (e.g.
taint risk proven), mark "### N. [ABANDONED] …" with a one-line reason.
