// LibraryView.swift
// luksMusic
//
// Main library screen displaying all user scores in a searchable, filterable grid or list.

import SwiftUI
import SwiftData

// MARK: - Sort & Filter Types

/// Sort options available in the library.
enum LibrarySortOption: String, CaseIterable, Identifiable {
    case dateCreated = "Date Added"
    case title = "Title"
    case difficulty = "Difficulty"
    case lastPracticed = "Last Practiced"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .dateCreated: return "calendar"
        case .title: return "textformat.abc"
        case .difficulty: return "speedometer"
        case .lastPracticed: return "clock"
        }
    }
}

/// Layout mode for the library.
enum LibraryLayout: String, CaseIterable {
    case grid
    case list
}

// MARK: - LibraryView

/// The main library screen showing all of the user's musical scores.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Score.dateCreated, order: .reverse) private var scores: [Score]

    @State private var searchText = ""
    @State private var sortOption: LibrarySortOption = .dateCreated
    @State private var sortAscending = false
    @State private var layout: LibraryLayout = .grid
    @State private var selectedDifficulty: Difficulty?
    @State private var selectedSource: ScoreSource?
    @State private var showFavoritesOnly = false
    @State private var showAddSheet = false
    @State private var showImportSheet = false
    @State private var showFilterMenu = false

    // MARK: Computed Properties

    /// Filtered and sorted scores based on current search / filter / sort state.
    private var filteredScores: [Score] {
        var result = scores

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.composer.lowercased().contains(query)
            }
        }

        // Difficulty filter
        if let difficulty = selectedDifficulty {
            result = result.filter { $0.difficulty == difficulty }
        }

        // Source filter
        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }

        // Favorites filter
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        // Sort
        result.sort { a, b in
            let ascending: Bool
            switch sortOption {
            case .dateCreated:
                ascending = a.dateCreated < b.dateCreated
            case .title:
                ascending = a.title.localizedCompare(b.title) == .orderedAscending
            case .difficulty:
                ascending = Difficulty.allCases.firstIndex(of: a.difficulty)! <
                            Difficulty.allCases.firstIndex(of: b.difficulty)!
            case .lastPracticed:
                ascending = (a.lastPracticed ?? .distantPast) < (b.lastPracticed ?? .distantPast)
            }
            return sortAscending ? ascending : !ascending
        }

        return result
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedDifficulty != nil { count += 1 }
        if selectedSource != nil { count += 1 }
        if showFavoritesOnly { count += 1 }
        return count
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if scores.isEmpty && searchText.isEmpty {
                    emptyStateView
                } else {
                    scoreContentView
                }

                addButton
            }
            .background(Color(.systemBackground))
            .navigationTitle("My Library")
            .searchable(text: $searchText, prompt: "Search scores…")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddSheet) { addScoreSheet }
            .sheet(isPresented: $showImportSheet) {
                ImportScoreView()
            }
        }
    }

    // MARK: - Subviews

    /// Content area showing either the grid or list of scores.
    @ViewBuilder
    private var scoreContentView: some View {
        VStack(spacing: 0) {
            // Active filters bar
            if activeFilterCount > 0 {
                activeFiltersBar
            }

            if filteredScores.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    switch layout {
                    case .grid:
                        gridLayout
                    case .list:
                        listLayout
                    }
                }
            }
        }
    }

    /// Grid layout with two columns of score cards.
    private var gridLayout: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredScores) { score in
                NavigationLink(value: score.id) {
                    ScoreListItemView(score: score, layout: .grid)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    scoreContextMenu(for: score)
                }
            }
        }
        .padding()
        .navigationDestination(for: UUID.self) { scoreID in
            if let score = scores.first(where: { $0.id == scoreID }) {
                ScoreView(score: score)
            }
        }
    }

    /// List layout with full-width rows.
    private var listLayout: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredScores) { score in
                NavigationLink(value: score.id) {
                    ScoreListItemView(score: score, layout: .list)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteScore(score)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        toggleFavorite(score)
                    } label: {
                        Label(
                            score.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: score.isFavorite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(.yellow)
                }
                .contextMenu {
                    scoreContextMenu(for: score)
                }
            }
        }
        .padding()
        .navigationDestination(for: UUID.self) { scoreID in
            if let score = scores.first(where: { $0.id == scoreID }) {
                ScoreView(score: score)
            }
        }
    }

    /// Active filters horizontal strip.
    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let difficulty = selectedDifficulty {
                    filterChip(difficulty.rawValue) {
                        withAnimation { selectedDifficulty = nil }
                    }
                }
                if let source = selectedSource {
                    filterChip(source.rawValue) {
                        withAnimation { selectedSource = nil }
                    }
                }
                if showFavoritesOnly {
                    filterChip("Favorites") {
                        withAnimation { showFavoritesOnly = false }
                    }
                }

                Button("Clear All") {
                    withAnimation {
                        selectedDifficulty = nil
                        selectedSource = nil
                        showFavoritesOnly = false
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    /// A removable filter chip.
    private func filterChip(_ label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.indigo.opacity(0.25), in: Capsule())
        .foregroundStyle(.indigo)
    }

    /// Empty state shown when no scores exist.
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.indigo.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "music.note.list")
                    .font(.system(size: 56))
                    .foregroundStyle(.indigo)
            }

            VStack(spacing: 8) {
                Text("No Scores Yet")
                    .font(.title2.bold())

                Text("Add your first score by tapping the\nbutton below to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddSheet = true
            } label: {
                Label("Add Score", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)

            Spacer()
            Spacer()
        }
        .padding()
    }

    /// Floating add button in the bottom-right corner.
    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.indigo, in: Circle())
                .shadow(color: .indigo.opacity(0.4), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("Add new score")
    }

    /// Bottom sheet for choosing how to add a score.
    private var addScoreSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showAddSheet = false
                        createNewScore()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create New")
                                    .font(.body.weight(.medium))
                                Text("Start with an empty score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "pencil.and.outline")
                                .foregroundStyle(.indigo)
                        }
                    }

                    Button {
                        showAddSheet = false
                        showImportSheet = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import File")
                                    .font(.body.weight(.medium))
                                Text("MusicXML files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.down.doc")
                                .foregroundStyle(.indigo)
                        }
                    }
                }
            }
            .navigationTitle("Add Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            // Layout toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    layout = layout == .grid ? .list : .grid
                }
            } label: {
                Image(systemName: layout == .grid ? "rectangle.grid.1x2" : "square.grid.2x2")
            }

            // Sort menu
            Menu {
                ForEach(LibrarySortOption.allCases) { option in
                    Button {
                        if sortOption == option {
                            sortAscending.toggle()
                        } else {
                            sortOption = option
                            sortAscending = false
                        }
                    } label: {
                        HStack {
                            Label(option.rawValue, systemImage: option.iconName)
                            if sortOption == option {
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }

            // Filter menu
            Menu {
                // Difficulty filters
                Section("Difficulty") {
                    ForEach(Difficulty.allCases) { difficulty in
                        Button {
                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                        } label: {
                            HStack {
                                Text(difficulty.rawValue)
                                if selectedDifficulty == difficulty {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                // Source filters
                Section("Source") {
                    ForEach(ScoreSource.allCases) { source in
                        Button {
                            selectedSource = selectedSource == source ? nil : source
                        } label: {
                            HStack {
                                Label(source.rawValue, systemImage: source.iconName)
                                if selectedSource == source {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        HStack {
                            Label("Favorites Only", systemImage: "star.fill")
                            if showFavoritesOnly {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(activeFilterCount > 0 ? .indigo : .primary)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func scoreContextMenu(for score: Score) -> some View {
        Button {
            toggleFavorite(score)
        } label: {
            Label(
                score.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: score.isFavorite ? "star.slash" : "star.fill"
            )
        }

        Divider()

        Button(role: .destructive) {
            deleteScore(score)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func createNewScore() {
        let score = Score(title: "Untitled Score", composer: "", source: .manual)
        modelContext.insert(score)
    }

    private func toggleFavorite(_ score: Score) {
        score.isFavorite.toggle()
    }

    private func deleteScore(_ score: Score) {
        modelContext.delete(score)
    }
}

// MARK: - Preview

#Preview("Library - Empty") {
    LibraryView()
        .modelContainer(for: Score.self, inMemory: true)
        .preferredColorScheme(.dark)
}

#Preview("Library - With Scores") {
    let container = try! ModelContainer(for: Score.self, configurations: .init(isStoredInMemoryOnly: true))

    let sampleScores: [(String, String, Difficulty, ScoreSource)] = [
        ("Moonlight Sonata", "Beethoven", .advanced, .imported),
        ("Für Elise", "Beethoven", .intermediate, .imported),
        ("Prelude in C Major", "Bach", .beginner, .manual),
        ("Nocturne Op. 9 No. 2", "Chopin", .expert, .scanned),
        ("Clair de Lune", "Debussy", .advanced, .imported),
    ]

    for (title, composer, difficulty, source) in sampleScores {
        let score = Score(
            title: title,
            composer: composer,
            difficulty: difficulty,
            source: source,
            estimatedDuration: TimeInterval.random(in: 120...600)
        )
        score.isFavorite = Bool.random()
        score.lastPracticed = Date().addingTimeInterval(-Double.random(in: 0...604800))
        container.mainContext.insert(score)
    }

    return LibraryView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
