# Jacks or Better Strategy Trainer - Technical Specification

## 1. Project Overview

This document outlines the technical specification for building a Jacks or Better Video Poker strategy trainer application for iOS. The app will help players learn optimal strategy by presenting dealt hands and allowing them to select which cards to hold, then showing the expected value of their choices compared to the optimal play.

## 2. Current Project Analysis

### 2.1 Existing Files and Structure

The current project is a basic SwiftUI iOS application with the following structure:

```
Video Poker/
├── ContentView.swift (Basic view with "Hello, world!" placeholder)
├── Video_PokerApp.swift (Main app entry point)
├── Assets.xcassets/ (Asset catalog with AppIcon and AccentColor)
├── Video Poker.xcodeproj/ (Xcode project configuration)
├── Video PokerTests/ (Unit tests)
└── Video PokerUITests/ (UI tests)
```

### 2.2 Integration Points

- **ContentView.swift**: Will be replaced with the main game interface
- **Video_PokerApp.swift**: Will remain as the main app entry point with minimal changes
- **Assets.xcassets**: Will be extended to include card images
- **Tests**: Existing test structure will be utilized for new functionality

## 3. UI Components

### 3.1 Core Views

1. **GameView**
   - Main playing surface
   - Displays player's hand (5 cards)
   - Shows card selection states (held/not held)
   - Displays expected value comparison
   - Action buttons (Deal, Draw, Hint, New Hand)

2. **CardView**
   - Visual representation of a playing card
   - Shows card face or back
   - Selection indicator for held cards
   - Tap gesture recognition

3. **StatisticsView**
   - Player performance metrics
   - Strategy accuracy percentage
   - Hands played counter
   - Reset statistics option

4. **SettingsView**
   - Difficulty levels
   - Sound preferences
   - Display options

### 3.2 Navigation

- Tab-based navigation between Game, Statistics, and Settings
- Modal presentation for detailed strategy explanations

## 4. Data Models

### 4.1 Card
```swift
struct Card {
    enum Suit {
        case hearts, diamonds, clubs, spades
    }
    
    enum Rank {
        case two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace
    }
    
    let suit: Suit
    let rank: Rank
}
```

### 4.2 Hand
```swift
struct Hand {
    let cards: [Card]
    let payout: Int
    let name: String  // e.g., "Royal Flush", "Straight"
}
```

### 4.3 GameState
```swift
struct GameState {
    let initialHand: [Card]
    var heldCards: Set<Int>  // Indices of held cards
    let optimalHold: Set<Int>  // Optimal cards to hold
    let playerEV: Double  // Expected value of player's choice
    let optimalEV: Double  // Expected value of optimal play
    var stage: GameStage  // Dealt, Holding, Result
}
```

### 4.4 PlayerStatistics
```swift
struct PlayerStatistics {
    var handsPlayed: Int
    var correctDecisions: Int
    var totalEV: Double
    var optimalEV: Double
}
```

## 5. Game Logic Components

### 5.1 Deck Management
- Standard 52-card deck implementation
- Shuffling algorithm
- Card dealing functionality

### 5.2 Hand Evaluation
- Hand ranking system (Royal Flush, Straight Flush, Four of a Kind, etc.)
- Payout calculation based on standard Jacks or Better paytable
- Hand comparison utilities

### 5.3 Game Flow Controller
- Manages game state transitions
- Coordinates between UI and business logic
- Handles user input processing

### 5.4 Strategy Engine
- Implements optimal strategy lookup
- Calculates expected values for all possible hold combinations
- Provides hints to players

## 6. Expected Value Calculation System

### 6.1 Core Algorithm
The expected value calculation will evaluate all 32 possible hold combinations (2^5) for any given hand:

1. For each hold combination:
   - Determine which cards will be drawn
   - Calculate all possible resulting hands
   - Weight each outcome by probability
   - Multiply by corresponding payout
   - Sum to get expected value

### 6.2 Optimization Strategies
- Precomputed strategy tables for common hand patterns
- Caching of previously calculated EV values
- Early termination for obviously suboptimal holds

### 6.3 Paytable Reference
Standard Jacks or Better paytable:
- Royal Flush: 800 (with max bet)
- Straight Flush: 50
- Four of a Kind: 25
- Full House: 9
- Flush: 6
- Straight: 4
- Three of a Kind: 3
- Two Pair: 2
- Jacks or Better: 1

## 7. State Management Approach

### 7.1 SwiftUI State Management
- `@State` for local view properties
- `@Binding` for shared state between parent/child views
- `@ObservedObject` for complex state objects
- `@EnvironmentObject` for global app state (statistics, settings)

### 7.2 Game State Architecture
```
GameStateManager (ObservableObject)
├── Current game state
├── Player statistics
└── Game settings
```

### 7.3 Data Persistence
- UserDefaults for simple preferences and statistics
- JSON serialization for complex state if needed
- No external dependencies for offline functionality

## 8. Asset Integration Plan

### 8.1 Card Images
- Add playing card images to Assets.xcassets
- Organize by suit and rank
- Include card back design
- Support for different visual themes

### 8.2 Icons and Graphics
- Custom icons for UI controls
- Visual indicators for card selection
- Performance metrics visualization

## 9. Testing Strategy

### 9.1 Unit Tests
- Card creation and validation
- Hand evaluation accuracy
- Expected value calculations
- Game state transitions

### 9.2 UI Tests
- Basic gameplay flow
- User interaction with cards
- Navigation between screens

### 9.3 Strategy Validation
- Verification against known optimal strategy tables
- Edge case handling for unusual hands

## 10. Implementation Roadmap

### Phase 1: Core Infrastructure
- Card and deck implementation
- Hand evaluation system
- Basic UI framework

### Phase 2: Game Logic
- Expected value calculation engine
- Strategy hint system
- Game state management

### Phase 3: User Experience
- Complete UI implementation
- Animations and visual feedback
- Statistics tracking

### Phase 4: Polish and Refinement
- Performance optimization
- Comprehensive testing
- Final UI adjustments

## 11. Technical Requirements

### 11.1 Platform Support
- iOS 17.2+ (matching current deployment target)
- iPhone and iPad compatibility
- Portrait and landscape orientations

### 11.2 Performance Targets
- Hand evaluation and EV calculation under 100ms
- Smooth animations at 60fps
- Minimal memory footprint

### 11.3 Accessibility
- VoiceOver support
- Dynamic text sizing
- Color contrast compliance

## 12. Future Expansion Opportunities

- Additional video poker variants
- Tournament mode
- Social features and leaderboards
- Advanced statistics and analytics
- Tutorial system for beginners