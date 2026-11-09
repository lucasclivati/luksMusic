// LearnHomeView.swift
// luksMusic
//
// The "Aprender" tab: the course's modules and their lessons, with the best result of each.

import SwiftUI

struct LearnHomeView: View {
    @State private var openLesson: Lesson?
    @State private var progress = LessonProgress.shared

    private let lessons = LessonCatalog.allLessons

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Aprenda a ler partitura tocando. Cada aula explica algumas notas e pede para você tocá-las.")
                        .font(.subheadline)
                        .foregroundStyle(PlayerTheme.muted)

                    Label("Toque na tela, em um teclado ligado por USB, ou em um piano de verdade com o microfone (botão no alto da aula).",
                          systemImage: "pianokeys")
                        .font(.footnote)
                        .foregroundStyle(PlayerTheme.text)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PlayerTheme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    ForEach(LessonCatalog.modules) { module in
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(module.title)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(PlayerTheme.text)
                                Text(module.summary)
                                    .font(.footnote)
                                    .foregroundStyle(PlayerTheme.muted)
                            }

                            ForEach(Array(module.lessons.enumerated()), id: \.element.id) { index, lesson in
                                let isOpen = progress.isOpen(lesson, in: lessons)
                                Button {
                                    openLesson = lesson
                                } label: {
                                    lessonRow(lesson, number: index + 1, isOpen: isOpen)
                                }
                                .disabled(!isOpen)
                                .accessibilityIdentifier(lesson.id)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(PlayerTheme.background.ignoresSafeArea())
            .navigationTitle("Aprender")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Liberar todas as aulas", isOn: Binding(
                            get: { progress.unlocksEverything },
                            set: { progress.setUnlocksEverything($0) }
                        ))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Opções das aulas")
                    .accessibilityIdentifier("learnMenuButton")
                }
            }
        }
        .fullScreenCover(item: $openLesson) { lesson in
            LessonPlayerView(lesson: lesson)
        }
    }

    private func lessonRow(_ lesson: Lesson, number: Int, isOpen: Bool) -> some View {
        let earned = progress.stars[lesson.id] ?? 0
        return HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PlayerTheme.background)
                .frame(width: 36, height: 36)
                .background(isOpen ? PlayerTheme.cyan : PlayerTheme.border, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOpen ? PlayerTheme.text : PlayerTheme.muted)
                    .multilineTextAlignment(.leading)
                Text(lesson.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(PlayerTheme.muted)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            if earned > 0 {
                HStack(spacing: 1) {
                    ForEach(1...3, id: \.self) { star in
                        Image(systemName: star <= earned ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(earned) de 3 estrelas")
            } else if !isOpen {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PlayerTheme.muted)
                    .accessibilityLabel("Bloqueada")
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PlayerTheme.muted)
            }
        }
        .padding(12)
        .background(PlayerTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PlayerTheme.raised, lineWidth: 1))
    }
}
