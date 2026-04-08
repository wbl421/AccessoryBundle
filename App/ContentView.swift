import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddCategory = false
    @State private var categoryToEdit: Category?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    categoryGrid
                    Spacer(minLength: 40)
                    accessoryButton
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddCategory = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                CategoryEditView(category: nil)
            }
            .sheet(item: $categoryToEdit) { category in
                CategoryEditView(category: category)
            }
        }
    }

    private var headerView: some View {
        Text("会员优享套餐")
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .padding(.top, 8)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(dataManager.categories.sorted { $0.order < $1.order }) { category in
                NavigationLink(destination: CategoryView(category: category)) {
                    CategoryCard(category: category)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        categoryToEdit = category
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        dataManager.deleteCategory(category.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .onLongPressGesture {
                    categoryToEdit = category
                }
            }
        }
    }

    private var accessoryButton: some View {
        NavigationLink(destination: AccessoryListView()) {
            HStack {
                Image(systemName: "gearshape.fill")
                Text("配件管理")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

struct CategoryCard: View {
    let category: Category

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 56))
                .foregroundStyle(.white)

            Text(category.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            LinearGradient(colors: [category.color, category.color.opacity(0.7)],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: category.color.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Category Edit View
struct CategoryEditView: View {
    let category: Category?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    @State private var name = ""
    @State private var selectedIcon = "iphone"
    @State private var selectedColorHex = "#007AFF"

    private var isEditing: Bool { category != nil }

    private let icons = ["iphone", "ipad", "laptopcomputer", "applewatch", "desktopcomputer", "headphones", "airpods", "airpodpro", "airpodsmax", "keyboard", "mouse", "tv", "hifispeaker", "printer", "gamecontroller"]

    private let colors: [(name: String, hex: String)] = [
        ("蓝色", "#007AFF"),
        ("紫色", "#5856D6"),
        ("橙色", "#FF9500"),
        ("粉色", "#FF2D55"),
        ("绿色", "#34C759"),
        ("红色", "#FF3B30"),
        ("青色", "#5AC8FA"),
        ("黄色", "#FFCC00")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("分类名称") {
                    TextField("请输入名称", text: $name)
                }

                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colors, id: \.hex) { color in
                            Button {
                                selectedColorHex = color.hex
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: color.hex) ?? .blue)
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            if selectedColorHex == color.hex {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(color.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 预览
                Section("预览") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                            Text(name.isEmpty ? "分类名称" : name)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(width: 120, height: 100)
                        .background(
                            LinearGradient(colors: [Color(hex: selectedColorHex) ?? .blue, (Color(hex: selectedColorHex) ?? .blue).opacity(0.7)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            dataManager.deleteCategory(category!.id)
                            dismiss()
                        } label: {
                            HStack { Spacer(); Text("删除此分类"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑分类" : "添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    selectedIcon = category.icon
                    selectedColorHex = category.colorHex
                }
            }
        }
    }

    private func saveCategory() {
        if let existingCategory = category {
            var updated = existingCategory
            updated.name = name
            updated.icon = selectedIcon
            updated.colorHex = selectedColorHex
            dataManager.updateCategory(updated)
        } else {
            let maxOrder = dataManager.categories.map(\.order).max() ?? -1
            let newCategory = Category(name: name, icon: selectedIcon, colorHex: selectedColorHex, order: maxOrder + 1)
            dataManager.addCategory(newCategory)
        }
        dismiss()
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else {
            return nil
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager.shared)
}
