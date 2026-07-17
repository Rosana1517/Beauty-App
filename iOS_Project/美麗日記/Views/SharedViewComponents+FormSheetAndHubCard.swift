import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct FormSheet<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    content
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HubCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        CardView {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.primarySoft)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: icon).foregroundStyle(AppTheme.primary))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.subtext)
            }
        }
    }
}

/// Reusable "type your concern -> get AI suggestions" card, shared by every
/// screen with this pattern (護膚/頭髮/面部拉提/身體皮膚/飲食/妝容) so each
/// one doesn't duplicate the chip-selector + custom-input + button + result
/// list wiring.
