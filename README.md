🕒 Time Blind (WIP)

![Swift](https://img.shields.io/badge/swift-5.9-orange)
![Platform](https://img.shields.io/badge/platform-iOS%20%26%20iPadOS-blue)
![Status](https://img.shields.io/badge/status-WIP-yellow)
![Build](https://img.shields.io/badge/build-local_only-lightgrey)

**Time Blind** is a simple, SwiftUI-based iOS app designed to help people who chronically run late — by showing how early or late they’d arrive at a saved destination **if they left right now**.

---

## ✨ Core Functionality

- ✅ Add destinations with a name, address, and target arrival time  
- ✅ Automatically geocode addresses to coordinates (via `CLGeocoder`)  
- ✅ Calculate real-time ETA using `MapKit` and live traffic  
- ✅ Compare ETA to the user-defined arrival time (e.g., “+4 min” or “–3 min”)  
- ✅ Display all destinations in a scrollable list view  
- ✅ SwiftData-backed local persistence (no manual save/load)

---

## 📦 Tech Stack

- **SwiftUI** – Declarative UI for iOS & iPadOS  
- **SwiftData** – Local persistence for destinations  
- **MapKit / CoreLocation** – Real-time traffic + ETA calculation  
- **CLGeocoder** – Address → coordinate conversion  
- **No iCloud or external APIs** (yet — planned)

---
