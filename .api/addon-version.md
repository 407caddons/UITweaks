# Addon & Version APIs

APIs for reading addon metadata, checking load state, and build information.

---

## C_AddOns

### C_AddOns.GetAddOnMetadata
```lua
local value = C_AddOns.GetAddOnMetadata(addonName, field)
```
Reads a field from an addon's `.toc` file.

**Common fields:**
- `"Version"` — the `## Version:` field (e.g. `"0.15"`)
- `"Title"` — the `## Title:` field
- `"Author"` — the `## Author:` field
- `"Notes"` — the `## Notes:` field
- `"Interface"` — the `## Interface:` TOC version (e.g. `"120000"`)
- `"X-*"` — any custom `## X-MyField:` value

**Used in:** Core.lua (version display), AddonVersions.lua (broadcasting version to group), TalentManager.lua.

**Caveat:** Returns `nil` if the addon is not loaded or the field doesn't exist. Always check for nil before use.

**This addon's version field:**
```lua
local version = C_AddOns.GetAddOnMetadata("LunaUITweaks", "Version")
```

### C_AddOns.IsAddOnLoaded
```lua
local loaded, finished = C_AddOns.IsAddOnLoaded(addonName)
```
- `loaded` — true if the addon's code has been executed
- `finished` — true if the addon has fully initialised

**Used in:** ActionBars.lua (checking if WeakAuras or other addons are present), widgets/PullTimer.lua (checking for DBM/BigWigs).

### C_AddOns.GetNumAddOns / C_AddOns.GetAddOnInfo
```lua
local numAddOns = C_AddOns.GetNumAddOns()
local name, title, notes, loadable, reason, security, newVersion =
    C_AddOns.GetAddOnInfo(indexOrName)
```
Used in widgets/FPS.lua to count/list loaded addons.

---

## GetBuildInfo

```lua
local version, build, date, tocVersion = GetBuildInfo()
```
- `version` — game version string, e.g. `"12.0.2"`
- `build` — build number string, e.g. `"56162"`
- `date` — build date string
- `tocVersion` — numeric TOC version, e.g. `120002`

Used in TalentManager.lua for version-gating features.

---

## AddonVersions Module Pattern

`AddonVersions.lua` broadcasts the addon version to group members via AddonComm and collects responses:

```lua
-- On login or group join: broadcast version
Comm.Send("VER", "HELLO", myVersion)

-- On request: respond with version
Comm.Register("VER", "REQ", function(sender, payload)
    Comm.Send("VER", "HELLO", myVersion)
end)

-- On receiving a version: store and display
Comm.Register("VER", "HELLO", function(sender, version)
    versionData[sender] = version
    UpdateDisplay()
end)
```

---

## Relevant Events

| Event | Description |
|---|---|
| `ADDON_LOADED` | Args: `(addonName)` — fires when each addon finishes loading |
| `PLAYER_LOGIN` | All addons loaded; safe to read full addon list |
