import SwiftUI
import PhotosUI

// MARK: - Logo 编辑页面
struct LogoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AppSettings

    let initialImage: UIImage

    @State private var selectedImage: UIImage
    @State private var scale: Double

    init(settings: AppSettings, image: UIImage) {
        self.settings = settings
        self.initialImage = image
        self._selectedImage = State(initialValue: image)
        self._scale = State(initialValue: settings.logoScale > 0 ? settings.logoScale : 1.0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo 预览
                VStack(spacing: 16) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120 * scale, height: 120 * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )

                    Text("调整 Logo 大小")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                Spacer()

                // 缩放控制
                VStack(spacing: 12) {
                    HStack {
                        Text("大小")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(scale * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack(spacing: 16) {
                        Text("小")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Slider(value: $scale, in: 0.5...2.0, step: 0.1)
                            .tint(.blue)

                        Text("大")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("编辑 Logo")
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
        }
    }

    private func saveAndDismiss() {
        settings.saveLogo(selectedImage)
        settings.logoScale = scale
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
