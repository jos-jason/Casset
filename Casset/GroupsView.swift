import SwiftUI

// MARK: - Collection Cover Grid
/// Shows a 2x2 grid of book covers for a collection's icon.
struct CollectionCoverGrid: View {
    let books: [Book]
    let size: CGFloat

    private var covers: [Book] {
        Array(books.prefix(4))
    }

    private var cellSize: CGFloat {
        (size - 2) / 2 // 2pt gap between cells
    }

    var body: some View {
        Group {
            if covers.isEmpty {
                // No books — show folder icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.secondary)
                    )
            } else {
                let columns = [
                    GridItem(.fixed(cellSize), spacing: 2),
                    GridItem(.fixed(cellSize), spacing: 2)
                ]
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        if index < covers.count,
                           let artURL = covers[index].bestCoverArtURL(),
                           let uiImage = UIImage(contentsOfFile: artURL.path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: cellSize * 0.4))
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Cassette-style Collection Row
/// Mimics the CassetteSpineView look: black outer box, white borders, 3D depth lines,
/// with the multi-image grid on the left and collection name + count on the right.
struct CollectionCassetteRow: View {
    let group: BookGroup
    let books: [Book]
    let bookCount: Int

    private let lineColor = Color.white
    private let lineWidth: CGFloat = 1.2

    var body: some View {
        let innerBox = HStack(spacing: 0) {
            // Cover grid on the left, sized to fill height
            CollectionCoverGrid(books: books, size: 62)
                .frame(maxHeight: .infinity)

            // Divider
            lineColor.opacity(0.6)
                .frame(width: lineWidth, height: 34)
                .padding(.leading, 8)

            // Title + count
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(lineColor)
                Text("\(bookCount) book\(bookCount == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(lineColor.opacity(0.7))
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .strokeBorder(lineColor.opacity(0.5), lineWidth: lineWidth)
        )

        // Outer cassette box
        innerBox
            .padding(12)
            .background(Color.black)
            .overlay(
                GeometryReader { geo in
                    let inset: CGFloat = 12
                    let lineLen: CGFloat = 8
                    let opacity: Double = 0.35
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: lineLen, y: -lineLen))
                        p.move(to: CGPoint(x: geo.size.width, y: 0))
                        p.addLine(to: CGPoint(x: geo.size.width + lineLen, y: -lineLen))
                        p.move(to: CGPoint(x: inset, y: inset))
                        p.addLine(to: CGPoint(x: inset + lineLen, y: inset - lineLen))
                        p.move(to: CGPoint(x: geo.size.width - inset, y: inset))
                        p.addLine(to: CGPoint(x: geo.size.width - inset + lineLen, y: inset - lineLen))
                        p.move(to: CGPoint(x: 0, y: geo.size.height))
                        p.addLine(to: CGPoint(x: lineLen, y: geo.size.height - lineLen))
                        p.move(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.addLine(to: CGPoint(x: geo.size.width + lineLen, y: geo.size.height - lineLen))
                        p.move(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset))
                        p.addLine(to: CGPoint(x: geo.size.width - inset + lineLen, y: geo.size.height - inset - lineLen))
                    }
                    .stroke(lineColor.opacity(opacity), lineWidth: 0.8)
                }
            )
            .overlay(
                Rectangle()
                    .strokeBorder(lineColor.opacity(0.6), lineWidth: lineWidth)
            )
    }
}

struct GroupsView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @EnvironmentObject var playerScreenTracker: PlayerScreenTracker
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""

    @AppStorage("useSimpleLibrary") var useSimpleLibrary: Bool = false

    // Mini player navigation (driven from outside or internally)
    @Binding var miniPlayerTarget: Book?
    @Binding var isPushingFromMini: Bool
    
    func actualBookCount(for group: BookGroup) -> Int {
        libraryManager.books.filter { group.bookIDs.contains($0.id) }.count
    }

    func booksInGroup(_ group: BookGroup) -> [Book] {
        libraryManager.books.filter { group.bookIDs.contains($0.id) }
    }

    @ViewBuilder
    private func miniPlayerDestination() -> some View {
        if let target = miniPlayerTarget {
            PlayerView(book: target)
                .environmentObject(libraryManager)
                .environmentObject(playerManager)
                .environmentObject(playerScreenTracker)
        } else {
            EmptyView()
        }
    }

    private var hasAnyGroups: Bool {
        !libraryManager.seriesGroups.isEmpty
        || !libraryManager.authorGroups.isEmpty
        || !libraryManager.manualGroups.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationLink(
                    destination: miniPlayerDestination(),
                    isActive: $isPushingFromMini
                ) { EmptyView() }
                .hidden()

                Group {
                    if !hasAnyGroups {
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
                    } else if useSimpleLibrary {
                        simpleListBody
                    } else {
                        cassetteBody
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

    // MARK: - Simple List Layout

    private var simpleListBody: some View {
        List {
            if !libraryManager.manualGroups.isEmpty {
                Section("Your Collections") {
                    ForEach(libraryManager.manualGroups) { group in
                        simpleRow(for: group)
                    }
                    .onDelete(perform: deleteManualGroups)
                }
            }
            if !libraryManager.seriesGroups.isEmpty {
                Section("Series") {
                    ForEach(libraryManager.seriesGroups) { group in
                        simpleRow(for: group)
                    }
                }
            }
            if !libraryManager.authorGroups.isEmpty {
                Section("Authors") {
                    ForEach(libraryManager.authorGroups) { group in
                        simpleRow(for: group)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func simpleRow(for group: BookGroup) -> some View {
        NavigationLink(
            destination: GroupDetailView(group: group)
                .environmentObject(libraryManager)
        ) {
            let count = actualBookCount(for: group)
            HStack(spacing: 14) {
                CollectionCoverGrid(
                    books: booksInGroup(group),
                    size: 56
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                    Text("\(count) book\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Cassette Layout

    private var cassetteBody: some View {
        ScrollView {
            VStack(spacing: 10) {
                if !libraryManager.manualGroups.isEmpty {
                    sectionHeader("Your Collections")
                    ForEach(libraryManager.manualGroups) { group in
                        cassetteRow(for: group)
                    }
                }
                if !libraryManager.seriesGroups.isEmpty {
                    sectionHeader("Series")
                    ForEach(libraryManager.seriesGroups) { group in
                        cassetteRow(for: group)
                    }
                }
                if !libraryManager.authorGroups.isEmpty {
                    sectionHeader("Authors")
                    ForEach(libraryManager.authorGroups) { group in
                        cassetteRow(for: group)
                    }
                }
            }
            .padding(12)
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    @ViewBuilder
    private func cassetteRow(for group: BookGroup) -> some View {
        NavigationLink(
            destination: GroupDetailView(group: group)
                .environmentObject(libraryManager)
        ) {
            CollectionCassetteRow(
                group: group,
                books: booksInGroup(group),
                bookCount: actualBookCount(for: group)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Deletes manual groups from the filtered manualGroups list.
    private func deleteManualGroups(at offsets: IndexSet) {
        let manualIDs = libraryManager.manualGroups.map(\.id)
        let idsToRemove = offsets.map { manualIDs[$0] }
        for id in idsToRemove {
            if let idx = libraryManager.groups.firstIndex(where: { $0.id == id }) {
                libraryManager.groups.remove(at: idx)
            }
        }
        libraryManager.saveGroupsPublic()
    }
}

