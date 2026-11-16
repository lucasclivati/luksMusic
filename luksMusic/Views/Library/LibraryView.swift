// LibraryView.swift
// luksMusic
//
// Main library screen: the luksmusic.web.app catalog on top, whose scores download to the phone on a tap and then
// open like the user's own, then the user's own scores in a searchable, filterable grid or list.

import SwiftUI
import SwiftData

// MARK: - Sort & Filter Types

/// Sort options available in the library.
enum LibrarySortOption: String, CaseIterable, Identifiable {
    case dateCreated = "Data de inclusão"
    case title = "Título"
    case difficulty = "Dificuldade"
    case lastPracticed = "Último estudo"

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

/// The main library screen showing the catalog and the user's own scores.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Score.dateCreated, order: .reverse) private var scores: [Score]

    @State private var catalog = OnlineLibraryService.shared
    @State private var path: [Score] = []
    /// The library itself is on screen, with no score or the full catalog pushed over it
    @State private var isInFront = false
    @State private var downloadFailure: DownloadFailure?
    @State private var searchText = ""
    @State private var sortOption: LibrarySortOption = .dateCreated
    @State private var sortAscending = false
    @State private var layout: LibraryLayout = .grid
    @State private var selectedDifficulty: Difficulty?
    @State private var selectedSource: ScoreSource?
    @State private var showFavoritesOnly = false
    @State private var showAddSheet = false
    @State private var showImportSheet = false

    /// Sources a score can still come from (the camera scanner was removed).
    private let filterableSources: [ScoreSource] = [.manual, .imported]

    /// A catalog score that could not be downloaded, and why.
    private struct DownloadFailure {
        let score: OnlineScore
        let message: String
    }

    // MARK: Computed Properties

