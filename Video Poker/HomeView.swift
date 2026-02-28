import SwiftUI
import UIKit

struct HomeView: View {
    private let previewCards = ["10S", "JS", "QS", "KS", "AS"]

    var body: some View {
        NavigationStack {
            ZStack {
                FeltTableBackground()
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.32))
                                .clipShape(Capsule())
                        }
                    }

                    Text("Video Poker Trainer")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 4)
                        .padding(.top, 4)

                    HStack(spacing: 10) {
                        ForEach(Array(previewCards.enumerated()), id: \.offset) { index, imageName in
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 66, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
                                .rotationEffect(.degrees(Double(index - 2) * 3))
                                .offset(y: CGFloat(abs(index - 2)) * 2)
                        }
                    }

                    Spacer(minLength: 0)

                    NavigationLink {
                        TrainingSetupView()
                    } label: {
                        Text("Training")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.10, green: 0.48, blue: 0.95),
                                        Color(red: 0.07, green: 0.34, blue: 0.78)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        GameView(mode: .justPlay)
                    } label: {
                        Text("Just Play")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.62, blue: 0.2),
                                        Color(red: 0.98, green: 0.46, blue: 0.12)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                DispatchQueue.global(qos: .utility).async {
                    ExpectedValueCalculator.prewarmResources()
                }
            }
        }
    }
}

private struct FeltTableBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.48, blue: 0.25),
                    Color(red: 0.03, green: 0.38, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 320
            )

            FeltTexture()
                .blendMode(.overlay)
                .opacity(0.4)

            RoundedRectangle(cornerRadius: 600)
                .stroke(Color.black.opacity(0.25), lineWidth: 40)
                .blur(radius: 20)
                .padding(-90)
        }
    }
}

private struct FeltTexture: View {
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 1.2
            let strideLength: CGFloat = 7
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let wave = sin((x * 0.09) + (y * 0.13))
                    let alpha = 0.02 + ((wave + 1) * 0.02)
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                    x += strideLength
                }
                y += strideLength
            }
        }
    }
}

private struct SettingsView: View {
    @AppStorage(Paytable.selectionStorageKey) private var selectedPaytableID: String = Paytable.defaultPaytable.id
    @State private var showPaytableList: Bool = false

    private var selectedPaytable: Paytable {
        Paytable.byID(selectedPaytableID)
    }

    private func plainNumber(_ value: Int) -> String {
        String(value)
    }

    private var menuWidth: CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .headline)
        let widestLabel = Paytable.allOptions
            .map { ($0.displayName as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 260
        // text + paddings + check + chevron room
        return ceil(widestLabel) + 88
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pay Table")
                .font(.title2.bold())
                .foregroundColor(.white)

            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showPaytableList.toggle()
                    }
                } label: {
                    HStack {
                        Text(selectedPaytable.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.yellow)
                        Image(systemName: showPaytableList ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(width: menuWidth, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showPaytableList {
                    Divider().overlay(Color.white.opacity(0.2))
                    ForEach(Paytable.allOptions.filter { $0.id != selectedPaytableID }, id: \.id) { paytable in
                        Button {
                            selectedPaytableID = paytable.id
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showPaytableList = false
                            }
                        } label: {
                            HStack {
                                Text(paytable.displayName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(width: menuWidth, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if paytable.id != Paytable.allOptions.last(where: { $0.id != selectedPaytableID })?.id {
                            Divider().overlay(Color.white.opacity(0.2))
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(12)
            .frame(width: menuWidth, alignment: .leading)

            VStack(spacing: 8) {
                HStack {
                    Text("Hand")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                    Text("1")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 42, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("2")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 42, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("3")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 42, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("4")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 42, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("5")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 42, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Divider().overlay(Color.white.opacity(0.2))

                ForEach(Array(Paytable.handDisplayOrder.enumerated()), id: \.offset) { index, label in
                    let coinPayouts = selectedPaytable.payoutsForCoins(handName: label)
                    HStack {
                        Text(label)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Spacer()
                        ForEach(Array(coinPayouts.enumerated()), id: \.offset) { _, payout in
                            Text(plainNumber(payout))
                                .font(.body.monospacedDigit())
                                .foregroundColor(.white)
                                .frame(width: 42, alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    if index < Paytable.handDisplayOrder.count - 1 {
                        Divider().overlay(Color.white.opacity(0.2))
                    }
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.top, 2)

            Text(selectedPaytable.commonLocationSummary)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            FeltTableBackground()
                .ignoresSafeArea()
        )
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
}

private struct TrainingSetupView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Training")
                .font(.title.bold())
                .foregroundColor(.white)

            Text("Pick a difficulty and practice with 50 fixed hands.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))

            ForEach(TrainingDifficulty.allCases) { level in
                NavigationLink {
                    GameView(mode: .training(level))
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.title)
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text(level.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            FeltTableBackground()
                .ignoresSafeArea()
        )
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
    }
}
