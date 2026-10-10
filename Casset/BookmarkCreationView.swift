import SwiftUI

struct BookmarkCreationView: View {
    @Binding var label: String
    @Binding var selectedColor: String
    @Binding var note: String
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let colors: [(name: String, color: Color)] = [
        ("default", Color.primary),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("e.g. Great quote, Chapter note...", text: $label)
                }
                
                Section {
                    TextField("Add an optional note...", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Note (Optional)")
                } footer: {
                    Text("You can add more details about this bookmark or leave it blank.")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colors, id: \.name) { item in
                            ZStack {
                                Circle()
                                    .fill(item.name == "default"
                                          ? (colorScheme == .dark ? Color.white : Color.black)
                                          : item.color)
                                    .frame(width: 32, height: 32)
                                if selectedColor == item.name {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(item.name == "yellow" ? .black : .white)
                                }
                            }
                            .onTapGesture { selectedColor = item.name }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                } footer: {
                    Text("Default follows your current light/dark mode.")
                }
            }
            .navigationTitle("New Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        label = ""
                        selectedColor = "default"
                        note = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

