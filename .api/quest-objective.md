# Quest & Objective Tracking APIs

APIs for reading quest state, managing super-tracking, gossip interaction, and content tracking.

---

## C_QuestLog

### C_QuestLog.GetLogIndexForQuestID
```lua
local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
```
Returns the quest log index for a given quest ID, or `nil` if not in the log.

### C_QuestLog.GetInfo
```lua
local info = C_QuestLog.GetInfo(logIndex)
-- info.title, info.questID, info.isHeader, info.isCollapsed, info.isComplete,
-- info.frequency, info.isTask, info.isBounty, info.numObjectives,
-- info.startEvent, info.isAutoComplete, info.overridesSortOrder,
-- info.readyForTranslation, info.hasLocalPOI, info.isHidden,
-- info.isScaling, info.level, info.suggestedGroup, info.difficultyLevel,
-- info.campaignID, info.isQuestHelpful, info.hasDailies
```
Returns a table of quest info for the given log index. Returns `nil` if the index is invalid.

### C_QuestLog.RemoveQuestWatch
```lua
C_QuestLog.RemoveQuestWatch(questID)
```
Removes a quest from the watch list (objective tracker).

### C_QuestLog.IsComplete
```lua
local isComplete = C_QuestLog.IsComplete(questID)
```
Returns true if the quest is complete.

### C_QuestLog.SetSelectedQuest
```lua
C_QuestLog.SetSelectedQuest(questID)
```
Sets the currently selected quest in the quest log.

### C_QuestLog.IsPushableQuest
```lua
local isPushable = C_QuestLog.IsPushableQuest(questID)
```
Returns true if the quest can be shared with group members.

### C_QuestLog.IsQuestTrivial
```lua
local isTrivial = C_QuestLog.IsQuestTrivial(questID)
```
Returns true if the quest is grey (trivial level) for the player.

### C_QuestLog.IsQuestFlaggedCompleted
```lua
local isCompleted = C_QuestLog.IsQuestFlaggedCompleted(questID)
```
Returns true if the quest has been completed (even if not currently in log). Useful for one-time event tracking (e.g. Darkmoon Faire widgets).

### GetQuestLink / GetQuestLogSpecialItemInfo
```lua
local link = GetQuestLink(questID)
local itemLink, itemIcon, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
```

---

## C_SuperTrack

Manages the "super tracked" quest — the one shown with the arrow/route on screen.

### C_SuperTrack.GetSuperTrackedQuestID
```lua
local questID = C_SuperTrack.GetSuperTrackedQuestID()
```
Returns the currently super-tracked quest ID, or 0/nil if none.

### C_SuperTrack.SetSuperTrackedQuestID
```lua
C_SuperTrack.SetSuperTrackedQuestID(questID)
```
Sets a quest as super-tracked. Pass 0 to clear.

**Caveat:** Calling this will fire `SUPER_TRACKING_CHANGED`. If your code listens for that event and calls this in response, guard against infinite loops with a flag.

### C_SuperTrack.ClearAllSuperTracked
```lua
C_SuperTrack.ClearAllSuperTracked()
```
Clears the super-tracked quest entirely.

**ObjectiveTracker.lua pattern:** The addon saves and restores the super-tracked quest ID across reloads to work around Blizzard resetting it.

---

## C_ContentTracking

```lua
C_ContentTracking.StopTracking(trackableType, trackableID, userRequested)
```
Stops tracking a piece of content (achievements, perks activities, etc.) in the objective tracker.

---

## C_PerksActivities

```lua
C_PerksActivities.RemoveTrackedPerksActivity(activityID)
```
Removes a Trader's Tender / Perks activity from the objective tracker.

---

## C_GossipInfo

Used by QuestAuto.lua to auto-interact with NPCs.

```lua
local options = C_GossipInfo.GetOptions()
-- options[i].gossipOptionID, options[i].name, options[i].icon, options[i].type, options[i].isTrivial, options[i].status

local numActive = C_GossipInfo.GetNumActiveQuests()
local activeQuests = C_GossipInfo.GetActiveQuests()

local numAvailable = C_GossipInfo.GetNumAvailableQuests()
local availableQuests = C_GossipInfo.GetAvailableQuests()

C_GossipInfo.SelectActiveQuest(index)
C_GossipInfo.SelectAvailableQuest(index)
C_GossipInfo.SelectOption(gossipOptionID [, text [, confirmed]])
```

**Caveats:**
- These APIs are only valid while a gossip window is open (after `GOSSIP_SHOW` event).
- Calling them outside of a gossip context returns empty/nil.
- Auto-accepting quests via these APIs can spam quest toasts if not rate-limited.

---

## Quest Log Legacy Globals

```lua
QuestLogPushQuest()        -- share current quest with group
ShowQuestComplete()        -- show quest completion dialog
ToggleQuestLog()           -- open/close quest log UI
GetNumActiveQuests()       -- number of active quests in current gossip (legacy)
```

---

## Relevant Events

| Event | Description |
|---|---|
| `QUEST_LOG_UPDATE` | Quest log changed (quests added, removed, objectives updated) |
| `SUPER_TRACKING_CHANGED` | Super-tracked quest or content changed |
| `PLAYER_ENTERING_WORLD` | Safe to read quest state after zone transition |
| `QUEST_WATCH_LIST_CHANGED` | Watched quests list changed |
| `QUEST_TURNED_IN` | Quest was completed and turned in |
| `QUEST_ACCEPTED` | New quest accepted |
| `GOSSIP_SHOW` | NPC gossip window opened |
| `GOSSIP_CLOSED` | NPC gossip window closed |
| `QUEST_GREETING` | NPC quest greeting dialog opened |
