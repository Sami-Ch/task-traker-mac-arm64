# Daily Goals Tracker

A beautiful native macOS menu bar app for tracking your daily goals with visual status indicators.

![Menu Bar App](https://img.shields.io/badge/macOS-14.0+-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-orange)

## Features

- **Menu Bar Integration** - Lives in your status bar for quick access
- **Three Status States** - Mark goals as Done (●), Partial (◐), or Not Done (○)
- **Visual-First Design** - Icons and colors over text for quick scanning
- **Multiple Views**:
  - **Day View** - Focus on today's goals with progress ring
  - **Week View** - 7-day grid to see your weekly patterns
  - **Month View** - Calendar heat-map showing your consistency
  - **Plan View** - Big-picture goals for the week, month, year, and life
- **Special Days** - Mark a day as fasting, trip, sick, or rest, and only your
  essential goals stay tracked
- **Goal Management** - Add, edit, reorder, and toggle goals on/off
- **Streak Tracking** - See your current streak of perfect days
- **Global Hotkey** - Press `Cmd+Shift+Y` to toggle the popover from anywhere

## Quick Start

### Option 1: Run the Pre-built App
1. Double-click `DailyGoalsTracker.app` in this folder
2. The app will appear in your menu bar (look for the checklist icon ✓)
3. Click the icon to open the goals tracker

### Option 2: Build from Source
1. Open `DailyGoalsTracker.xcodeproj` in Xcode
2. Press `Cmd+R` to build and run
3. The app will appear in your menu bar

Or build from the terminal — see [Build command](#build-command) below.

## Usage

### Tracking Goals
- **Click** the status circle to cycle through: Not Done → Partial → Done
- Use the **Day/Week/Month** tabs to switch views
- Click **Today** button to jump back to the current date

### Managing Goals
1. Click the **gear icon** (⚙️) in the top right
2. **Add goals** with the + button
3. **Reorder** by dragging the handle (≡)
4. **Toggle** goals on/off with the switch
5. **Edit or delete** with the pencil / trash buttons that appear on hover
6. **Star** a goal to mark it essential, so it stays tracked on special days

### Keyboard Shortcuts
- `Cmd+Shift+Y` - Toggle the popover from anywhere
  (change it in `AppDelegate.swift` → `setupGlobalHotKey()`, then rebuild)
- Right-click the menu bar icon for quick stats and quit option

## Data Storage

Your goals and entries are stored locally at:
```
~/Library/Application Support/DailyGoalsTracker/
├── goals.json           # Your goal definitions
├── entries.json         # Your daily entries
├── planning_goals.json  # Week / month / year / life goals
└── day_records.json     # Special day modes (fasting, trip, sick, rest)
```

## Sample Goals Included

The app comes with 8 sample goals to get you started:
- Exercise 🏃
- Read 📚
- Meditate 🧠
- Healthy Eating 🍃
- Learn Something New 💡
- Connect with Family ❤️
- Work on Side Project 🔨
- Drink Water 💧

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (for building from source)

## Tips

1. **Keep it simple** - Start with 3-5 goals and add more as habits form
2. **Use partial status** - It's better to do something than nothing
3. **Check the week view** - Patterns become visible over time
4. **Maintain streaks** - The flame icon shows consecutive perfect days

## Customization

You can customize goals with any SF Symbol icon. Popular choices:
- `figure.run` - Exercise
- `book.fill` - Reading
- `brain.head.profile` - Mental health
- `drop.fill` - Hydration
- `moon.fill` - Sleep
- `dollarsign.circle.fill` - Finance

---

Made for personal daily use. Track your habits, build consistency, achieve your goals.



## Build command

The app is **not** installed in `/Applications`. It runs from `DailyGoalsTracker.app`
inside this project folder.

Run this from the project folder to rebuild, replace the app, and relaunch it:

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

All paths are relative, so this keeps working if you move the project folder
somewhere else (Desktop, `~/Projects`, etc.).

Build output goes to a `.build/` folder inside the project (~125 MB). Delete it any
time with `rm -rf .build` — the next build just takes a few seconds longer.

### Optionally install to /Applications

If you'd rather launch it from Spotlight/Launchpad like a normal app:

```bash
pkill -f DailyGoalsTracker; \
rm -rf /Applications/DailyGoalsTracker.app \
&& cp -R DailyGoalsTracker.app /Applications/ \
&& open /Applications/DailyGoalsTracker.app
```

Your goals and history live in `~/Library/Application Support/`, so they are
unaffected by where the app itself sits.
