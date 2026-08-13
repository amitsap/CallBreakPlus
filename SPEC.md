# CallBreak+ — Game Specification

## Overview

CallBreak (also known as Call Bridge) is a 4-player trick-taking card game popular in South Asia. This app implements the standard rules with one human player and three AI bots.

## Core Rules

### Deck & Deal
- Standard 52-card deck, no jokers
- 4 players, each dealt 13 cards
- **Spades are always trump**
- Card rank (high to low): A K Q J 10 9 8 7 6 5 4 3 2

### Game Structure
- A game consists of **5 rounds** (deals), unless a player wins early through Thok
- Scores accumulate across rounds
- Highest cumulative score after round 5 wins; equal highest scores produce co-winners

### Seating & Turn Order
- Four seats: Bottom (human), Left (bot), Top (bot), Right (bot)
- **[DECISION] Play direction: anti-clockwise** — turn order is Bottom → Right → Top → Left
- **[DECISION] First trick leader: player seated after the dealer in turn order**
- Dealer rotates each round (anti-clockwise)

### Bidding
- After the deal, each player bids 1–13 (minimum 1, no nil/zero bid)
- **[DECISION] Bids revealed sequentially** — each bid is visible to all as it's made
- Bids are made in turn order starting from the player after the dealer

### Trick Play (13 tricks per round)

1. The trick leader plays any card
2. Others follow in turn order
3. **Follow suit:** if you hold the led suit, you must play it
4. **[DECISION] Must-go-higher: ON** — while the trick has not been trumped, a player following the led suit must beat its current highest card when able. Once a trump is winning the trick, the player must still follow suit but may play any card of that suit
5. **[DECISION] Must-trump: ON** — if void in the led suit and you hold spades, you must play a spade. If a spade has already been played in the trick, you must play a higher spade if possible
6. **[DECISION] Free Discard: ON** — if a spade has already been played and you cannot overtrump it, you may discard any card instead of spending a lower spade
7. If void in both the led suit and spades, play any card
8. **Trick winner:** highest spade if any played; otherwise highest card of the led suit
9. Winner leads the next trick

### Default House Rules

- **Free Discard: ON** — described above
- **Fair Deal: ON** — redeal if any player receives no spade or no face card; dealing retries are capped to guarantee progress
- **Thok: ON** — a player who bids 8 or more and makes that bid wins the game immediately

### Scoring (per round, per player)

- **Made bid (tricks ≥ bid):** score = `bid + 0.1 × (tricks − bid)`
- **Failed bid (tricks < bid):** score = `−bid`

**[DECISION] Overtrick handling: simple (+0.1 per overtrick)**

No accumulated overtrick penalty in v1. A common variant penalizes when fractional overtricks reach 1.0 (effectively: every 10 overtricks costs a point). The scoring function is isolated and well-tested so this variant can be swapped in later.

## Bot AI

### Difficulty Presets

**Beginner**
- Bids conservatively: rough count of high cards (A, K, Q of spades; A, K of other suits) + bonus for spade length
- Play: avoids leading trump, wins with the cheapest legal card when possible, and otherwise plays low
- No card tracking

**Intermediate**
- Bids from high cards + spade length + distribution analysis
- Tracks which suits are broken
- Win with lowest winning card; duck when bid is already met; hold high spades for late tricks
- Basic defensive play

**Advanced**
- Tracks all played cards
- Bids accurately based on trick potential analysis
- Actively tries to break opponents' calls (force over/under)
- Manages spade timing (hold for key tricks)
- No cheating — only uses publicly visible information (played cards, bids, own hand)

## UI Specification

### Layout (Landscape)
- Edge-filling oval/green felt table with restrained wood surround
- Human hand: large, partially edge-cropped hand along the bottom, sorted by suit then rank
- Bot seats at left, top, right: card-back fans with compact name, bid, and tricks-won labels
- Dealer indicated by a gold `D` chip at the appropriate seat
- Center: enlarged four-position trick diamond that preserves the origin of every played card
- Top chrome: Pause at left, round/trick status centered, score-sheet control at right
- Score sheet slides in only on request; cumulative score is not duplicated at every seat
- Previous-trick review appears contextually beside the trick area
- Active turn is communicated by seat/hand glow and playable cards; a text hint appears only after hesitation

### CardView
- Reusable component with face and back states
- Vector-clean rendering, legible at small sizes
- Crisp suit pips (♠ ♥ ♦ ♣) and rank labels
- Card back: at least one alternate design (selectable in Settings)

### Animations
- **Dealing:** cards fly from center deck to each seat with stagger; human cards flip face-up into fan
- **Legal card affordance:** legal cards rise slightly with gentle scale + optional soft glow; illegal cards sit lower and dimmed
- **Card play:** tapped card animates from hand to center trick position (matchedGeometryEffect)
- **Bot play:** same animation from bot seat to center
- **Trick collection:** highlight winning card, sweep trick to winner's corner
- **Bidding:** a compact 1–13 call tray appears immediately above the human hand; bot calls remain visible in the tray and at their seats
- **Round transition:** round-end summary card, then animate into next deal
- **Haptics:** light impact on card play, medium on trick win
- **Pause:** suspends bot flow and exposes resume, sound, settings, statistics, play speed, and quit actions

All animation timing driven by ViewModel, decoupled from engine.

### Settings Screen
- Bot difficulty: Beginner / Intermediate / Advanced
- Sound: on/off
- Haptics: on/off
- Player name (text field)
- Card-back style selector
- House-rule explanations and accessibility options
- Feedback and App Store rating routes
- Reset statistics (with confirmation alert)

### Statistics Screen (SwiftData)
- Games played / won / win rate
- Average bid accuracy (bids made vs met)
- Best round score
- Longest win streak
- Per-difficulty breakdowns

## Out of Scope (v1)

- Online/multiplayer
- Game Center integration
- In-app purchases
- Sound effect asset pipeline (audio interface stubbed only)
- iPad-specific layout tuning beyond "it works in landscape"
- Localization beyond English
- Accumulated overtrick penalty variant
