import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct HairstyleMatchView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddHairstyle = false
    @State private var editingSavedHairstyle: TutorialLink?
    @State private var facePhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var detecting = false
    @State private var detectionMessage: String?

    private let faceShapes = ["圓臉", "長臉", "方臉", "心形臉", "鵜蛋臉", "菱形臉"]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "髮型臉型適配") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("我的臉型")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 10) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("拍照偵測", systemImage: "camera.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            PhotosPicker(selection: $facePhotoItem, matching: .images) {
                                Label("相簿選照", systemImage: "photo.on.rectangle")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primarySoft)
                                    .foregroundStyle(AppTheme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if detecting {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("正在偵測臉型…")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        } else if let detectionMessage {
                            Text(detectionMessage)
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }

                        Text("或手動選擇：")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(faceShapes, id: \.self) { shape in
                                Button {
                                    store.setFaceShape(shape)
                                } label: {
                                    Text(shape)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(store.state.faceShape == shape ? AppTheme.primary : AppTheme.primarySoft)
                                        .foregroundStyle(store.state.faceShape == shape ? Color.white : AppTheme.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }

                if let currentShape = store.state.faceShape, !currentShape.isEmpty,
                   let recommendations = HairstyleRecommendation.byFaceShape[currentShape] {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("適合「\(currentShape)」的髮型")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(recommendations, id: \.style) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.style)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Text(item.reason)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("髮型收藏")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("添加") { showAddHairstyle = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.savedHairstyles.isEmpty {
                            EmptyStateView(title: "暫無收藏", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.savedHairstyles) { hairstyle in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(hairstyle.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.text)
                                        if !hairstyle.url.isEmpty {
                                            Text(hairstyle.url)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingSavedHairstyle = hairstyle }) {
                                        store.deleteSavedHairstyle(hairstyle)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingSavedHairstyle) { record in
            FieldsEditSheet(
                title: "編輯髮型收藏",
                fieldLabels: ["標題", "連結URL"],
                values: [record.title, record.url],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.title = values[0]
                updated.url = values[1]

                store.replaceRecord(updated, in: \.savedHairstyles)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let image {
                    runFaceDetection(on: image)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: facePhotoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    runFaceDetection(on: image)
                } else {
                    detectionMessage = "無法讀取照片，請重新選擇。"
                }
                facePhotoItem = nil
            }
        }
        .sheet(isPresented: $showAddHairstyle) {
            AddLinkSheet(sheetTitle: "添加髮型", titleFieldLabel: "髮型名稱") { title, url in
                store.addSavedHairstyle(title: title, url: url)
            }
        }
    }

    private func runFaceDetection(on image: UIImage) {
        detecting = true
        detectionMessage = nil
        FaceShapeDetector.detect(from: image) { result in
            detecting = false
            switch result {
            case .success(let detection):
                store.setFaceShape(detection.shape)
                detectionMessage = "偵測結果：\(detection.shape)（\(detection.confidenceNote)）。照片僅在本機分析，不會上傳或保存。"
            case .failure(let error):
                detectionMessage = error.localizedDescription
            }
        }
    }
}

/// 相機拍照元件（照片僅回傳記憶體，不寫入相簿）
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .front
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onCapture(info[.originalImage] as? UIImage)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCapture(nil)
            parent.dismiss()
        }
    }
}
