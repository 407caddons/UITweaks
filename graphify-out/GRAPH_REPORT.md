# Graph Report - LunaUITweaks  (2026-09-07)

## Corpus Check
- 147 files · ~270,371 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1221 nodes · 2372 edges · 78 communities (48 shown, 16 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 281 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `93a47fe4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- addonTable.Config.Initialize
- Tiles.lua
- Blocks.lua
- Misc.lua
- Destroy.lua
- Warehousing.lua
- DamageMeter.lua
- TalentReminder.lua
- Combat.lua
- MinimapCustom.lua
- BuffAlerts.lua
- TalentManager.lua
- CastBar.lua
- Core.lua
- MplusTimer.lua
- WoW Lua API Reference
- Loot.lua
- Coordinates.lua
- Kick.lua
- Reagents.lua
- LunaUITweaks architecture
- Snek.lua
- Cards.lua
- Widgets.lua
- AddonVersions.lua
- Boxes.lua
- Teleports.lua
- Vendor.lua
- Group.lua
- XpBar.lua
- CompactGroupFinder.lua
- Profiler.lua
- Hearthstone.lua
- Keystone.lua
- SessionStats.lua
- ReadyCheck.lua
- QueueTimer.lua
- Currency.lua
- PullTimer.lua
- Mail.lua
- DarkmoonFaire.lua
- Lockouts.lua
- PullCounter.lua
- Proposed group buff consumable checker
- widgets/AddonComm.lua
- MythicRating.lua
- Vault.lua
- XPRep.lua
- Bags.lua
- widgets/Combat.lua
- Crit.lua
- FPS.lua
- Friends.lua
- Guild.lua
- Haste.lua
- ItemLevel.lua
- Mastery.lua
- PvP.lua
- Speed.lua
- Vers.lua
- Zone.lua
- challengeMapID-keyed forces and interruptible spells
- Buff Alerts custom OGG and MP3 audio
- Crescent Moon and Cosmic Vortex Emblem

## God Nodes (most connected - your core abstractions)
1. `addonTable.Config.Initialize()` - 30 edges
2. `Helpers.UpdateModuleVisuals()` - 24 edges
3. `Helpers.CreateResetButton()` - 23 edges
4. `Helpers.CreateSectionHeader()` - 21 edges
5. `addonTable.Core.Log()` - 20 edges
6. `WoW Lua API Reference` - 20 edges
7. `addonTable.Core.SafeAfter()` - 19 edges
8. `EnsureDB()` - 19 edges
9. `RenderPane()` - 17 edges
10. `EventBus.Register()` - 16 edges

## Surprising Connections (you probably didn't know these)
- `addonTable.ConfigSetup.AddonVersions()` --calls--> `Helpers.CreateResetAllButton()`  [INFERRED]
  LunaUITweaks_Config/config/panels/AddonVersionsPanel.lua → ConfigHelpers.lua
- `addonTable.ConfigSetup.BuffAlerts()` --calls--> `BuffAlerts.SetSearchUpdateCallback()`  [INFERRED]
  LunaUITweaks_Config/config/panels/BuffAlertsPanel.lua → BuffAlerts.lua
- `addonTable.Config.Initialize()` --calls--> `addonTable.Combat.UpdateSettings()`  [INFERRED]
  LunaUITweaks_Config/config/ConfigMain.lua → Combat.lua
- `CheckCombatLogging()` --calls--> `addonTable.Core.Log()`  [INFERRED]
  Combat.lua → Core.lua
- `addonTable.ConfigSetup.Combat()` --calls--> `addonTable.Combat.CheckCombatLogging()`  [INFERRED]
  LunaUITweaks_Config/config/panels/CombatPanel.lua → Combat.lua

## Import Cycles
- None detected.

## Communities (78 total, 16 thin omitted)

### Community 0 - "addonTable.Config.Initialize"
Cohesion: 0.06
Nodes (46): addonTable.Combat.ClearConsumableUsage(), Helpers.CreateColorPicker(), Helpers.CreateColorSwatch(), Helpers.CreateFontDropdown(), Helpers.CreateResetAllButton(), Helpers.CreateResetButton(), Helpers.CreateSectionHeader(), Helpers.CreateTextureDropdown() (+38 more)

### Community 1 - "Tiles.lua"
Cohesion: 0.06
Nodes (59): addonTable.ConfigSetup.AddonVersions(), addonTable.Blocks.CloseGame(), addonTable.Blocks.ShowGame(), addonTable.Bombs.CloseGame(), addonTable.Bombs.ShowGame(), ChordReveal(), GetCellButton(), ToggleFlag() (+51 more)

### Community 2 - "Blocks.lua"
Cohesion: 0.09
Nodes (51): AnnounceGameStart(), BuildCellFrame(), BuildOppBoard(), BuildStartPayload(), CancelInvite(), DecodeBoard(), EncodeBoard(), FindCompleteRows() (+43 more)

### Community 3 - "Misc.lua"
Cohesion: 0.06
Nodes (45): addonTable.Core.SafeAfter(), addonTable.Core.SpeakTTS(), AddIDLine(), AddSpellID(), ApplyAHFilter(), ApplyUIScale(), ApplyWorkOrderFilter(), CheckForPersonalOrders() (+37 more)

### Community 4 - "Destroy.lua"
Cohesion: 0.08
Nodes (48): BuildMacroText(), CreateWindow(), Destroy.ApplyVisuals(), Destroy.ShowWindow(), Destroy.UpdateSettings(), EscapePattern(), EvaluateItem(), GetExcludedItems() (+40 more)

### Community 5 - "Warehousing.lua"
Cohesion: 0.09
Nodes (48): Helpers.ApplyFrameBackdrop(), BuildMailQueue(), CalculateOverflowDeficit(), CreatePopupFrame(), EnsureDB(), FindEmptyBagSlot(), FindItemSlots(), FindOnMerchant() (+40 more)

### Community 6 - "DamageMeter.lua"
Cohesion: 0.08
Nodes (41): AcquireRow(), AcquireSessMenuBtn(), addonTable.DamageMeter.Initialize(), addonTable.DamageMeter.ResetData(), addonTable.DamageMeter.UpdateSettings(), ApplyBackdrop(), ApplyDeathTooltip(), ApplyPositionAndSize() (+33 more)

### Community 7 - "TalentReminder.lua"
Cohesion: 0.09
Nodes (35): CleanupRecentMessages(), Comm.GetChannel(), Comm.IsAllowed(), Comm.Send(), Dispatch(), HasRealGroupMembers(), OnAddonMessage(), ShouldProcess() (+27 more)

### Community 8 - "Combat.lua"
Cohesion: 0.08
Nodes (34): addonTable.Combat.ApplyLogFrameEvents(), addonTable.Combat.ApplyReminderEvents(), addonTable.Combat.ApplyTimerEvents(), addonTable.Combat.CheckCombatLogging(), addonTable.Combat.UpdateReminders(), addonTable.Combat.UpdateSettings(), ApplyReminderEvents(), ApplyReminderLock() (+26 more)

### Community 9 - "MinimapCustom.lua"
Cohesion: 0.09
Nodes (28): AnchorQueueEyeToMinimap(), ApplyDrawerLockVisuals(), ApplyMinimapShape(), ApplyThreeSidedBorder(), CollectMinimapButtons(), EnsureBorderTextures(), HideDefaultDecorations(), IsDrawerOnRightSide() (+20 more)

### Community 10 - "BuffAlerts.lua"
Cohesion: 0.13
Nodes (34): BuffAlerts.AddCustomSound(), BuffAlerts.FindSpellMatches(), BuffAlerts.GetSoundLabel(), BuffAlerts.GetSoundOptions(), BuffAlerts.GetStatus(), BuffAlerts.IndexEncounterJournal(), BuffAlerts.MigrateLegacySounds(), BuffAlerts.Refresh() (+26 more)

### Community 11 - "TalentManager.lua"
Cohesion: 0.12
Nodes (28): Helpers.DeepCopy(), AnchorToTalentFrame(), CreateMainPanel(), DecodeImportString(), EnsureEJCache(), FindInstanceInCache(), GetOrCreateAddEditFrame(), GetOrCreateImportExportFrame() (+20 more)

### Community 12 - "CastBar.lua"
Cohesion: 0.12
Nodes (29): ApplyBarColor(), ApplyBlizzBarVisibility(), ApplyBorders(), ApplyTargetBarColor(), CastBar.ApplyEvents(), CastBar.HideBlizzardCastBar(), CastBar.RestoreBlizzardCastBar(), CastBar.UpdateSettings() (+21 more)

### Community 13 - "Core.lua"
Cohesion: 0.09
Nodes (19): ApplyDefaults(), CharacterRegistry.Delete(), CharacterRegistry.GetAll(), CharacterRegistry.GetAllKeys(), CharacterRegistry.Register(), DeepCopy(), EnsureCharDB(), OnEvent() (+11 more)

### Community 14 - "MplusTimer.lua"
Cohesion: 0.17
Nodes (30): ApplyLayout(), CheckForChallengeMode(), CompleteChallenge(), CreateBar(), DisableChallengeMode(), EnableChallengeMode(), FormatTime(), FormatTimeSigned() (+22 more)

### Community 15 - "WoW Lua API Reference"
Cohesion: 0.10
Nodes (30): Addon Metadata and Versions, Blizzard Global Frames, Class Colors, Combat and Spell APIs, Currency and Weekly Rewards, Encounter Journal, AddonComm, EventBus (+22 more)

### Community 16 - "Loot.lua"
Cohesion: 0.13
Nodes (25): AcquireToast(), GetEquippedIlvlForSlots(), GetOrCreateOverlay(), IsDuplicate(), IsIlvlUpgrade(), Loot.ApplyBagHighlightEvents(), Loot.ApplyEvents(), Loot.RecycleToast() (+17 more)

### Community 17 - "Coordinates.lua"
Cohesion: 0.15
Nodes (27): AcquireRow(), ActiveWaypointStillCurrent(), BuildZoneCache(), CheckActiveWaypointStolen(), ClearActiveWaypoint(), Coordinates.AddWaypoint(), Coordinates.ApplyWayCommand(), Coordinates.ClearAllWaypoints() (+19 more)

### Community 18 - "Kick.lua"
Cohesion: 0.16
Nodes (26): AnchorToBlizzFrame(), CreateAttachedFrame(), CreateAttachedIcon(), CreatePartyContainer(), CreatePartyFrame(), CreateSpellRow(), FindUnitFrame(), GetIconSize() (+18 more)

### Community 19 - "Reagents.lua"
Cohesion: 0.17
Nodes (25): AddReagentLinesToTooltip(), DisableEvents(), DoFullCharacterScan(), DoWarbandScan(), EnableEvents(), EnsureDB(), GetAllCharCounts(), GetCharacterClass() (+17 more)

### Community 20 - "LunaUITweaks architecture"
Cohesion: 0.10
Nodes (22): AddonComm LunaUI message bus, LunaUITweaks architecture, LunaUITweaksAPI companion panel registration, Shared ConfigHelpers control factories, Charcoal-and-mint ConfigTheme, Core initialization and recursive defaults, EventBus centralized event dispatcher, Lazy configuration initialization (+14 more)

### Community 21 - "Snek.lua"
Cohesion: 0.16
Nodes (17): LunaUITweaks_Game_Left(), LunaUITweaks_Game_Pause(), LunaUITweaks_Game_Right(), LunaUITweaks_Game_RotateCCW(), LunaUITweaks_Game_RotateCW(), MoveDown(), MoveLeft(), MoveRight() (+9 more)

### Community 22 - "Cards.lua"
Cohesion: 0.20
Nodes (14): BuildCardFrame(), BuildMiniCardFrame(), CancelDrag(), CommitDrag(), CreateDeck(), Deal(), EnsureDragGhosts(), GetDragCards() (+6 more)

### Community 23 - "Widgets.lua"
Cohesion: 0.23
Nodes (14): EvaluateCondition(), OnConditionEvent(), RebuildAnchorCache(), StartWidgetTicker(), StopWidgetTicker(), UpdateAnchoredLayouts(), Widgets.EstimateRatingGain(), Widgets.EstimateTimedScore() (+6 more)

### Community 24 - "AddonVersions.lua"
Cohesion: 0.30
Nodes (10): AddonVersions.BroadcastPresence(), AddonVersions.RefreshVersions(), BroadcastVersion(), BuildMessage(), GetPlayerKeystone(), GetPlayerName(), OnGroupRosterUpdate(), RequestVersions() (+2 more)

### Community 25 - "Boxes.lua"
Cohesion: 0.29
Nodes (11): BoxesIsOpen(), BoxesIsPaused(), CellColor(), LunaUITweaks_Game_Left(), LunaUITweaks_Game_Pause(), LunaUITweaks_Game_Right(), LunaUITweaks_Game_RotateCCW(), LunaUITweaks_Game_RotateCW() (+3 more)

### Community 26 - "Teleports.lua"
Cohesion: 0.30
Nodes (12): AcquireButton(), AcquireSecureButton(), AddDirectSpellButton(), AddMenuButton(), ClearMainPanel(), ClearSubPanel(), GetTeleportDestFromTooltip(), IsSpellKnownByName() (+4 more)

### Community 27 - "Vendor.lua"
Cohesion: 0.31
Nodes (11): addonTable.Vendor.UpdateSettings(), ApplyVendorEvents(), AutoRepair(), CheckBagSpace(), CheckDurability(), OnBagUpdateDelayed(), OnMerchantShow(), OnPlayerLogin() (+3 more)

### Community 28 - "Group.lua"
Cohesion: 0.28
Nodes (10): ApplyRaidAssignments(), GetRaidRole(), OnGroupRosterUpdate(), OnReadyCheck(), PlanRaidMoves(), RefreshGroupCache(), RefreshReadyCheckNames(), SortHealersToLast() (+2 more)

### Community 29 - "XpBar.lua"
Cohesion: 0.33
Nodes (12): addonTable.XpBar.UpdateSettings(), ApplyBlizzardBarVisibility(), FormatTime(), GetMentorBonus(), GetPendingQuestXP(), GetXPBonusPct(), Init(), OnEnteringWorld() (+4 more)

### Community 30 - "CompactGroupFinder.lua"
Cohesion: 0.35
Nodes (11): CompactEntry(), CompactGroupFinder.UpdateSettings(), DefaultRowHeight(), DesiredRowHeight(), GetScrollBox(), HideSupplementalDisplay(), InstallHooks(), RefreshVisibleEntries() (+3 more)

### Community 31 - "Profiler.lua"
Cohesion: 0.25
Nodes (7): BuildDisplayFrame(), FormatTime(), pack(), Profiler.Toggle(), SpikeColor(), timingExec(), UpdateDisplay()

### Community 32 - "Hearthstone.lua"
Cohesion: 0.36
Nodes (10): BuildOwnedList(), FormatCooldown(), GetAnyHearthstoneID(), GetCooldownRemaining(), GetRandomHearthstoneID(), OnHearthEnteringWorld(), OnHearthUpdate(), RefreshCooldownText() (+2 more)

### Community 33 - "Keystone.lua"
Cohesion: 0.25
Nodes (6): BuildTeleportMap(), FindTeleportForDungeon(), GetDungeonNameVariants(), GetKeystoneInfo(), GetPlayerKeystone(), UpdateTeleportButton()

### Community 34 - "SessionStats.lua"
Cohesion: 0.33
Nodes (7): FormatDuration(), FormatGoldPerHour(), OnChatMsgLoot(), OnPlayerDead(), OnSessionEnteringWorld(), SaveSessionData(), UpdateCachedText()

### Community 35 - "ReadyCheck.lua"
Cohesion: 0.53
Nodes (8): GetPlayerShortName(), GetShortName(), OnReadyCheck(), OnReadyCheckFinished(), OnReadyCheckResponse(), PopulateGroupMembers(), RefreshNameCache(), UpdateCachedText()

### Community 36 - "QueueTimer.lua"
Cohesion: 0.43
Nodes (6): addonTable.QueueTimer.UpdateSettings(), GetProposalTimeLeft(), Init(), OnUpdate(), StartTimer(), StopTimer()

### Community 37 - "Currency.lua"
Cohesion: 0.48
Nodes (5): AcquireRow(), GetActiveCurrencyList(), GetCurrencyData(), ReleaseAllRows(), UpdateCurrencyPanel()

### Community 38 - "PullTimer.lua"
Cohesion: 0.48
Nodes (5): CancelChatCountdown(), CancelPull(), DoChatCountdown(), GetBackend(), StartPull()

### Community 41 - "Mail.lua"
Cohesion: 0.60
Nodes (5): OnMailClosed(), OnMailShow(), OnMailUpdate(), RefreshMailCache(), ScanInbox()

### Community 42 - "DarkmoonFaire.lua"
Cohesion: 0.70
Nodes (4): FormatCountdown(), GetDMFInfo(), OnDMFEvent(), RefreshDMFCache()

### Community 43 - "Lockouts.lua"
Cohesion: 0.60
Nodes (3): OnLockoutEnteringWorld(), OnLockoutUpdate(), RefreshLockoutCache()

### Community 44 - "PullCounter.lua"
Cohesion: 0.70
Nodes (4): OnEncounterEnd(), OnEncounterStart(), OnPullCounterEnteringWorld(), RefreshCache()

### Community 46 - "Proposed group buff consumable checker"
Cohesion: 0.50
Nodes (4): Proposed group buff consumable checker, Future feature ideas baseline April 2026, Proposed buff consumable checker widget, Widget ideas and improvements baseline

### Community 47 - "widgets/AddonComm.lua"
Cohesion: 0.83
Nodes (3): GetGroupSize(), OnGroupUpdate(), UpdateCachedText()

### Community 49 - "MythicRating.lua"
Cohesion: 0.83
Nodes (3): OnRatingEnteringWorld(), OnRatingUpdate(), RefreshRatingCache()

### Community 50 - "Vault.lua"
Cohesion: 0.83
Nodes (3): OnVaultEnteringWorld(), OnVaultUpdate(), RefreshVaultCache()

### Community 52 - "XPRep.lua"
Cohesion: 0.83
Nodes (3): OnXPRepEnteringWorld(), OnXPRepUpdate(), RefreshCache()

## Knowledge Gaps
- **18 isolated node(s):** `Class Colors`, `Encounter Journal`, `Group and Social APIs`, `Quest and Objective Tracking`, `AddonComm LunaUI message bus` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 193 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `addonTable.ConfigSetup.AddonVersions()` connect `Tiles.lua` to `addonTable.Config.Initialize`, `TalentReminder.lua`?**
  _High betweenness centrality (0.212) - this node is a cross-community bridge._
- **Why does `addonTable.Core.Log()` connect `TalentReminder.lua` to `addonTable.Config.Initialize`, `Tiles.lua`, `Combat.lua`, `Core.lua`, `Kick.lua`, `Group.lua`?**
  _High betweenness centrality (0.163) - this node is a cross-community bridge._
- **Why does `addonTable.Config.Initialize()` connect `addonTable.Config.Initialize` to `Combat.lua`, `Tiles.lua`, `BuffAlerts.lua`, `XpBar.lua`?**
  _High betweenness centrality (0.159) - this node is a cross-community bridge._
- **Are the 28 inferred relationships involving `addonTable.Config.Initialize()` (e.g. with `addonTable.Combat.UpdateSettings()` and `addonTable.DamageMeter.SetLocked()`) actually correct?**
  _`addonTable.Config.Initialize()` has 28 INFERRED edges - model-reasoned connections that need verification._
- **Are the 23 inferred relationships involving `Helpers.UpdateModuleVisuals()` (e.g. with `addonTable.ConfigSetup.CastBar()` and `addonTable.ConfigSetup.Combat()`) actually correct?**
  _`Helpers.UpdateModuleVisuals()` has 23 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `Helpers.CreateResetButton()` (e.g. with `addonTable.ConfigSetup.BuffAlerts()` and `addonTable.ConfigSetup.CastBar()`) actually correct?**
  _`Helpers.CreateResetButton()` has 22 INFERRED edges - model-reasoned connections that need verification._
- **Are the 20 inferred relationships involving `Helpers.CreateSectionHeader()` (e.g. with `addonTable.ConfigSetup.CastBar()` and `addonTable.ConfigSetup.Combat()`) actually correct?**
  _`Helpers.CreateSectionHeader()` has 20 INFERRED edges - model-reasoned connections that need verification._