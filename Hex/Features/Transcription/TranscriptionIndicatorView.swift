//
//  TranscriptionIndicatorView.swift
//  Hex
//
//  Created by Kit Langton on 1/25/25.
//

import Inject
import SwiftUI

struct TranscriptionIndicatorView: View {
  @ObserveInjection var inject
  
  enum Status {
    case hidden
    case optionKeyPressed
    case recording
    case transcribing
    case postProcessing
    case prewarming
  }

  var status: Status
  var meter: Meter

  private var isHidden: Bool {
    status == .hidden
  }

  @State private var phase: CGFloat = 0

  var body: some View {
    ZStack {
      if !isHidden {
        HStack(spacing: 12) {
          // Status Icon/Indicator
          Group {
            switch status {
            case .hidden:
              EmptyView()
            case .optionKeyPressed:
              Image(systemName: "command")
                .font(.system(size: 12))
                .foregroundStyle(HexDesign.Colors.textSecondary)
            case .recording:
              RecordingIndicator(meter: meter)
            case .transcribing:
              ProgressView()
                .controlSize(.small)
                .tint(HexDesign.Colors.textPrimary)
            case .postProcessing:
              Image(systemName: "sparkles")
                .symbolEffect(.pulse.byLayer, options: .repeating)
                .foregroundStyle(HexDesign.Colors.accent)
            case .prewarming:
              Image(systemName: "hourglass")
                .foregroundStyle(HexDesign.Colors.warning)
            }
          }

          // Status Text (Optional, maybe just concise mode)
          if status == .postProcessing {
             Text("Thinking...")
                .font(HexDesign.Fonts.code(size: 12))
                .foregroundStyle(HexDesign.Colors.textSecondary)
          } else if status == .transcribing {
             Text("Transcribing...")
                .font(HexDesign.Fonts.code(size: 12))
                .foregroundStyle(HexDesign.Colors.textSecondary)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(HexDesign.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: HexDesign.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: HexDesign.cornerRadius)
                .stroke(HexDesign.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.bouncy(duration: 0.3)),
            removal: .opacity.animation(.easeOut(duration: 0.2))
        ))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .enableInjection()
  }
}

struct RecordingIndicator: View {
    var meter: Meter

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(HexDesign.Colors.error)
                .frame(width: 8, height: 8)
                .opacity(Double(meter.averagePower) > 0.1 ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.1), value: meter.averagePower)

            // Minimalist waveform
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(HexDesign.Colors.textSecondary)
                        .frame(width: 2, height: 4 + (CGFloat(meter.averagePower) * 12.0 * CGFloat(index + 1).truncatingRemainder(dividingBy: 3)))
                        .animation(.spring(response: 0.1, dampingFraction: 0.5), value: meter.averagePower)
                }
            }
        }
    }
}

#Preview("HEX New") {
    ZStack {
        Color.gray
        VStack(spacing: 20) {
            TranscriptionIndicatorView(status: .recording, meter: .init(averagePower: 0.8, peakPower: 1.0))
            TranscriptionIndicatorView(status: .transcribing, meter: .init(averagePower: 0, peakPower: 0))
            TranscriptionIndicatorView(status: .postProcessing, meter: .init(averagePower: 0, peakPower: 0))
        }
    }
}
