//
//  PromotionPickerView.swift
//  Chess Base
//

import SwiftUI

/// Compact overlay shown when an analysis move promotes a pawn.
struct PromotionPickerView: View {
    let color: PieceColor
    let onPick: (PieceType) -> Void
    let onCancel: () -> Void

    private static let choices: [PieceType] = [.queen, .rook, .bishop, .knight]

    var body: some View {
        VStack(spacing: 12) {
            Text("Promote to")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                ForEach(Self.choices, id: \.rawValue) { type in
                    Button {
                        onPick(type)
                    } label: {
                        Image("\(type.rawValue)_\(color.rawValue)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .padding(6)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Cancel", role: .cancel, action: onCancel)
                .font(.subheadline)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 12)
    }
}

#Preview {
    PromotionPickerView(color: .white, onPick: { _ in }, onCancel: {})
}
