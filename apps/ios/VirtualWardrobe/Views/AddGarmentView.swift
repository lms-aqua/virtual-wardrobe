import SwiftUI

/// Add your own garment (name + category + color) to try on in 3D. Stored
/// locally; try-on only (not saved into synced outfits).
struct AddGarmentView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdded: () -> Void

    @State private var name = ""
    @State private var category = "top"
    @State private var colorHex = CustomGarments.palette[0]

    private let categories = [
        ("top", "T-shirt / top"), ("dress", "Dress"), ("bottom", "Bottoms"),
        ("outerwear", "Jacket / coat"), ("footwear", "Shoes"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                Form {
                    Section("Name") {
                        TextField("e.g. My red jacket", text: $name)
                    }
                    Section("Type") {
                        Picker("Type", selection: $category) {
                            ForEach(categories, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        .pickerStyle(.inline).labelsHidden()
                    }
                    Section("Colour") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ForEach(CustomGarments.palette, id: \.self) { hex in
                                Circle().fill(Color(hex: hex)).frame(height: 40)
                                    .overlay(Circle().stroke(colorHex == hex ? .white : .clear, lineWidth: 3))
                                    .onTapGesture { colorHex = hex }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add clothing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        CustomGarments.add(name: name, category: category, colorHex: colorHex)
                        onAdded(); dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