    /// Filtered and sorted scores based on current search / filter / sort state.
    private var filteredScores: [Score] {
        var result = scores

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.composer.lowercased().contains(query)
            }
        }

        if let difficulty = selectedDifficulty {
            result = result.filter { $0.difficulty == difficulty }
        }

        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }

        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

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

    /// Catalog scores matching the search.
    private var filteredCatalog: [OnlineScore] {
        guard !searchText.isEmpty else { return catalog.scores }
        let query = searchText.lowercased()
        return catalog.scores.filter {
            $0.title.lowercased().contains(query) || $0.credits.lowercased().contains(query)
        }
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
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if catalog.isLoading || !filteredCatalog.isEmpty {
                        catalogSection
                    }

                    localSection
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .onAppear { isInFront = true }
            .onDisappear { isInFront = false }
            .navigationTitle("Biblioteca")
            .searchable(text: $searchText, prompt: "Buscar partituras")
            .toolbar { toolbarContent }
            .navigationDestination(for: Score.self) { score in
                ScoreView(score: score)
            }
            .sheet(isPresented: $showAddSheet) { addScoreSheet }
            .sheet(isPresented: $showImportSheet) {
                ImportScoreView()
            }
            .alert("Não foi possível baixar", isPresented: Binding(
                get: { downloadFailure != nil },
                set: { if !$0 { downloadFailure = nil } }
            ), presenting: downloadFailure) { failure in
                Button("Tentar de novo") {
                    open(failure.score)
                }
                Button("Cancelar", role: .cancel) {}
            } message: { failure in
                Text(failure.message)
            }
            .task(id: catalog.account) {
                await catalog.refreshIfNeeded()
            }
            .refreshable {
                await catalog.refresh()
            }
        }
    }

    // MARK: - Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Catálogo luksMusic")
                        .font(.title3.weight(.bold))
                    Text("Baixe para tocar no app, mesmo sem internet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink {
                    OnlineLibraryView()
                } label: {
                    Text("Ver todas")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("onlineLibraryButton")
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    if catalog.isLoading && catalog.scores.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(width: 140, height: 186)
                        }
                    }
                    ForEach(filteredCatalog) { entry in
                        Button {
                            open(entry)
                        } label: {
                            catalogCard(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private func catalogCard(_ entry: OnlineScore) -> some View {
        let download = catalog.downloads[entry.id]
        let isDownloaded = localCopy(of: entry) != nil
        return VStack(alignment: .leading, spacing: 6) {
            SheetCover(title: entry.pieceTitle, subtitle: entry.composer)
                .frame(width: 140, height: 186)
                .overlay {
                    if let download {
                        downloadProgress(download)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                .overlay(alignment: .topTrailing) {
                    if entry.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7), in: Circle())
                            .padding(6)
                            .accessibilityLabel("Privada")
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if download == nil {
                        Label(isDownloaded ? "Baixada" : "Baixar",
                              systemImage: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(isDownloaded ? Color.green : Color.indigo, in: Capsule())
                            .padding(6)
                    }
                }

            Text(entry.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(entry.credits)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140, alignment: .leading)
    }

    /// Over a card's cover while its score downloads: the part received when the file's size is known.
    private func downloadProgress(_ download: CatalogDownload) -> some View {
        VStack(spacing: 10) {
            if let fraction = download.fraction {
                ProgressView(value: fraction)
                    .tint(.white)
                    .padding(.horizontal, 22)
            } else {
                ProgressView()
                    .tint(.white)
            }
            Text("Baixando…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55))
    }

    /// The phone's copy of a catalog score, or nil when it was not downloaded yet.
    private func localCopy(of entry: OnlineScore) -> Score? {
        scores.first { $0.catalogId == entry.id }
    }

    // MARK: - My Scores

    @ViewBuilder
    private var localSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Minhas partituras")
                .font(.title3.weight(.bold))
            Spacer()
            if activeFilterCount > 0 {
                Button("Limpar filtros") {
                    withAnimation {
                        selectedDifficulty = nil
                        selectedSource = nil
                        showFavoritesOnly = false
                    }
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)

        if scores.isEmpty {
            emptyStateView
        } else if filteredScores.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .padding(.top, 20)
        } else {
            switch layout {
            case .grid:
                gridLayout
            case .list:
                listLayout
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
                NavigationLink(value: score) {
                    ScoreListItemView(score: score, layout: .grid)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    scoreContextMenu(for: score)
                }
            }
        }
        .padding()
    }

    /// List layout with full-width rows.
    private var listLayout: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredScores) { score in
                NavigationLink(value: score) {
                    ScoreListItemView(score: score, layout: .list)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    scoreContextMenu(for: score)
                }
            }
        }
        .padding()
    }

    /// Shown when the user has no scores of their own yet.
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(.indigo)
            Text("Nenhuma partitura sua ainda")
                .font(.headline)
            Text("Importe um arquivo MusicXML ou crie uma partitura nova.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("Adicionar partitura", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal)
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
                                Text("Criar nova")
                                    .font(.body.weight(.medium))
                                Text("Comece com uma partitura em branco")
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
                                Text("Importar arquivo")
                                    .font(.body.weight(.medium))
                                Text("Arquivos MusicXML (.musicxml, .xml, .mxl)")
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
            .navigationTitle("Adicionar partitura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showAddSheet = false }
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
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Adicionar partitura")

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    layout = layout == .grid ? .list : .grid
                }
            } label: {
                Image(systemName: layout == .grid ? "rectangle.grid.1x2" : "square.grid.2x2")
            }
            .accessibilityLabel(layout == .grid ? "Mostrar em lista" : "Mostrar em grade")

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
            .accessibilityLabel("Ordenar")

            Menu {
                Section("Dificuldade") {
                    ForEach(Difficulty.allCases) { difficulty in
                        Button {
                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                        } label: {
                            HStack {
                                Text(difficulty.displayName)
                                if selectedDifficulty == difficulty {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Section("Origem") {
                    ForEach(filterableSources) { source in
                        Button {
                            selectedSource = selectedSource == source ? nil : source
                        } label: {
                            HStack {
                                Label(source.displayName, systemImage: source.iconName)
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
                            Label("Só favoritas", systemImage: "star.fill")
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
            .accessibilityLabel("Filtrar")
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func scoreContextMenu(for score: Score) -> some View {
        Button {
            toggleFavorite(score)
        } label: {
            Label(
                score.isFavorite ? "Remover dos favoritos" : "Favoritar",
                systemImage: score.isFavorite ? "star.slash" : "star.fill"
            )
        }

        Divider()

        Button(role: .destructive) {
            deleteScore(score)
        } label: {
            Label("Apagar", systemImage: "trash")
        }
    }

    // MARK: - Actions

    /// Opens a catalog score's copy on the phone, downloading it first when it is not there yet.
    private func open(_ entry: OnlineScore) {
        if let local = localCopy(of: entry) {
            path.append(local)
            return
        }
        guard catalog.downloads[entry.id] == nil else { return }
        Task {
            do {
                let score = try await catalog.download(entry, into: modelContext)
                // Never pushed over a score opened meanwhile; its card then just says "Baixada"
                if isInFront {
                    path.append(score)
                }
            } catch {
                downloadFailure = DownloadFailure(score: entry, message: error.localizedDescription)
            }
        }
    }

    private func createNewScore() {
        let score = Score(title: "Partitura sem título", composer: "", source: .manual)
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

#Preview("Library") {
    let container = try! ModelContainer(for: Score.self, configurations: .init(isStoredInMemoryOnly: true))

    let sampleScores: [(String, String, Difficulty, ScoreSource)] = [
        ("Moonlight Sonata", "Beethoven", .advanced, .imported),
        ("Für Elise", "Beethoven", .intermediate, .imported),
        ("Prelude in C Major", "Bach", .beginner, .manual),
    ]

    for (title, composer, difficulty, source) in sampleScores {
        let score = Score(
            title: title,
            composer: composer,
            difficulty: difficulty,
            source: source,
            estimatedDuration: 240
        )
        container.mainContext.insert(score)
    }

    return LibraryView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
