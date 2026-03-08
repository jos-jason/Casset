import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            Group {
                if libraryManager.groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No collections yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Swipe right on a book in your library to add it to a collection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(libraryManager.groups) { group in
                            NavigationLink(
                                destination: GroupDetailView(group: group)
                                    .environmentObject(libraryManager)
                            ) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.yellow)
                                    VStack(alignment: .leading) {
                                        Text(group.name)
                                            .font(.headline)
                                        Text("\(group.bookIDs.count) book\(group.bookIDs.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: libraryManager.removeGroup)
                    }
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingGroup = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .alert("New Collection", isPresented: $isCreatingGroup) {
                TextField("Collection name", text: $newGroupName)
                Button("Create") {
                    if !newGroupName.isEmpty {
                        libraryManager.addGroup(name: newGroupName)
                        newGroupName = ""
                    }
                }
                Button("Cancel", role: .cancel) { newGroupName = "" }
            }
        }
    }
}

