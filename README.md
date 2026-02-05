# Pillars

**Pillars** is a high-performance implementation of a classic match-three puzzle game, developed entirely in MIPS assembly language. The project demonstrates low-level system design, utilizing direct memory manipulation for graphics and Memory Mapped I/O (MMIO) for real-time user interaction.

## 🛠 Technical Features

The engine is built for a $256 \times 256$ bitmap display and features several advanced systems programming implementations:

* **Real-Time Physics Engine:** An iterative timing loop manages falling object gravity at 60 FPS, with dynamic speed scaling as the game progresses.
* **Direct Bitmap Rendering:** Custom graphical routines interface directly with the display address at `0x10008000`.
* **Asynchronous Input Handling:** Processes keyboard events via the `0xffff0000` MMIO address for responsive, lag-free gameplay.
* **MIDI Audio Subsystem:** Integrated sound effects for shuffling, matching gems, and game-over states using system-level MIDI calls.
* **Advanced Logic Modules:**
    * **Pattern Matching:** Scans the $6 \times 15$ grid for horizontal, vertical, and diagonal alignments.
    * **Column Bomb:** A special white-cell block that triggers a full-column clear upon detonation.
    * **State Management:** Full support for pausing, resuming, and hard-resetting the game state.

## 🎮 Controls

The system maps the following inputs for real-time interaction:

* **W:** Shuffle the internal order of the falling colors.
* **A / D:** Move the active pillar laterally across the grid.
* **S:** Manual drop (accelerated gravity).
* **P:** Toggle system pause.
* **Q:** Immediate system termination.
* **R:** Restart from the Game Over screen.

## 🚀 Environment Setup

To execute the engine, use a MIPS simulator (such as MARS) with the following configurations:

### Bitmap Display Settings
* **Unit Width/Height in Pixels:** 8
* **Display Width/Height in Pixels:** 256
* **Base Address for Display:** `0x10008000 ($gp)`

### Keyboard Settings
* **Base Address:** `0xffff0000`

---
*Technical demonstration of low-level systems and memory management.*
