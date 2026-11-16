// OnlineScoreView.swift
// luksMusic
//
// A catalog score opened from the full catalog list (OnlineLibraryView): its copy on the phone in the score
// viewer, downloaded into the library first when it is not there yet.

import SwiftUI

struct OnlineScoreView: View {
    let score: OnlineScore

    @State private var catalog = OnlineLibraryService.shared
    @State private var local: Score?
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let local {
            ScoreView(score: local)
        } else {
            VStack(spacing: 0) {
                PlayerTopBar(title: score.pieceTitle, subtitle: score.composer, onBack: { dismiss() }) {
                    EmptyView()
                }

                Group {
                    if let errorMessage {
                        VStack(spacing: 14) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 36))
                                .foregroundStyle(PlayerTheme.muted)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(PlayerTheme.text)
                                .multilineTextAlignment(.center)
                            Button("Tentar de novo") {
                                Task { await load() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PlayerTheme.blue)
                        }
                        .padding(32)
                    } else {
                        VStack(spacing: 12) {
                            if let fraction = catalog.downloads[score.id]?.fraction {
                                ProgressView(value: fraction)
                                    .tint(PlayerTheme.cyan)
                                    .frame(width: 180)
                            } else {
                                ProgressView()
                                    .tint(PlayerTheme.cyan)
                            }
                            Text("Baixando partitura…")
                                .font(.subheadline)
                                .foregroundStyle(PlayerTheme.muted)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(PlayerTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .task {
                await load()
            }
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            local = try await catalog.download(score, into: modelContext)
        } catch {
            errorMessage = String(localized: "Não foi possível baixar a partitura: \(error.localizedDescription)")
        }
    }
}
