# Talent & Spec APIs

APIs for reading the player's current specialization, talents, and build information.

---

## GetSpecialization

```lua
local specIndex = GetSpecialization([isInspect [, isPet [, groupIndex]]])
```
Returns the player's current active specialization index (1–4, or 0 if no spec selected). For `"player"` unit, call with no args.

---

## GetSpecializationInfo

```lua
local id, name, description, icon, role, primaryStat =
    GetSpecializationInfo(specIndex [, isInspect [, isPet [, inspectUnit [, sex]]]])
```
- `id` — spec ID (numeric, unique across all classes)
- `name` — localized spec name
- `role` — `"TANK"`, `"HEALER"`, `"DAMAGER"`
- `primaryStat` — 1=Strength, 2=Agility, 3=Intelligence

**Used in:** TalentReminder.lua for zone-based spec change alerts, widgets/Spec.lua for displaying current spec.

---

## C_SpecializationInfo

### C_SpecializationInfo.GetAllSelectedTalentIDs
```lua
local talentIDs = C_SpecializationInfo.GetAllSelectedTalentIDs()
```
Returns an array of all currently selected talent spell IDs. Used by TalentManager.lua to detect talent builds.

### C_SpecializationInfo.GetNumSpecializationsForClassID
```lua
local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
```

### C_SpecializationInfo.GetSpecializationInfoForClassID
```lua
local id, name, description, icon, role =
    C_SpecializationInfo.GetSpecializationInfoForClassID(classID, specIndex)
```

---

## PlayerSpellsFrame Integration

`PlayerSpellsFrame` is the Blizzard talent/spellbook UI frame.

**Caveat:** TalentManager.lua interacts with `PlayerSpellsFrame` to detect when the talent UI is open. Do **not** call `SetPoint`, `SetSize`, or write fields onto this frame — it is Blizzard-owned.

---

## TalentReminder Pattern

TalentReminder.lua watches `PLAYER_SPECIALIZATION_CHANGED` and zone change events:

```lua
EventBus.Register("PLAYER_SPECIALIZATION_CHANGED", function(event, unitID)
    if unitID ~= "player" then return end
    -- read new spec and check reminders
end)

EventBus.Register("ZONE_CHANGED_NEW_AREA", function()
    local zone = GetSubZoneText() or GetZoneText()
    -- match zone against user-defined reminders
end)
```

Reminders are stored in `LunaUITweaks_TalentReminders` (separate saved variable, survives settings resets).

---

## Relevant Events

| Event | Description |
|---|---|
| `PLAYER_SPECIALIZATION_CHANGED` | Spec changed; args: `(unitID)` |
| `PLAYER_TALENT_UPDATE` | Talent selections changed |
| `ACTIVE_TALENT_GROUP_CHANGED` | Active talent group/loadout changed |
| `ZONE_CHANGED_NEW_AREA` | New zone entered (trigger reminder check) |
