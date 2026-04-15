# Daymap

<p align="center">
  <img src="daymap/Daymap/Assets.xcassets/AppIcon.appiconset/icon_512.png" alt="Daymap app icon" width="128" height="128" />
</p>

<p align="center">
  A minimal, time-aware daily planner for macOS.
</p>

## What is Daymap?

Daymap helps you plan your day **based on time, not wishful thinking**.

Instead of dumping tasks into an endless list, Daymap lets you map your work onto a real timeline — so you can see what actually fits into your day.

---

## Screenshots

### Daily (focus)

![Daily focus mode](screenshots/daily-focus.png)

### Daily (timeline)

![Daily timeline view](screenshots/daily-timeline.png)

### Weekly

![Weekly view](screenshots/weekly.png)


## ✨ Why Daymap?

Most todo apps fail at one thing:

> They let you plan *more than you can actually do*.

Daymap fixes this by combining:
- a **task list for intent**
- a **calendar timeline for reality**

So you’re always working within the constraint that matters most — **time**.

---

## 🧠 Core Ideas

- Plan with awareness of your available time  
- Make tradeoffs visible (what fits vs what doesn’t)  
- Stay focused on one thing at a time  
- Keep the interface fast, minimal, and distraction-free  

---

## ⚡ Features

### 🗓️ Time-aware daily planning
- Visual timeline of your day
- Tasks are placed based on start and end times
- Drag to reschedule, resize to adjust duration
- See your day as it actually unfolds

### 🧠 Focus Mode
- Work on one task at a time
- Built-in timer to track actual time spent
- Clean, distraction-free interface
- Encourages deep work over multitasking

### 📅 Weekly view
- See your workload across the week
- Move tasks across days easily
- Plan ahead without losing daily clarity

### 🧩 Subtasks & notes
- Break down work into smaller steps
- Add context without cluttering the UI

---

## 🎯 Philosophy

Daymap is built on a simple belief:

> A good planning system should make it obvious when you're overcommitting.

By grounding tasks in time, Daymap helps you:
- be more realistic
- prioritize better
- and actually finish what you plan

---

## Requirements

- **macOS**: 13+ recommended
- **Xcode**: 15+ recommended

## Run locally

- Clone:

```bash
git clone https://github.com/bhagaban/daymap.git
cd daymap
```

- Open the Xcode project:
  - Open `daymap/Daymap.xcodeproj`
  - Select the `Daymap` scheme
  - Press **Run** (⌘R)

## Build (Release)

In Xcode:

- Select **Product → Archive**
- Distribute/export as needed

## Data storage

Daymap stores data locally on your machine in **Application Support** (a JSON file). No server required.

## Contributing

Issues and pull requests are welcome. If you’re changing UI behavior, please include a short screen recording or screenshots.

## License

MIT. See `LICENSE`.
