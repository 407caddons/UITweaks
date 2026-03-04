# Group & Social APIs

APIs for reading group composition, roster info, and social lists (friends, guild).

---

## Group State

### IsInGroup / IsInRaid
```lua
local inGroup = IsInGroup([groupType])
local inRaid = IsInRaid([groupType])
```
- `groupType` — `LE_PARTY_CATEGORY_HOME` (default) or `LE_PARTY_CATEGORY_INSTANCE`
- `IsInGroup()` returns true for both party and raid groups.
- `IsInRaid()` returns true only when in a raid (5+ members or explicitly converted to raid).

**Used in:** AddonComm.lua, AddonVersions.lua, Kick.lua, TalentReminder.lua, Misc.lua, widgets/Group.lua.

### GetNumGroupMembers
```lua
local numMembers = GetNumGroupMembers([groupType])
```
Returns total group size (including player). Returns 0 when not in a group.

**Note:** The legacy `GetNumRaidMembers()` is deprecated — use `GetNumGroupMembers()`.

### GetRaidRosterInfo
```lua
local name, rank, subgroup, level, class, fileName, zone,
      online, isDead, role, isML, combatRole =
    GetRaidRosterInfo(raidIndex)
```
Returns info for a raid member by index (1–40). Returns `nil` for empty slots.

- `fileName` — uppercase class name (e.g. `"WARRIOR"`)
- `rank` — 0=member, 1=assistant, 2=leader
- `combatRole` — `"TANK"`, `"HEALER"`, `"DAMAGER"`, `"NONE"`

---

## Unit Group APIs

```lua
local isLeader = UnitIsGroupLeader(unitID)
local isAssistant = UnitIsGroupAssistant(unitID)
local name, realm = UnitName(unitID)   -- "party1", "raid3", etc.
local guid = UnitGUID(unitID)
local level = UnitLevel(unitID)
local className, classFilename = UnitClass(unitID)
```

**Iterating party:**
```lua
for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists(unit) then
        -- process party member
    end
end
```

**Iterating raid:**
```lua
for i = 1, 40 do
    local unit = "raid" .. i
    if UnitExists(unit) then
        -- process raid member
    end
end
```

---

## Friend List

### C_FriendList.GetNumFriends / GetNumOnlineFriends
```lua
local total = C_FriendList.GetNumFriends()
local online = C_FriendList.GetNumOnlineFriends()
```

### C_FriendList.GetFriendInfoByIndex
```lua
local info = C_FriendList.GetFriendInfoByIndex(index)
-- info.name, info.className, info.area, info.connected, info.status,
-- info.notes, info.rafLinkType, info.guid
```

### C_FriendList.IsFriend
```lua
local isFriend = C_FriendList.IsFriend(guid)
```
Returns true if the GUID belongs to someone on the player's friend list.

**Used in:** widgets/Friends.lua, widgets/Group.lua (to mark friends in group frames).

---

## BattleNet Friends

```lua
local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
-- accountInfo.battleTag, accountInfo.isFriend, accountInfo.gameAccountInfo.gameID, etc.
```

**Used in:** widgets/Friends.lua to display BattleTag friends.

---

## Guild

### IsInGuild
```lua
local inGuild = IsInGuild()
```

### C_GuildInfo.MemberExistsByName
```lua
local exists = C_GuildInfo.MemberExistsByName(playerName)
```
Returns true if the player name is a guild member. Used in widgets/Group.lua to mark guildmates.

---

## Relevant Events

| Event | Description |
|---|---|
| `GROUP_ROSTER_UPDATE` | Party/raid composition changed |
| `PARTY_LEADER_CHANGED` | Party leader changed |
| `PARTY_MEMBERS_CHANGED` | Party membership changed (legacy, prefer `GROUP_ROSTER_UPDATE`) |
| `RAID_ROSTER_UPDATE` | Raid roster changed (legacy, prefer `GROUP_ROSTER_UPDATE`) |
| `FRIENDLIST_UPDATE` | Friend list updated |
| `BN_FRIEND_LIST_SIZE_CHANGED` | BattleNet friend list changed |
| `GUILD_ROSTER_UPDATE` | Guild roster data updated |
