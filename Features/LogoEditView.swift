import SwiftUI
import PhotosUI

// MARK: - Logo 编辑页面
struct LogoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AppSettings

    let initialImage: UIImage

    @State private var selectedImage: UIImage
    @State private var containerWidth: Double
    @State private var containerHeight: Double
    @State private var imageScale: Double
    @State private var bottomPadding: Double
    @State private var showImagePicker = false

    init(settings: AppSettings, image: UIImage) {
        self.settings = settings
        self.initialImage = image
        self._selectedImage = State(initialValue: image)
        self._containerWidth = State(initialValue: settings.containerWidth)
        self._containerHeight = State(initialValue: settings.containerHeight)
        self._imageScale = State(initialValue: settings.imageScale)
        self._bottomPadding = State(initialValue: settings.bottomPadding)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 预览区域（可滚动查看大尺寸）
                    VStack(spacing: 8) {
                        Text("预览效果（实际尺寸）")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 预览容器 - 使用固定尺寸显示实际效果
                        VStack(spacing: bottomPadding) {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: containerWidth * imageScale, height: containerHeight * imageScale)
                                .frame(width: containerWidth, height: containerHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )

                            // 模拟下方标题
                            Text("会员优享套餐")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    }
                    .padding(.top, 16)

                    // 编辑控制
                    VStack(spacing: 20) {
                        // 容器宽度
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("容器宽度")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(containerWidth))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            HStack(spacing: 12) {
                                Text("100")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Slider(value: $containerWidth, in: 100...400, step: 10)
                                    .tint(.blue)
                                Text("400")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // 容器高度
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("容器高度")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(containerHeight))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            HStack(spacing: 12) {
                                Text("50")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Slider(value: $containerHeight, in: 50...400, step: 10)
                                    .tint(.blue)
                                Text("400")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // 图片缩放
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("图片缩放")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(imageScale * 100))%")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            HStack(spacing: 12) {
                                Text("30%")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Slider(value: $imageScale, in: 0.3...3.0, step: 0.1)
                                    .tint(.blue)
                                Text("300%")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // 下边距
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("与标题距离")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(bottomPadding))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            HStack(spacing: 12) {
                                Text("0")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Slider(value: $bottomPadding, in: 0...60, step: 5)
                                    .tint(.blue)
                                Text("60")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 重新选择图片
                    Button {
                        showImagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("重新选择图片")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }
                    .padding(.bottom, 20)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("编辑图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }

    private func saveAndDismiss() {
        settings.saveLogo(selectedImage)
        settings.containerWidth = containerWidth
        settings.containerHeight = containerHeight
        settings.imageScale = imageScale
        settings.bottomPadding = bottomPadding
        dismiss()
    }
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else { return }

            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.image = image
                    }
                }
            }
        }
    }
}
