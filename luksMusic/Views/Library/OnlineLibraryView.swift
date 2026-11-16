// OnlineLibraryView.swift
// luksMusic
//
// The whole luksMusic catalog ("Ver todas"): the scores of luksmusic.web.app this account can download, public-domain
// editions for everyone plus private scores for their author and the people the author invited by e-mail. Opening
// one downloads it to the phone (OnlineScoreView) and plays it like the user's own scores.

import SwiftData
import SwiftUI

struct OnlineLibraryView: View {
    @State private var library = OnlineLibraryService.shared
    @Query private var localScores: [Score]

    var body: some View {
        let downloaded = Set(localScores.compactMap(\.catalogId))
        return List {
            if library.scores.isEmpty && !library.isLoading {
                VStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(library.errorMessage ?? String(localized: "Nenhuma partitura do catálogo disponível para esta conta."))
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
                        Spacer(minLength: 4)
                        Label(downloaded.contains(score.id) ? "Baixada" : "Baixar",
                              systemImage: downloaded.contains(score.id) ? "checkmark.circle.fill" : "arrow.down.circle")
                            .labelStyle(.iconOnly)
                            .foregroundColor(downloaded.contains(score.id) ? .green : .accentColor)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Toque em uma partitura para baixá-la e tocar no celular, mesmo sem internet. As privadas aparecem só para o autor e para quem ele convidou.")
            }
        }
        .overlay {
            if library.isLoading && library.scores.isEmpty {
                ProgressView()
            }
        }
        .navigationTitle("Catálogo luksMusic")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await library.refresh()
        }
        .task(id: library.account) {
            await library.refresh()
        }
    }
}
