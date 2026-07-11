# Completion Tracker Mod

A Payday 2 mod that helps you track your completion status across different game elements.

## Features

- **Contract Broker**: Shows completed heists in the contract broker with a green color indicator for DSOD (one-down) completions
- **Crime.net**: Colors completed heists in Crime.net with a green color indicator for DSOD completions  
- **Black Market**: Shows owned weapons and masks with visual indicators:
  - Icons indicating ownership
  - Green borders around owned items

## Installation

1. Place the `CompletionTracker` folder in your `mods` directory
2. Enable the mod in the BLT menu

## Configuration

The mod can be configured through the settings menu:
- `show_icons`: Show icons for owned weapons/masks (default: false)
- `show_borders`: Show green borders around owned items (default: true)
- `show_heist_completion`: Show completion status on Crime.net (default: true)
- `show_contract_completion`: Show completion status in contract broker (default: true)

## Compatibility

This mod is compatible with Payday 2 and requires BLT (Better Lua Toolkit) to be installed.

## Changelog

### Version 1.1.1
- Improved contract broker completion tracking
- Enhanced Crime.net completion detection
- Better initialization handling for all GUI elements
- Fixed potential issues with hooking into game elements

### Version 1.0.0
- Initial release
- Basic completion tracking for contracts, heists, and black market items