// OnlineLibraryView.swift
// luksMusic
//
// Scores published on luksmusic.web.app that this account can open: public-domain editions for everyone,
// plus private scores for their author and the people the author invited by e-mail.

import SwiftUI

struct OnlineLibraryView: View {
    @State private var library = OnlineLibraryService.shared

    var body: some View {
        List {
            if library.scores.isEmpty && !library.isLoading {
                VStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(library.errorMessage ?? "Nenhuma partitura online disponível para esta conta.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            }

            ForEach(library.scores) { score in
                NavigationLink {
                    OnlineScoreView(score: score)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: score.isPrivate ? "lock.fill" : "music.note.list")
                            .foregroundColor(score.isPrivate ? .purple : .accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(score.title)
                                .font(.subheadline.weight(.semibold))
                            Text(score.credits)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Partituras do luksmusic.web.app, com as páginas originais. As privadas aparecem só para o autor e para quem ele convidou.")
            }
        }
        .overlay {
            if library.isLoading && library.scores.isEmpty {
                ProgressView()
            }
        }
        .navigationTitle("Biblioteca online")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await library.refresh()
        }
        .task {
            await library.refresh()
        }
    }
}
