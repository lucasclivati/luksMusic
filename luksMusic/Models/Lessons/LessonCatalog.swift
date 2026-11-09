// LessonCatalog.swift
// luksMusic
//
// The lessons themselves. Each one introduces a few notes, has them played with help, then without.

import Foundation

enum LessonCatalog {

    static let modules: [LessonModule] = [trebleClef]

    static var allLessons: [Lesson] { modules.flatMap(\.lessons) }

    static func lesson(after lesson: Lesson) -> Lesson? {
        let lessons = allLessons
        guard let index = lessons.firstIndex(where: { $0.id == lesson.id }), index + 1 < lessons.count else { return nil }
        return lessons[index + 1]
    }

    // MARK: - Clave de Sol

    private static let trebleClef = LessonModule(
        id: "treble",
        title: "Clave de sol",
        summary: "Mão direita, do Dó central ao Dó de cima",
        lessons: [middleC, cDE, fG, aBC, scaleUp, scaleDown]
    )

    private static let middleC = Lesson(
        id: "treble-1",
        title: "O Dó central",
        summary: "Como achar o Dó no piano e na pauta",
        steps: [
            LessonStep(.explain, "Ache o Dó no piano",
                       "As teclas pretas vêm em grupos de 2 e de 3. O Dó é a tecla branca logo à esquerda de cada grupo de 2.",
                       litKeys: "C4 C5"),
            LessonStep(.explain, "O Dó central",
                       "É o Dó mais perto do meio do piano. Na clave de sol, ele fica numa linha curta, logo abaixo das cinco linhas da pauta.",
                       notes: "C4"),
            LessonStep(.guided, "Toque o Dó central", "Use o polegar da mão direita.", notes: "C4"),
            LessonStep(.alone, "Agora sem ajuda", "Toque o Dó central três vezes. Cada toque vale uma nota.", notes: "C4 C4 C4"),
        ]
    )

    private static let cDE = Lesson(
        id: "treble-2",
        title: "Dó, Ré, Mi",
        summary: "As três primeiras notas",
        steps: [
            LessonStep(.explain, "O Ré", "É a tecla branca logo à direita do Dó. Na pauta, ele fica logo abaixo da primeira linha.", notes: "C4 D4"),
            LessonStep(.explain, "O Mi", "É a tecla branca seguinte. Na pauta, ele fica em cima da primeira linha.", notes: "C4 D4 E4"),
            LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "C4 D4 E4"),
            LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "E4 D4 C4"),
            LessonStep(.alone, "Misturando", "As notas agora vêm fora de ordem.", notes: "D4 E4 C4 D4"),
        ]
    )

    private static let fG = Lesson(
        id: "treble-3",
        title: "Fá e Sol",
        summary: "A clave de sol marca a linha do Sol",
        steps: [
            LessonStep(.explain, "O Fá", "É a tecla branca logo à esquerda do grupo de 3 teclas pretas. Na pauta, ele fica no primeiro espaço, entre a primeira e a segunda linha.", notes: "E4 F4"),
            LessonStep(.explain, "O Sol", "Fica na segunda linha, a que a curva da clave de sol envolve. É daí que vem o nome da clave.", notes: "F4 G4"),
            LessonStep(.guided, "Toque com ajuda", "Do Dó ao Sol: um dedo para cada nota.", notes: "C4 D4 E4 F4 G4"),
            LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "G4 F4 E4"),
            LessonStep(.alone, "Misturando", "As notas agora vêm fora de ordem.", notes: "E4 G4 F4 D4"),
            LessonStep(.listen, "Ouça e repita", "Primeiro o app toca. Depois é a sua vez.", notes: "C4 E4 G4"),
        ]
    )

    private static let aBC = Lesson(
        id: "treble-4",
        title: "Lá, Si e o outro Dó",
        summary: "Até o Dó de cima",
        steps: [
            LessonStep(.explain, "O Lá", "Vem depois do Sol. Na pauta, ele fica no segundo espaço.", notes: "G4 A4"),
            LessonStep(.explain, "O Si", "Fica na terceira linha, bem no meio da pauta.", notes: "A4 B4"),
            LessonStep(.explain, "O outro Dó", "Depois do Si, os nomes recomeçam. Este Dó é o oitavo som a partir do Dó central e fica no terceiro espaço.", notes: "C4 C5"),
            LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "G4 A4 B4 C5"),
            LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "C5 B4 A4 G4"),
            LessonStep(.alone, "Misturando", "As notas agora vêm fora de ordem.", notes: "A4 C5 G4 B4"),
            LessonStep(.listen, "Ouça e repita", "Primeiro o app toca. Depois é a sua vez.", notes: "G4 B4 C5"),
        ]
    )

    private static let scaleUp = Lesson(
        id: "treble-5",
        title: "A escala subindo",
        summary: "Do Dó central ao Dó de cima",
        steps: [
            LessonStep(.explain, "A escala de Dó", "São oito notas vizinhas, todas em teclas brancas. Na pauta, cada nota sobe um degrau: linha, espaço, linha, espaço.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
            LessonStep(.guided, "Toque com ajuda", "Suba devagar, nota por nota.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
            LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e suba até o Dó de cima.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
            LessonStep(.listen, "Ouça e repita", "Primeiro o app toca. Depois é a sua vez.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
        ]
    )

    private static let scaleDown = Lesson(
        id: "treble-6",
        title: "A escala descendo",
        summary: "O caminho de volta",
        steps: [
            LessonStep(.explain, "Descendo", "Agora o caminho contrário: comece no Dó de cima e desça um degrau por vez até o Dó central.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
            LessonStep(.guided, "Toque com ajuda", "Desça devagar, nota por nota.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
            LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e desça até o Dó central.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
            LessonStep(.listen, "Ouça e repita", "Primeiro o app toca. Depois é a sua vez.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
        ]
    )
}
