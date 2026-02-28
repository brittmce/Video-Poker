//
//  CardView.swift
//  Video Poker
//
//  Created by Britt McEachern on 1/20/26.
//

import SwiftUI

/// A view that displays a single playing card with optional held indicator
///
/// This view represents a single card in the video poker game. It displays
/// the card's suit and rank when visible, or a card back when the card
/// is not yet revealed. Players can tap on cards to indicate which ones
/// they want to hold during the deal phase.
struct CardView: View {
    /// The card to display
    let card: Card?
    
    /// Whether the card is currently held
    let isHeld: Bool
    
    /// Whether this card is optimally held (for feedback display)
    let isOptimallyHeld: Bool
    
    /// Action to perform when the card is tapped
    let onTap: () -> Void
    
    /// Card back image for when card is nil
    private let cardBackImage = "card_back"
    
    /// Colors for different suits
    private var suitColor: Color {
        guard let card = card else { return .black }
        switch card.suit {
        case .hearts, .diamonds:
            return .red
        case .clubs, .spades:
            return .black
        }
    }
    
    /// Border color based on card state
    private var borderColor: Color {
        if isHeld {
            return .yellow
        } else if isOptimallyHeld {
            return .green
        } else {
            return .gray
        }
    }
    
    var body: some View {
        ZStack {
            if let card = card {
                // Display actual card image
                Image(card.imageName)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 4)
                    )
                    .shadow(radius: 4)
                
                // Held banner overlay
                if isHeld {
                    Text("HELD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .padding(6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                
                // Optimal strategy indicator
                if isOptimallyHeld && !isHeld {
                    Text("HELD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            } else {
                // Display card back when card is nil
                Image(cardBackImage)
                    .resizable()
                    .scaledToFit()
                    .shadow(radius: 4)
            }
            
            // Invisible tap area that covers the entire card
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        }
        .aspectRatio(2/3, contentMode: .fit) // Standard poker card aspect ratio
    }
    
    /// Get the symbol for a suit
    /// - Parameter suit: The suit to get the symbol for
    /// - Returns: A string representing the suit symbol
    private func suitSymbol(for suit: Suit) -> String {
        switch suit {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }
}

// MARK: - Previews

#Preview {
    VStack {
        // Preview with a card that is not held
        CardView(
            card: Card(suit: .hearts, rank: .ace),
            isHeld: false,
            isOptimallyHeld: false,
            onTap: {}
        )
        .frame(width: 100, height: 150)
        
        // Preview with a card that is held
        CardView(
            card: Card(suit: .spades, rank: .king),
            isHeld: true,
            isOptimallyHeld: false,
            onTap: {}
        )
        .frame(width: 100, height: 150)
        
        // Preview with optimal hold indicator
        CardView(
            card: Card(suit: .diamonds, rank: .queen),
            isHeld: false,
            isOptimallyHeld: true,
            onTap: {}
        )
        .frame(width: 100, height: 150)
        
        // Preview with no card (card back)
        CardView(
            card: nil,
            isHeld: false,
            isOptimallyHeld: false,
            onTap: {}
        )
        .frame(width: 100, height: 150)
    }
}
