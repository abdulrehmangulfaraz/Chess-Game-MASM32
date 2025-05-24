
# ♟ Chess Game in MASM32

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is a full-featured **two-player Chess Game implemented in MASM32 Assembly language**. It uses low-level Windows API and graphical rendering techniques to simulate a fully playable chess match with proper rules, interface, and control. Built with care and precision, it showcases the capability of MASM32 to power logic-heavy systems like a chess engine.

---

## 🕹️ Gameplay Features

- 🎮 **Two-Player Chess**: Blue (White) vs Red (Black)
- ♟️ **Standard Piece Movement**: All six types of pieces follow standard chess rules.
- 🔁 **Special Moves Supported**:
  - Castling (Kingside & Queenside)
  - En Passant
  - Pawn Promotion
- 👑 **Check & Checkmate Detection**
- ✅ **Move Validation & Turn Switching**
- 🔍 **Move History Displayed in Console**

---

## 🧱 Technical Implementation

- ⚙️ **Language**: Assembly (MASM32 SDK)
- 🪟 **Graphics**: Windows GDI (graphical board and pieces)
- 📟 **Console**: Move input handled via a separate input thread
- 🧠 **Threading**:
  - Main thread: Handles board rendering and display
  - Input thread: Reads and validates user move commands
- 🧮 **Bitwise & Memory-Efficient Structures**:
  - 64-word (128-byte) board array in memory
  - Flags for game state: current turn, castling rights, en passant availability, etc.

---

## 🖥️ User Interface

- 🧊 **Graphical Board**: Chess board with alternating square colors
- ♚ **Unicode Piece Symbols**:
  - White: ♔♕♖♗♘♙
  - Black: ♚♛♜♝♞♟
- 🔠 **Algebraic Notation**: a-h files, 1-8 ranks labeled
- 🎨 **Colors**:
  - Blue: White pieces
  - Red: Black pieces
- 🖋️ **Input Format**:
  - Move: `e2 e4`
  - Castling: `O-O` or `O-O-O`

---

## 🧠 Game Logic

### ✅ Castling
- Ensures king and rook haven't moved
- Checks clear path
- Verifies king isn't in/through check

### ✅ En Passant
- Detects double pawn step
- Allows capture on the next move only

### ✅ Pawn Promotion
- Prompts player on reaching final rank
- Offers Queen, Rook, Bishop, Knight
- Defaults to Queen on invalid input

### ✅ Checkmate Detection
- Detects check after every move
- Searches all legal responses
- Declares winner if none are legal

---

## 🗂️ File Structure

- `ChessGame.asm`: Single source file with complete logic and interface
  - `.data` section: Game constants, flags, piece definitions
  - `.code` section: Game loop, move validation, rendering
  - Modular procedures for:
    - Drawing board
    - Handling input
    - Special rules
    - Game state updates

---

## ⚒️ Build & Run Instructions

### ✅ Requirements
- 🛠️ MASM32 SDK
- 💻 Windows OS

### 🏗️ Build
```bash
ml /c /coff ChessGame.asm
link /subsystem:windows ChessGame.obj
````

### ▶️ Run

* Launch `ChessGame.exe`
* A graphical window displays the board
* Console window receives move input
* Turns alternate automatically

---

## 📋 Console Features

* Displays move history
* Provides prompts for:

  * Pawn promotion
  * Invalid move warnings
  * Check/checkmate notifications

---

## 🚀 Planned Enhancements

> This game is complete as of now, but I plan to expand it further.

* ♟️ **AI Opponent**
* 💾 Save & Load Games
* 🔁 Undo Moves
* 🔔 Sound Effects
* 🕒 Player Clock/Timer
* 🧭 Better GUI with clickable interface

---

## 📫 Contact

* 🔗 **GitHub**: [abdulrehmangulfaraz](https://github.com/abdulrehmangulfaraz)
* 🔗 **LinkedIn**: [abdulrehman-gulfaraz](https://www.linkedin.com/in/abdulrehman-gulfaraz)
* 📧 **Email**: [abdulrehmangulfaraz@gmail.com](mailto:abdulrehmangulfaraz@gmail.com)

---

## ⚖️ License

This project is licensed under the [MIT License](LICENSE).

---

> Built with MASM32 to demonstrate the power of Assembly in real-world logical simulations and game development.
