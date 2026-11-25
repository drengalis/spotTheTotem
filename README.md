# Spot the Totem

A World of Warcraft: Forever addon that puts each totem's spell icon on its nameplate, so totems are easy to see and pick out in a fight.

## Features

- Spell icon on every shaman totem's nameplate, with a red border for enemy totems and green for friendly ones
- Countdown timer on each icon: white, then yellow under 10 seconds, red under 5
  - Exact for your own totems; other players' totems use WoW Forever's standard durations
- Separate settings for enemy and friendly totems:
  - Turn spotting on or off
  - Turn the game's minion nameplates on or off (totems need these)
  - Icon size (16–128 px)
  - Horizontal and vertical offset for the icon
  - "Only spot selected totems", with a checkbox list of every totem grouped by element
- Option to hide the totem's health bar so only the icon shows
- Minimap button: left-click for settings, right-click to turn the addon on or off, drag to move

Only totems that exist in WoW Forever are listed. Fire Nova Totem (now the Fire Nova spell), Tranquil Air Totem and Burning Crusade totems are not included.

## Requirements

Minion nameplates must be on for totem icons to show. Use the minion nameplate checkboxes in the addon's settings, or the game's nameplate options.

Friendly nameplates can't be changed by addons inside dungeons and raids, so friendly totem icons won't show there. Enemy totems work everywhere.

## Installation

Copy the `SpotTheTotem` folder to:

```
World of Warcraft\_forever_\Interface\AddOns\SpotTheTotem
```

## Slash commands

| Command | Action |
|---|---|
| `/stt` | Open settings |
| `/stt toggle` | Turn the addon on or off |
| `/stt enemy` / `/stt friendly` | Turn enemy or friendly totem icons on or off |
| `/stt timer` | Turn the countdown timer on or off |
| `/stt size [enemy\|friendly] <16-128>` | Set icon size (both sides if none given) |
| `/stt hoffset [enemy\|friendly] <-100 to 100>` | Set the horizontal offset (both sides if none given) |
| `/stt voffset [enemy\|friendly] <-50 to 100>` | Set the vertical offset (both sides if none given) |
| `/stt durations` | Compare the addon's totem durations with the game's tooltips |
| `/stt minimap` | Show or hide the minimap button |
| `/stt reset` | Reset all settings |

## Releasing

Releases are published automatically. Bump `## Version:` in `SpotTheTotem.toc`, add `release-notes/vX.Y.Z.md`, and push to `main`. The Release workflow then creates the `vX.Y.Z` tag, builds `SpotTheTotem-vX.Y.Z.zip`, and publishes the release.
