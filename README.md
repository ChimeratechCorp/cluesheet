# Clue Sheet

An iPhone app that replaces the paper detective notepad in the board game Clue (Cluedo).
You enter what happens at the table, and the app crosses off cards, works out who holds
what, and tells you when it knows what's in the envelope.

## What it does

- **Setup:** enter the players in turn order, their hand sizes (filled in for you), which
  player you are, and the cards in your hand.
- **The sheet:** a row for every suspect, weapon and room, and a column for every player
  plus the envelope. ✓ means that player has the card, ✗ means they don't, blank means
  not known yet. Tap any square to record something you learned yourself.
- **Log turn:** after each suggestion, pick who suggested, the three cards, and who showed
  a card (or nobody). If you made the suggestion, also pick the card you were shown.
  Players asked before the one who showed are recorded as having none of the three.
  Wrong accusations can be logged too.
- **Solution banner:** shows each part of the answer once it's certain, or how many
  candidates are left.
- **History:** every entry, newest first. Swipe to delete a mistake and the sheet is
  recalculated. If entries contradict each other, a red warning tells you what conflicts.
- **Helper switch** (⋯ menu, on by default): when on, the sheet fills in everything that
  follows from your entries, such as X'ing out the rest of a column once a player's whole
  hand is known. When off, it shows only what you entered, like a paper sheet.
- **Turn numbers:** each square shows, in small numbers, the turns when that player showed
  a card that might have been this one. The history is numbered to match.
- **Notes:** a blank notepad for hunches and reminders.
- **iPhone Duo (foldable):** unfolded, the screen splits at the fold: notes on the left
  half, the clue sheet on the right. (Any screen at least 600 points wide does the same,
  such as an iPad or the folded Duo turned sideways.)
  A switch at the top of the left half flips it to the history. On a folded phone, notes
  and history are in the ⋯ menu.
- The game and notes are saved automatically, so closing the app doesn't lose them.

### How it deduces

The logic lives in the `ClueEngine` Swift package, separate from the app so it can be
tested on any computer. It repeatedly applies these rules until nothing changes:

1. Every card has exactly one owner (a player or the envelope).
2. Every player holds exactly their hand size.
3. The envelope holds exactly one suspect, one weapon and one room.
4. A player who showed a card for a suggestion holds at least one of those three; once
   two are ruled out, it must be the third.
5. A wrong accusation means the envelope doesn't hold all three of those cards.

Then it tries every unknown square both ways: if assuming "has it" leads to a
contradiction, the player can't have it (and vice versa). That catches deductions that
take several steps to see.

## Project layout

```
ClueSheet.xcodeproj    Xcode project for the iPhone app
ClueSheet/             The app's SwiftUI screens
ClueEngine/            Swift package with the deduction logic and its tests
.github/workflows/     Checks GitHub runs on every push
```

## Running it on a Mac

You need a Mac with **Xcode 16 or later** (free from the Mac App Store). The app needs
iOS 17 or later.

1. Get the code: in Terminal, run
   `git clone https://github.com/ChimeratechCorp/cluesheet.git`
   (or on GitHub click **Code → Download ZIP** and unzip it).
2. Double-click `ClueSheet.xcodeproj` to open it in Xcode.
3. At the top of the Xcode window, pick an iPhone simulator (for example "iPhone 16")
   and press the ▶ Run button. The app opens in the simulator.

### On your own iPhone

1. In Xcode, open **Settings → Accounts** and sign in with your Apple ID (a free account
   works; a paid developer account lets the app run for more than 7 days at a time).
2. Click the blue **ClueSheet** project at the top of the file list, choose the
   **ClueSheet** target, open **Signing & Capabilities**, and pick your account under
   **Team**. If Xcode says the bundle identifier is taken, change
   `com.chimeratech.cluesheet` to something unique, such as `com.yourname.cluesheet`.
3. Plug in your iPhone, unlock it, and choose it at the top of the Xcode window.
4. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode** if asked,
   then press ▶ Run.
5. The first time, the iPhone may ask you to trust the developer: go to
   **Settings → General → VPN & Device Management** and trust your Apple ID.

## Testing the deduction logic

The engine tests run on macOS or Linux with Swift 5.9 or later:

```
cd ClueEngine
swift test
```

GitHub also runs these tests and builds the iPhone app on every push (see the
**Actions** tab), so you can tell the code compiles even without a Mac.

## Card names

The classic card set is built in (Miss Scarlet, Col. Mustard, Mrs. White, Mr. Green,
Mrs. Peacock, Prof. Plum; Candlestick, Knife, Lead Pipe, Revolver, Rope, Wrench; and the
nine rooms). Other editions rename cards; to change them, edit `Edition.classic` in
`ClueEngine/Sources/ClueEngine/Cards.swift`.
