# Daily Goals Tracker

A native macOS menu bar app for tracking daily goals with visual status indicators, custom day modes, and big-picture planning.

![Menu Bar App](https://img.shields.io/badge/macOS-14.0+-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-orange)

## Features

- **Menu Bar Integration** — Lives in your status bar for quick access
- **Three Status States** — Mark goals as Done (●), Partial (◐), or Not Done (○)
- **Visual-First Design** — Icons and colors for quick scanning
- **Multiple Views**:
  - **Day** — Today's goals with progress and day-mode chips
  - **Week** — 7-day grid for weekly patterns
  - **Month** — Calendar heat-map of consistency (special days tinted by mode)
  - **Plan** — Big-picture goals for the week, month, year, and life
- **Dynamic Day Modes** — Create modes (Fasting, Trip, Sick, Rest, or your own) and choose which goals count in each
- **Goal Management** — Add, edit, reorder, and toggle goals on/off
- **Streak Tracking** — Current streak of days that met their mode's target
- **Global Hotkey** — `Cmd+Shift+Y` toggles the popover from anywhere

## Quick Start

### Option 1: Run the Pre-built App
1. Double-click `DailyGoalsTracker.app` in this folder
2. Look for the checklist icon in the menu bar
3. Click it to open the tracker

### Option 2: Build from Source
1. Open `DailyGoalsTracker.xcodeproj` in Xcode
2. Press `Cmd+R` to build and run

Or build from the terminal — see [Build command](#build-command) below.

## Usage

### Tracking Goals
- **Click** the status circle to cycle: Not Done → Partial → Done
- Use the **Day / Week / Month / Plan** tabs to switch views
- Click **Today** to jump back to the current date
- On Day view, pick a **mode chip** (Normal, Fasting, etc.) — only goals assigned to that mode are tracked

### Settings (gear icon)
Settings has two panels:

#### Goals
1. **Add** with the + button
2. **Reorder** by dragging the handle
3. **Toggle** goals on/off with the switch
4. **Edit / delete** with the pencil / trash buttons on hover

#### Modes
1. Switch to the **Modes** panel
2. **Add** custom modes with name, short label, icon, and color
3. **Edit** a mode to choose which goals are accepted for that day type
4. **Reorder** or **delete** modes (Normal always tracks all active goals and cannot be deleted)
5. Unchecked goals are skipped when that mode is selected for a day

### Keyboard Shortcuts
- `Cmd+Shift+Y` — Toggle the popover (change in `AppDelegate.swift` → `setupGlobalHotKey()`, then rebuild)
- Right-click the menu bar icon for today's quick stats and Quit

## Data Storage

Everything is stored locally at:

```
~/Library/Application Support/DailyGoalsTracker/
├── goals.json           # Goal definitions
├── entries.json         # Daily status entries
├── planning_goals.json  # Week / month / year / life goals
├── day_modes.json       # Custom day modes + accepted goals per mode
└── day_records.json     # Which mode each calendar day used
```

## Sample Goals Included

On first launch the app seeds 8 sample goals:
- Exercise, Read, Meditate, Healthy Eating
- Learn Something New, Connect with Family
- Work on Side Project, Drink Water

Default modes: **Normal**, **Fasting**, **On Trip**, **Sick Day**, **Rest Day**. You can edit or replace them anytime.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (for building from source)

## Tips

1. Start with 3–5 goals and grow from there
2. Use Partial when you did something but not everything
3. Configure modes so travel / fasting / rest days only track what still matters
4. Check Week and Month views for patterns over time

## Customization

Goals and modes use SF Symbol icons. Common choices:
- `figure.run` — Exercise
- `book.fill` — Reading
- `brain.head.profile` — Mental health
- `drop.fill` — Hydration
- `moon.fill` / `moon.stars.fill` — Sleep / fasting
- `airplane` — Travel
- `leaf.fill` — Rest

---

Made for personal daily use. Track habits, build consistency, achieve your goals.

## Build command

The app is **not** installed in `/Applications` by default. It runs from `DailyGoalsTracker.app` inside this project folder.

Rebuild, replace the app, and relaunch:

```bash
xcodebuild -project DailyGoalsTracker.xcodeproj \
  -scheme DailyGoalsTracker \
  -configuration Debug \
  -derivedDataPath .build build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" \
&& pkill -f DailyGoalsTracker; \
rm -rf DailyGoalsTracker.app \
&& cp -R .build/Build/Products/Debug/DailyGoalsTracker.app . \
&& open DailyGoalsTracker.app
```

Build output goes to `.build/` (~125 MB). Delete anytime with `rm -rf .build`.

### Optionally install to /Applications

```bash
pkill -f DailyGoalsTracker; \
rm -rf /Applications/DailyGoalsTracker.app \
&& cp -R DailyGoalsTracker.app /Applications/ \
&& open /Applications/DailyGoalsTracker.app
```

Goals and history live in `~/Library/Application Support/`, so moving the app does not erase your data.
