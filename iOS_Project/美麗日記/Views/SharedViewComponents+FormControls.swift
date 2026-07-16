import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .foregroundStyle(AppTheme.subtext)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }
}

struct ThemedTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .padding(14)
            .background(AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(title)
    }
}

struct ThemedSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .padding(14)
            .background(AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(title)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.subtext)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.text)
        }
        .font(.subheadline)
    }
}

struct WrapChips: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.primarySoft)
                    .clipShape(Capsule())
            }
        }
    }
}

struct WrapToggleChips: View {
    let items: [String]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button {
                    if selection.contains(item) {
                        selection.remove(item)
                    } else {
                        selection.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selection.contains(item) ? AppTheme.primary : AppTheme.primarySoft)
                        .foregroundStyle(selection.contains(item) ? Color.white : AppTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WrapSelectableChips: View {
    let items: [ResourceCategory]
    let selected: ResourceCategory
    let action: (ResourceCategory) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                Button {
                    action(item)
                } label: {
                    Text(item.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected == item ? AppTheme.primary : AppTheme.primarySoft)
                        .foregroundStyle(selected == item ? Color.white : AppTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

func header(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(AppTheme.text)
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(AppTheme.subtext)
    }
}

func titleRow(title: String, action: String? = nil, onTap: @escaping () -> Void = {}) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(AppTheme.text)
        Spacer()
        if let action {
            Button(action) {
                onTap()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.primary)
            .clipShape(Capsule())
            .accessibilityIdentifier(action)
        }
    }
}

func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? AppTheme.primary : AppTheme.subtext)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? AppTheme.card : AppTheme.primarySoft)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? AppTheme.primary.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(BeautyDiaryStore.preview)
    }
}
