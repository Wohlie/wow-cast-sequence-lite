# CastSequenceLite

CastSequenceLite is a lightweight, combat-safe rotation helper addon for World of Warcraft. It allows you to create and
manage custom cast sequences with a simple graphical interface, similar to Gnome Sequencer Enhanced (GSE) but
streamlined for basic to intermediate rotations.

## Features

* **Multi-Client Support**: Fully compatible with both Legacy and Modern WoW clients (Retail, Classic Era,
  Cataclysm, ...).
* **GUI Editor**: Create and edit rotations with an intuitive interface.
* **Combat Safe**: Uses `SecureHandlerBaseTemplate` to execute rotations safely in combat.
* **Drag-and-Drop**: Automatically generates macros for your rotations that you can drag directly to your action bars.
* **Smart Targeting**: Configurable auto-targeting options (Always, In Combat, or Never).
* **Combat Reset**: Option to automatically reset the sequence to the first step when leaving combat.
* **Pre-Cast Commands**: Support for off-GCD actions before the main cast (e.g., trinkets, racials).
* **Error Suppression**: Automatically hides "Spell not ready" error messages and suppresses error sounds during
  execution.

## Installation

### Automatic (Recommended)

You can install this addon using [GitAddonsManager](https://woblight.gitlab.io/overview/gitaddonsmanager/).

### Manual

1. Download the latest release.
2. Extract the archive.
3. Move the `CastSequenceLite` folder into your World of Warcraft `Interface\AddOns\` directory.

## Usage

1. Log in to the game.
2. Type `/csl` in the chat to open the Rotation Manager.
3. Click **"+ New Rotation"** to start a new sequence.
4. Fill in the details:
    * **Rotation Name**: A unique name for your macro.
    * **Pre-Cast Commands**: (Optional) Commands to run before the main spell (e.g., `/use 13`, `/use 14`).
    * **Cast Commands**: List your spells one per line.
        * Example:
            ```
            /cast [combat] Blood Fury
            /cast [combat] Berserker Rage
            /cast Victory Rush
            /cast Overpower
            /cast Heroic Strike
            ```
    * **Auto Select Target**: Check this if you want the macro to automatically target the nearest enemy.
    * **Reset After Combat**: Check this to reset the sequence progress when combat ends.
5. Click **Save**.
6. Drag the icon from the list on the left to your action bar.
7. Spam the button to execute your rotation!

## Commands

* `/csl` - Opens the configuration window.

## How it Works

CastSequenceLite creates a secure button for each rotation. When you click the macro on your action bar, it triggers
this secure button. The button uses a secure handler snippet to cycle through your list of spells, checking conditions (
like `[combat]`) dynamically, and updates the macro icon to show the next spell in the sequence.
