# Graph Report - LunaUITweaks  (2026-09-07)

## Corpus Check
- 156 files · ~270,153 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1221 nodes · 2371 edges · 79 communities (49 shown, 16 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 280 edges (avg confidence: 0.85)
- Token cost: unavailable for host-agent semantic extraction (recorded zero counts are placeholders). No external LLM API was used.

## Community Hubs (Navigation)
- Config Panel Controls
- Puzzle Game Windows
- Falling Blocks Game
- Notifications and Quest Alerts
- Destroy and Event Dispatch
- Warehouse Inventory Management
- Damage Meter Rendering
- Talent Alerts and Communication
- Combat Timers and Reminders
- Minimap and Drawer
- Buff Alert Rules
- Talent Build Management
- Player and Target Castbars
- Core Initialization and Frames
- Mythic Plus Timer
- WoW API Reference
- Loot Toasts and Highlights
- Waypoint Management
- Interrupt Tracking
- Reagent Inventory Tracking
- Documented Project Architecture
- Snake Game Controls
- Card Game Dragging
- Widget Layout and Updates
- Addon Version Sharing
- Box Puzzle Controls
- Teleport Menu
- Vendor Automation
- Group Management
- Experience Bar
- Compact Group Finder
- Performance Profiler
- Hearthstone Selection
- Keystone Teleports
- Session Statistics
- Ready Check Tracking
- Queue Timer
- Currency Tracker
- Pull Countdown
- Config Visual Theme
- Mail Tracking
- Darkmoon Faire Calendar
- Instance Lockouts
- Encounter Pull Counter
- Proposed Feature Roadmap
- Communication Status Widget
- Mythic Rating Widget
- Vault Widget
- Experience Reputation Widget
- Bag Gold Widget
- Combat Status Widget
- Critical Strike Widget
- Performance Memory Widget
- Friends Status Widget
- Guild Status Widget
- Haste Stat Widget
- Item Level Widget
- Mastery Stat Widget
- PvP Status Widget
- Movement Speed Widget
- Versatility Stat Widget
- Zone Name Widget
- Dungeon Data Generation
- Custom Alert Audio
- Addon Icon Artwork

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

## Communities (79 total, 16 thin omitted)

### Community 0 - "Config Panel Controls"
Cohesion: 0.06
Nodes (42): addonTable.Combat.ClearConsumableUsage(), Helpers.CreateColorPicker(), Helpers.CreateColorSwatch(), Helpers.CreateFontDropdown(), Helpers.CreateResetAllButton(), Helpers.CreateResetButton(), Helpers.CreateSectionHeader(), Helpers.CreateTextureDropdown() (+34 more)

### Community 1 - "Puzzle Game Windows"
Cohesion: 0.06
Nodes (58): addonTable.ConfigSetup.AddonVersions(), addonTable.Blocks.ShowGame(), addonTable.Bombs.CloseGame(), addonTable.Bombs.ShowGame(), ChordReveal(), GetCellButton(), ToggleFlag(), UpdateCell() (+50 more)

### Community 2 - "Falling Blocks Game"
Cohesion: 0.09
Nodes (52): addonTable.Blocks.CloseGame(), AnnounceGameStart(), BuildCellFrame(), BuildOppBoard(), BuildStartPayload(), CancelInvite(), DecodeBoard(), EncodeBoard() (+44 more)

### Community 3 - "Notifications and Quest Alerts"
Cohesion: 0.06
Nodes (45): addonTable.Core.SafeAfter(), addonTable.Core.SpeakTTS(), AddIDLine(), AddSpellID(), ApplyAHFilter(), ApplyUIScale(), ApplyWorkOrderFilter(), CheckForPersonalOrders() (+37 more)

### Community 4 - "Destroy and Event Dispatch"
Cohesion: 0.08
Nodes (48): BuildMacroText(), CreateWindow(), Destroy.ApplyVisuals(), Destroy.ShowWindow(), Destroy.UpdateSettings(), EscapePattern(), EvaluateItem(), GetExcludedItems() (+40 more)

### Community 5 - "Warehouse Inventory Management"
Cohesion: 0.09
Nodes (48): Helpers.ApplyFrameBackdrop(), BuildMailQueue(), CalculateOverflowDeficit(), CreatePopupFrame(), EnsureDB(), FindEmptyBagSlot(), FindItemSlots(), FindOnMerchant() (+40 more)

### Community 6 - "Damage Meter Rendering"
Cohesion: 0.08
Nodes (41): AcquireRow(), AcquireSessMenuBtn(), addonTable.DamageMeter.Initialize(), addonTable.DamageMeter.ResetData(), addonTable.DamageMeter.UpdateSettings(), ApplyBackdrop(), ApplyDeathTooltip(), ApplyPositionAndSize() (+33 more)

### Community 7 - "Talent Alerts and Communication"
Cohesion: 0.09
Nodes (35): CleanupRecentMessages(), Comm.GetChannel(), Comm.IsAllowed(), Comm.Send(), Dispatch(), HasRealGroupMembers(), OnAddonMessage(), ShouldProcess() (+27 more)

### Community 8 - "Combat Timers and Reminders"
Cohesion: 0.08
Nodes (34): addonTable.Combat.ApplyLogFrameEvents(), addonTable.Combat.ApplyReminderEvents(), addonTable.Combat.ApplyTimerEvents(), addonTable.Combat.CheckCombatLogging(), addonTable.Combat.UpdateReminders(), addonTable.Combat.UpdateSettings(), ApplyReminderEvents(), ApplyReminderLock() (+26 more)

### Community 9 - "Minimap and Drawer"
Cohesion: 0.09
Nodes (28): AnchorQueueEyeToMinimap(), ApplyDrawerLockVisuals(), ApplyMinimapShape(), ApplyThreeSidedBorder(), CollectMinimapButtons(), EnsureBorderTextures(), HideDefaultDecorations(), IsDrawerOnRightSide() (+20 more)

### Community 10 - "Buff Alert Rules"
Cohesion: 0.13
Nodes (34): BuffAlerts.AddCustomSound(), BuffAlerts.FindSpellMatches(), BuffAlerts.GetSoundLabel(), BuffAlerts.GetSoundOptions(), BuffAlerts.GetStatus(), BuffAlerts.IndexEncounterJournal(), BuffAlerts.MigrateLegacySounds(), BuffAlerts.Refresh() (+26 more)

### Community 11 - "Talent Build Management"
Cohesion: 0.12
Nodes (28): Helpers.DeepCopy(), AnchorToTalentFrame(), CreateMainPanel(), DecodeImportString(), EnsureEJCache(), FindInstanceInCache(), GetOrCreateAddEditFrame(), GetOrCreateImportExportFrame() (+20 more)

### Community 12 - "Player and Target Castbars"
Cohesion: 0.12
Nodes (29): ApplyBarColor(), ApplyBlizzBarVisibility(), ApplyBorders(), ApplyTargetBarColor(), CastBar.ApplyEvents(), CastBar.HideBlizzardCastBar(), CastBar.RestoreBlizzardCastBar(), CastBar.UpdateSettings() (+21 more)

### Community 13 - "Core Initialization and Frames"
Cohesion: 0.09
Nodes (19): ApplyDefaults(), CharacterRegistry.Delete(), CharacterRegistry.GetAll(), CharacterRegistry.GetAllKeys(), CharacterRegistry.Register(), DeepCopy(), EnsureCharDB(), OnEvent() (+11 more)

### Community 14 - "Mythic Plus Timer"
Cohesion: 0.17
Nodes (30): ApplyLayout(), CheckForChallengeMode(), CompleteChallenge(), CreateBar(), DisableChallengeMode(), EnableChallengeMode(), FormatTime(), FormatTimeSigned() (+22 more)

### Community 15 - "WoW API Reference"
Cohesion: 0.10
Nodes (30): Addon Metadata and Versions, Blizzard Global Frames, Class Colors, Combat and Spell APIs, Currency and Weekly Rewards, Encounter Journal, AddonComm, EventBus (+22 more)

### Community 16 - "Loot Toasts and Highlights"
Cohesion: 0.13
Nodes (25): AcquireToast(), GetEquippedIlvlForSlots(), GetOrCreateOverlay(), IsDuplicate(), IsIlvlUpgrade(), Loot.ApplyBagHighlightEvents(), Loot.ApplyEvents(), Loot.RecycleToast() (+17 more)

### Community 17 - "Waypoint Management"
Cohesion: 0.15
Nodes (27): AcquireRow(), ActiveWaypointStillCurrent(), BuildZoneCache(), CheckActiveWaypointStolen(), ClearActiveWaypoint(), Coordinates.AddWaypoint(), Coordinates.ApplyWayCommand(), Coordinates.ClearAllWaypoints() (+19 more)

### Community 18 - "Interrupt Tracking"
Cohesion: 0.16
Nodes (26): AnchorToBlizzFrame(), CreateAttachedFrame(), CreateAttachedIcon(), CreatePartyContainer(), CreatePartyFrame(), CreateSpellRow(), FindUnitFrame(), GetIconSize() (+18 more)

### Community 19 - "Reagent Inventory Tracking"
Cohesion: 0.17
Nodes (25): AddReagentLinesToTooltip(), DisableEvents(), DoFullCharacterScan(), DoWarbandScan(), EnableEvents(), EnsureDB(), GetAllCharCounts(), GetCharacterClass() (+17 more)

### Community 20 - "Documented Project Architecture"
Cohesion: 0.10
Nodes (22): AddonComm LunaUI message bus, LunaUITweaks architecture, LunaUITweaksAPI companion panel registration, Shared ConfigHelpers control factories, Charcoal-and-mint ConfigTheme, Core initialization and recursive defaults, EventBus centralized event dispatcher, Lazy configuration initialization (+14 more)

### Community 21 - "Snake Game Controls"
Cohesion: 0.16
Nodes (17): LunaUITweaks_Game_Left(), LunaUITweaks_Game_Pause(), LunaUITweaks_Game_Right(), LunaUITweaks_Game_RotateCCW(), LunaUITweaks_Game_RotateCW(), MoveDown(), MoveLeft(), MoveRight() (+9 more)

### Community 22 - "Card Game Dragging"
Cohesion: 0.20
Nodes (14): BuildCardFrame(), BuildMiniCardFrame(), CancelDrag(), CommitDrag(), CreateDeck(), Deal(), EnsureDragGhosts(), GetDragCards() (+6 more)

### Community 23 - "Widget Layout and Updates"
Cohesion: 0.23
Nodes (14): EvaluateCondition(), OnConditionEvent(), RebuildAnchorCache(), StartWidgetTicker(), StopWidgetTicker(), UpdateAnchoredLayouts(), Widgets.EstimateRatingGain(), Widgets.EstimateTimedScore() (+6 more)

### Community 24 - "Addon Version Sharing"
Cohesion: 0.30
Nodes (10): AddonVersions.BroadcastPresence(), AddonVersions.RefreshVersions(), BroadcastVersion(), BuildMessage(), GetPlayerKeystone(), GetPlayerName(), OnGroupRosterUpdate(), RequestVersions() (+2 more)

### Community 25 - "Box Puzzle Controls"
Cohesion: 0.29
Nodes (11): BoxesIsOpen(), BoxesIsPaused(), CellColor(), LunaUITweaks_Game_Left(), LunaUITweaks_Game_Pause(), LunaUITweaks_Game_Right(), LunaUITweaks_Game_RotateCCW(), LunaUITweaks_Game_RotateCW() (+3 more)

### Community 26 - "Teleport Menu"
Cohesion: 0.30
Nodes (12): AcquireButton(), AcquireSecureButton(), AddDirectSpellButton(), AddMenuButton(), ClearMainPanel(), ClearSubPanel(), GetTeleportDestFromTooltip(), IsSpellKnownByName() (+4 more)

### Community 27 - "Vendor Automation"
Cohesion: 0.31
Nodes (11): addonTable.Vendor.UpdateSettings(), ApplyVendorEvents(), AutoRepair(), CheckBagSpace(), CheckDurability(), OnBagUpdateDelayed(), OnMerchantShow(), OnPlayerLogin() (+3 more)

### Community 28 - "Group Management"
Cohesion: 0.28
Nodes (10): ApplyRaidAssignments(), GetRaidRole(), OnGroupRosterUpdate(), OnReadyCheck(), PlanRaidMoves(), RefreshGroupCache(), RefreshReadyCheckNames(), SortHealersToLast() (+2 more)

### Community 29 - "Experience Bar"
Cohesion: 0.33
Nodes (12): addonTable.XpBar.UpdateSettings(), ApplyBlizzardBarVisibility(), FormatTime(), GetMentorBonus(), GetPendingQuestXP(), GetXPBonusPct(), Init(), OnEnteringWorld() (+4 more)

### Community 30 - "Compact Group Finder"
Cohesion: 0.35
Nodes (11): CompactEntry(), CompactGroupFinder.UpdateSettings(), DefaultRowHeight(), DesiredRowHeight(), GetScrollBox(), HideSupplementalDisplay(), InstallHooks(), RefreshVisibleEntries() (+3 more)

### Community 31 - "Performance Profiler"
Cohesion: 0.25
Nodes (7): BuildDisplayFrame(), FormatTime(), pack(), Profiler.Toggle(), SpikeColor(), timingExec(), UpdateDisplay()

### Community 32 - "Hearthstone Selection"
Cohesion: 0.36
Nodes (10): BuildOwnedList(), FormatCooldown(), GetAnyHearthstoneID(), GetCooldownRemaining(), GetRandomHearthstoneID(), OnHearthEnteringWorld(), OnHearthUpdate(), RefreshCooldownText() (+2 more)

### Community 33 - "Keystone Teleports"
Cohesion: 0.25
Nodes (6): BuildTeleportMap(), FindTeleportForDungeon(), GetDungeonNameVariants(), GetKeystoneInfo(), GetPlayerKeystone(), UpdateTeleportButton()

### Community 34 - "Session Statistics"
Cohesion: 0.33
Nodes (7): FormatDuration(), FormatGoldPerHour(), OnChatMsgLoot(), OnPlayerDead(), OnSessionEnteringWorld(), SaveSessionData(), UpdateCachedText()

### Community 35 - "Ready Check Tracking"
Cohesion: 0.53
Nodes (8): GetPlayerShortName(), GetShortName(), OnReadyCheck(), OnReadyCheckFinished(), OnReadyCheckResponse(), PopulateGroupMembers(), RefreshNameCache(), UpdateCachedText()

### Community 36 - "Queue Timer"
Cohesion: 0.43
Nodes (6): addonTable.QueueTimer.UpdateSettings(), GetProposalTimeLeft(), Init(), OnUpdate(), StartTimer(), StopTimer()

### Community 37 - "Currency Tracker"
Cohesion: 0.48
Nodes (5): AcquireRow(), GetActiveCurrencyList(), GetCurrencyData(), ReleaseAllRows(), UpdateCurrencyPanel()

### Community 38 - "Pull Countdown"
Cohesion: 0.48
Nodes (5): CancelChatCountdown(), CancelPull(), DoChatCountdown(), GetBackend(), StartPull()

### Community 39 - "Config Visual Theme"
Cohesion: 0.47
Nodes (3): Surface(), Theme.SkinTree(), Theme.Window()

### Community 41 - "Mail Tracking"
Cohesion: 0.60
Nodes (5): OnMailClosed(), OnMailShow(), OnMailUpdate(), RefreshMailCache(), ScanInbox()

### Community 42 - "Darkmoon Faire Calendar"
Cohesion: 0.70
Nodes (4): FormatCountdown(), GetDMFInfo(), OnDMFEvent(), RefreshDMFCache()

### Community 43 - "Instance Lockouts"
Cohesion: 0.60
Nodes (3): OnLockoutEnteringWorld(), OnLockoutUpdate(), RefreshLockoutCache()

### Community 44 - "Encounter Pull Counter"
Cohesion: 0.70
Nodes (4): OnEncounterEnd(), OnEncounterStart(), OnPullCounterEnteringWorld(), RefreshCache()

### Community 46 - "Proposed Feature Roadmap"
Cohesion: 0.50
Nodes (4): Proposed group buff consumable checker, Future feature ideas baseline April 2026, Proposed buff consumable checker widget, Widget ideas and improvements baseline

### Community 47 - "Communication Status Widget"
Cohesion: 0.83
Nodes (3): GetGroupSize(), OnGroupUpdate(), UpdateCachedText()

### Community 49 - "Mythic Rating Widget"
Cohesion: 0.83
Nodes (3): OnRatingEnteringWorld(), OnRatingUpdate(), RefreshRatingCache()

### Community 50 - "Vault Widget"
Cohesion: 0.83
Nodes (3): OnVaultEnteringWorld(), OnVaultUpdate(), RefreshVaultCache()

### Community 52 - "Experience Reputation Widget"
Cohesion: 0.83
Nodes (3): OnXPRepEnteringWorld(), OnXPRepUpdate(), RefreshCache()

## Knowledge Gaps
- **18 isolated node(s):** `Class Colors`, `Encounter Journal`, `Group and Social APIs`, `Quest and Objective Tracking`, `UIThingsDB saved module settings` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 194 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `addonTable.ConfigSetup.AddonVersions()` connect `Puzzle Game Windows` to `Config Panel Controls`, `Talent Alerts and Communication`?**
  _High betweenness centrality (0.211) - this node is a cross-community bridge._
- **Why does `addonTable.Core.Log()` connect `Talent Alerts and Communication` to `Config Panel Controls`, `Puzzle Game Windows`, `Combat Timers and Reminders`, `Core Initialization and Frames`, `Interrupt Tracking`, `Group Management`?**
  _High betweenness centrality (0.162) - this node is a cross-community bridge._
- **Why does `addonTable.Config.Initialize()` connect `Config Panel Controls` to `Combat Timers and Reminders`, `Puzzle Game Windows`, `Buff Alert Rules`, `Experience Bar`?**
  _High betweenness centrality (0.157) - this node is a cross-community bridge._
- **Are the 28 inferred relationships involving `addonTable.Config.Initialize()` (e.g. with `addonTable.Combat.UpdateSettings()` and `addonTable.DamageMeter.SetLocked()`) actually correct?**
  _`addonTable.Config.Initialize()` has 28 INFERRED edges - model-reasoned connections that need verification._
- **Are the 23 inferred relationships involving `Helpers.UpdateModuleVisuals()` (e.g. with `addonTable.ConfigSetup.CastBar()` and `addonTable.ConfigSetup.Combat()`) actually correct?**
  _`Helpers.UpdateModuleVisuals()` has 23 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `Helpers.CreateResetButton()` (e.g. with `addonTable.ConfigSetup.BuffAlerts()` and `addonTable.ConfigSetup.CastBar()`) actually correct?**
  _`Helpers.CreateResetButton()` has 22 INFERRED edges - model-reasoned connections that need verification._
- **Are the 20 inferred relationships involving `Helpers.CreateSectionHeader()` (e.g. with `addonTable.ConfigSetup.CastBar()` and `addonTable.ConfigSetup.Combat()`) actually correct?**
  _`Helpers.CreateSectionHeader()` has 20 INFERRED edges - model-reasoned connections that need verification._
## Extraction Limitations

- Token counts of 0 are placeholders: host-agent usage is unavailable, not zero-cost semantic extraction. No external LLM API was used.
- Five OGG files were not transcribed because faster-whisper is unavailable.
- Three WoW TOC manifests produced parser errors; manifest load-order relationships are incomplete.
- Five opposite-direction edge pairs collapsed in the default undirected graph; no dangling endpoints, missing endpoints, or self-loops were found.
- Documentation includes historical proposals and potentially stale API claims; those are documentation evidence, not verified runtime behavior.
