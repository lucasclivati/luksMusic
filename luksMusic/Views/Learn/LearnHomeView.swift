// LearnHomeView.swift
// luksMusic
//
// The "Aprender" tab: the course's modules and their lessons.

import SwiftUI

struct LearnHomeView: View {
    @State private var openLesson: Lesson?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Aprenda a ler partitura tocando. Cada aula explica algumas notas e pede para você tocá-las.")
                        .font(.subheadline)
                        .foregroundStyle(PlayerTheme.muted)

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
                                Button {
                                    openLesson = lesson
                                } label: {
                                    lessonRow(lesson, number: index + 1)
                                }
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
        }
        .fullScreenCover(item: $openLesson) { lesson in
            LessonPlayerView(lesson: lesson)
        }
    }

    private func lessonRow(_ lesson: Lesson, number: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PlayerTheme.background)
                .frame(width: 36, height: 36)
                .background(PlayerTheme.cyan, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PlayerTheme.text)
                Text(lesson.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(PlayerTheme.muted)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PlayerTheme.muted)
        }
        .padding(12)
        .background(PlayerTheme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PlayerTheme.raised, lineWidth: 1))
    }
}
