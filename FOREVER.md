# WoW Forever

LunaUITweaks supports the Forever/Camelot 1.60.1 client (interface 16001).

## Installation

Copy these folders into your Forever installation's `Interface/AddOns` folder:

- `LunaUITweaks`
- `LunaUITweaks_Config`
- `LunaUITweaks_Games` (optional)

The ZIP packages all three as sibling folders. Do not put the Config/Games
folders inside the installed LunaUITweaks folder. The client selects each
`_Camelot.toc`; the existing Retail TOCs and behavior remain available.
Completely restart WoW after installing the new TOCs.

Use `/luit` for settings, `/lunalayout` for positions, and `/luit compat` to print
the detected client/interface/build and key API availability when reporting bugs.
Disable other addons first so errors can be attributed to Luna.

## Included

General UI/minimap options, Layout Mode, vendor tools, loot toasts, quest tools,
coordinates, cast bars, XP/reputation displays, basic widgets, aura/proc sound
rules, cursor ring, container opening, collection unwrapping, damage meter,
cooldown-manager layouts, addon communication, generic encounter/pull/break
and custom timers, and inventory-count tooltips.

Spell/aura rules need Forever spell IDs; Retail rules are not automatically
converted. Some general UI options target Retail-style frames.

## Unavailable on Forever

- Talent Manager, automatic talent changes/reminders, and specialization widget.
  Use Blizzard's Forever talents directly for now.
- Mythic+ timer, keystones, seasonal dungeon teleports, Mythic rating and Vault.
- Retail automatic queue timer and compact group-finder modifications.
- Automatic bank/mail stock transfers and gear-upgrade suggestions.
- Tank-debuff displays and Retail consumable/class reminders/automatic logging.
- Retail movement/Time Spiral/Gateway/shared battle-res charge alerts.
- Mastery, Versatility, Retail PvP and DMF WHEE widgets.
- Retail encounter timeline replacement (manual pull/break timers remain).

Unavailable pages explain the restriction; unavailable widgets are omitted from
widget configuration.

## Settings and storage

Forever has its own WTF directory, separate from Retail. Do not copy Retail WTF
settings into it. New settings exports identify the client. Forever accepts Retail and older untagged exports on a best-effort basis: compatible settings and loaded companions (including Action Bars) are imported. Unsupported Retail systems, Retail talent/quest reminders and unavailable companions are skipped and listed before confirmation. Retail still rejects Forever exports. Talent build export remains disabled on Forever until its backend is adapted.

Carried bags are discovered without assuming a fifth reagent bag. Inventory-count
tooltips use Forever's reported purchased bank container IDs and preserve cached
bank counts when bank data cannot be read. Automated transfers remain disabled.

## Reporting problems

Report the first Lua error, what triggered it, and `/luit compat` output. Reload
before reproducing a later error if the first error interrupted initialization.
