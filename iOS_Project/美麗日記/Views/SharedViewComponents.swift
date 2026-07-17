import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct GenericSummaryView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: title) {}

                CardView {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}
