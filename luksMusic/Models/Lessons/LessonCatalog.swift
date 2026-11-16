// LessonCatalog.swift
// luksMusic
//
// The lessons themselves, in teaching order. A lesson is short and each of its steps does something different:
// new notes are learned by playing them, a drill draws notes from everything learned so far (the new ones more
// often), and the lesson ends with a short piece that uses them. Songs are traditional melodies or by composers
// long in the public domain, written out here.

import Foundation

enum LessonCatalog {

    static let modules: [LessonModule] = [
        trebleClef, bassClef, bothClefs, accidentals, rhythm, keySignatures, handsAndChords, songs, ear,
    ]

    static var allLessons: [Lesson] { modules.flatMap(\.lessons) }

    static func lesson(after lesson: Lesson) -> Lesson? {
        let lessons = allLessons
        guard let index = lessons.firstIndex(where: { $0.id == lesson.id }), index + 1 < lessons.count else { return nil }
        return lessons[index + 1]
    }

    /// The notes of a lesson's whole module, so the keyboard moves as little as possible between its lessons.
    static func keyboardNotes(for lesson: Lesson) -> ClosedRange<Int>? {
        let lessons = modules.first { $0.lessons.contains { $0.id == lesson.id } }?.lessons ?? [lesson]
        let ranges = lessons.compactMap(\.midiRange)
        guard let low = ranges.map(\.lowerBound).min(), let high = ranges.map(\.upperBound).max() else { return nil }
        return low...high
    }

    private static let drill = String(localized: "Sem ajuda. Se errar duas vezes, a tecla acende.")
    private static let atYourPace = String(localized: "Toque em Ouvir para escutar, depois leia e toque no seu ritmo.")

    // Pieces used in more than one lesson
    private static let hotCrossBuns = "E4 D4 C4:h E4 D4 C4:h C4:e C4:e C4:e C4:e D4:e D4:e D4:e D4:e E4 D4 C4:h"
    private static let odeToJoy = "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:q. D4:e D4:h"
    private static let twinkle = "C4 C4 G4 G4 A4 A4 G4:h F4 F4 E4 E4 D4 D4 C4:h"
    private static let maryHalf = "E4 D4 C4 D4 E4 E4 E4:h D4 D4 D4:h E4 G4 G4:h"

    // MARK: - Clave de Sol

    private static let trebleClef = LessonModule(
        id: "treble",
        title: String(localized: "Clave de sol"),
        summary: String(localized: "Mão direita, do Dó central para cima"),
        lessons: [
            Lesson(id: "treble-1", title: String(localized: "O Dó central"), summary: String(localized: "Como achar o Dó no piano e na pauta"), steps: [
                LessonStep(.learn, String(localized: "Ache o Dó"),
                           String(localized: "As teclas pretas vêm em grupos de 2 e de 3. O Dó é a tecla branca logo à esquerda de cada grupo de 2. Toque os dois Dós acesos."),
                           notes: "C4 C5"),
                LessonStep(.learn, String(localized: "Nota nova: Dó central"),
                           String(localized: "É o Dó mais perto do meio do piano. Na clave de sol, ele fica numa linha curta, logo abaixo das cinco linhas. Toque com o polegar direito."),
                           notes: "C4"),
                LessonStep(.read, String(localized: "Sua vez"), String(localized: "Toque o Dó central três vezes. Cada toque vale uma nota."), notes: "C4 C4 C4"),
            ]),
            Lesson(id: "treble-2", title: String(localized: "Dó, Ré, Mi"), summary: String(localized: "As três primeiras notas"), steps: [
                LessonStep(.learn, String(localized: "Nota nova: Ré"), String(localized: "É a tecla branca logo à direita do Dó. Na pauta, fica logo abaixo da primeira linha. Toque o Ré."), notes: "D4"),
                LessonStep(.learn, String(localized: "Nota nova: Mi"), String(localized: "É a tecla branca seguinte. Na pauta, fica em cima da primeira linha. Toque o Mi."), notes: "E4"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas entre Dó, Ré e Mi. \(drill)"), pool: "C4 D4 E4", focus: "D4 E4"),
                LessonStep(.read, String(localized: "Música: Hot Cross Buns"), String(localized: "Uma canção infantil inglesa só com Mi, Ré e Dó. \(atYourPace)"), notes: hotCrossBuns, meter: 4),
            ]),
            Lesson(id: "treble-3", title: String(localized: "Fá e Sol"), summary: String(localized: "A clave de sol marca a linha do Sol"), steps: [
                LessonStep(.learn, String(localized: "Nota nova: Fá"), String(localized: "É a tecla branca logo à esquerda do grupo de 3 teclas pretas. Na pauta, fica no primeiro espaço. Toque o Fá."), notes: "F4"),
                LessonStep(.learn, String(localized: "Nota nova: Sol"), String(localized: "Fica na segunda linha, a que a curva da clave de sol envolve. É daí que vem o nome da clave. Toque o Sol."), notes: "G4"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas do Dó ao Sol. \(drill)"), pool: "C4 D4 E4 F4 G4", focus: "F4 G4"),
                LessonStep(.read, String(localized: "Música: Ode à Alegria"), String(localized: "O tema de Beethoven usa só as notas do Dó ao Sol. \(atYourPace)"), notes: odeToJoy, meter: 4),
            ]),
            Lesson(id: "treble-4", title: String(localized: "Lá, Si e o outro Dó"), summary: String(localized: "Até o Dó de cima"), steps: [
                LessonStep(.learn, String(localized: "Nota nova: Lá"), String(localized: "Vem depois do Sol. Na pauta, fica no segundo espaço. Toque o Lá."), notes: "A4"),
                LessonStep(.learn, String(localized: "Nota nova: Si"), String(localized: "Fica na terceira linha, bem no meio da pauta. Toque o Si."), notes: "B4"),
                LessonStep(.learn, String(localized: "Nota nova: o Dó de cima"), String(localized: "Depois do Si, os nomes recomeçam. Este Dó é o oitavo som a partir do Dó central e fica no terceiro espaço. Toque-o."), notes: "C5"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas do Dó central ao Dó de cima. \(drill)"), pool: "C4 D4 E4 F4 G4 A4 B4 C5", focus: "A4 B4 C5"),
                LessonStep(.read, String(localized: "Música: Brilha, Brilha, Estrelinha"), String(localized: "Melodia tradicional que sobe até o Lá. \(atYourPace)"), notes: twinkle, meter: 4),
            ]),
            Lesson(id: "treble-5", title: String(localized: "A escala subindo"), summary: String(localized: "Do Dó central ao Dó de cima"), steps: [
                LessonStep(.learn, String(localized: "A escala de Dó"), String(localized: "São oito notas vizinhas, todas em teclas brancas. Na pauta, cada nota sobe um degrau: linha, espaço, linha, espaço. Suba pelas teclas acesas."), notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.read, String(localized: "Subindo sem ajuda"), String(localized: "Leia a pauta e suba até o Dó de cima."), notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.read, String(localized: "Linhas e espaços"), String(localized: "Primeiro as notas nas linhas, depois as dos espaços: pulando uma tecla de cada vez."), notes: "E4 G4 B4 F4 A4 C5"),
            ]),
            Lesson(id: "treble-6", title: String(localized: "A escala descendo"), summary: String(localized: "O caminho de volta"), steps: [
                LessonStep(.learn, String(localized: "Descendo"), String(localized: "Agora o caminho contrário: comece no Dó de cima e desça um degrau por vez até o Dó central, pelas teclas acesas."), notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(.read, String(localized: "Descendo sem ajuda"), String(localized: "Leia a pauta e desça até o Dó central."), notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas do Dó ao Dó. \(drill)"), pool: "C4 D4 E4 F4 G4 A4 B4 C5"),
            ]),
            Lesson(id: "treble-7", title: String(localized: "Ré, Mi, Fá e Sol de cima"), summary: String(localized: "O alto da pauta"), steps: [
                LessonStep(.learn, String(localized: "Notas novas: Ré e Mi"), String(localized: "O Ré fica na quarta linha, e o Mi no quarto espaço. Toque os dois."), notes: "D5 E5"),
                LessonStep(.learn, String(localized: "Notas novas: Fá e Sol"), String(localized: "O Fá fica na quinta linha, a última. O Sol fica logo acima dela. Toque os dois."), notes: "F5 G5"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas do Sol ao Sol de cima. \(drill)"), pool: "G4 A4 B4 C5 D5 E5 F5 G5", focus: "D5 E5 F5 G5"),
                LessonStep(.read, String(localized: "Música: Ode à Alegria, uma oitava acima"), String(localized: "A mesma melodia da aula Fá e Sol, oito notas mais aguda: mesmas teclas, mais à direita. \(atYourPace)"),
                           notes: "E5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 E5:q. D5:e D5:h", meter: 4),
            ]),
            Lesson(id: "treble-8", title: String(localized: "Linhas extras em cima"), summary: String(localized: "Lá, Si e Dó acima da pauta"), steps: [
                LessonStep(.learn, String(localized: "Nota nova: Lá agudo"), String(localized: "Quando a nota passa das cinco linhas, a pauta ganha linhas curtas. O Lá fica na primeira linha curta acima da pauta. Toque o Lá."), notes: "A5"),
                LessonStep(.learn, String(localized: "Notas novas: Si e Dó agudos"), String(localized: "O Si fica logo acima dessa linha. O Dó fica na segunda linha curta. Toque os dois."), notes: "B5 C6"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas no alto da pauta. \(drill)"), pool: "E5 F5 G5 A5 B5 C6", focus: "A5 B5 C6"),
            ]),
            Lesson(id: "treble-9", title: String(localized: "Desafio da clave de sol"), summary: String(localized: "Notas sorteadas, sem ajuda"), steps: [
                LessonStep(.read, String(localized: "Até o Dó de cima"), String(localized: "Dez notas sorteadas. \(drill)"), pool: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.read, String(localized: "Pauta inteira"), String(localized: "Dez notas sorteadas, do Dó central ao Dó mais alto. \(drill)"),
                           pool: "C4 D4 E4 F4 G4 A4 B4 C5 D5 E5 F5 G5 A5 B5 C6"),
            ]),
        ]
    )

    // MARK: - Clave de Fá

    private static let bassClef = LessonModule(
        id: "bass",
        title: String(localized: "Clave de fá"),
        summary: String(localized: "Mão esquerda, do Dó central para baixo"),
        lessons: [
            Lesson(id: "bass-1", title: String(localized: "A clave de fá"), summary: String(localized: "A pauta da mão esquerda"), steps: [
                LessonStep(.learn, String(localized: "Nota nova: o Fá da clave"), String(localized: "A mão esquerda costuma ler esta clave. Os dois pontos dela ficam em volta da quarta linha, e essa linha é o Fá. Toque com a mão esquerda."), notes: "F3", staff: .bass),
                LessonStep(.learn, String(localized: "O mesmo Dó central"), String(localized: "Nesta clave, o Dó central fica numa linha curta acima das cinco linhas. É a mesma tecla da clave de sol. Toque-o."), notes: "C4", staff: .bass),
                LessonStep(.read, String(localized: "Sua vez"), String(localized: "Leia a pauta: só Fá e Dó."), notes: "F3 C4 F3 F3 C4", staff: .bass),
            ]),
            Lesson(id: "bass-2", title: String(localized: "Si, Lá e Sol"), summary: String(localized: "Descendo a partir do Dó central"), steps: [
                LessonStep(.learn, String(localized: "Nota nova: Si"), String(localized: "É a tecla logo à esquerda do Dó central. Na pauta, fica logo acima da quinta linha. Toque o Si."), notes: "B3", staff: .bass),
                LessonStep(.learn, String(localized: "Notas novas: Lá e Sol"), String(localized: "O Lá fica na quinta linha, a de cima. O Sol fica no quarto espaço. Toque os dois."), notes: "A3 G3", staff: .bass),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas do Dó central ao Fá. \(drill)"), staff: .bass, pool: "C4 B3 A3 G3 F3", focus: "B3 A3 G3"),
                LessonStep(.read, String(localized: "Música: Hot Cross Buns com a mão esquerda"), String(localized: "A canção da clave de sol, agora com Si, Lá e Sol. \(atYourPace)"),
                           notes: "B3 A3 G3:h B3 A3 G3:h G3:e G3:e G3:e G3:e A3:e A3:e A3:e A3:e B3 A3 G3:h", staff: .bass, meter: 4),
            ]),
            Lesson(id: "bass-3", title: String(localized: "Mi, Ré e Dó"), summary: String(localized: "O meio da pauta da mão esquerda"), steps: [
                LessonStep(.learn, String(localized: "Nota nova: Mi"), String(localized: "Fica no terceiro espaço, logo abaixo do Fá. Toque o Mi."), notes: "E3", staff: .bass),
                LessonStep(.learn, String(localized: "Notas novas: Ré e Dó"), String(localized: "O Ré fica na terceira linha, no meio da pauta. O Dó fica no segundo espaço. Toque os dois."), notes: "D3 C3", staff: .bass),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas do Dó central ao Dó de baixo. \(drill)"), staff: .bass, pool: "C4 B3 A3 G3 F3 E3 D3 C3", focus: "E3 D3 C3"),
                LessonStep(.read, String(localized: "Música: Ode à Alegria com a mão esquerda"), String(localized: "O tema de Beethoven oito notas abaixo. \(atYourPace)"),
                           notes: "E3 E3 F3 G3 G3 F3 E3 D3 C3 C3 D3 E3 E3:q. D3:e D3:h", staff: .bass, meter: 4),
            ]),
            Lesson(id: "bass-4", title: String(localized: "Descendo e subindo"), summary: String(localized: "Do Dó central ao Dó de baixo, e de volta"), steps: [
                LessonStep(.learn, String(localized: "A escala na clave de fá"), String(localized: "As mesmas oito notas de nomes, uma oitava abaixo: do Dó central ao Dó do segundo espaço. Desça pelas teclas acesas."), notes: "C4 B3 A3 G3 F3 E3 D3 C3", staff: .bass),
                LessonStep(.read, String(localized: "Descendo sem ajuda"), String(localized: "Leia a pauta e desça."), notes: "C4 B3 A3 G3 F3 E3 D3 C3", staff: .bass),
                LessonStep(.read, String(localized: "Subindo sem ajuda"), String(localized: "Agora o caminho contrário."), notes: "C3 D3 E3 F3 G3 A3 B3 C4", staff: .bass),
            ]),
            Lesson(id: "bass-5", title: String(localized: "As notas mais graves"), summary: String(localized: "Até o Dó com linhas extras embaixo"), steps: [
                LessonStep(.learn, String(localized: "Notas novas: Si, Lá e Sol graves"), String(localized: "O Si fica na segunda linha, o Lá no primeiro espaço, e o Sol na primeira linha. Toque os três."), notes: "B2 A2 G2", staff: .bass),
                LessonStep(.learn, String(localized: "Abaixo da pauta"), String(localized: "O Fá fica logo abaixo da primeira linha. O Mi fica numa linha curta, o Ré logo abaixo dela, e o Dó na segunda linha curta. Toque os quatro."), notes: "F2 E2 D2 C2", staff: .bass),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas no grave. \(drill)"), staff: .bass, pool: "C2 D2 E2 F2 G2 A2 B2 C3"),
            ]),
            Lesson(id: "bass-6", title: String(localized: "Desafio da clave de fá"), summary: String(localized: "Notas sorteadas, sem ajuda"), steps: [
                LessonStep(.read, String(localized: "Até o Dó de baixo"), String(localized: "Dez notas sorteadas. \(drill)"), staff: .bass, pool: "C4 B3 A3 G3 F3 E3 D3 C3"),
                LessonStep(.read, String(localized: "Pauta inteira"), String(localized: "Dez notas sorteadas, do Dó central ao Dó mais grave. \(drill)"), staff: .bass,
                           pool: "C4 B3 A3 G3 F3 E3 D3 C3 B2 A2 G2 F2 E2 D2 C2"),
            ]),
        ]
    )

    // MARK: - As Duas Claves

    private static let bothClefs = LessonModule(
        id: "grand",
        title: String(localized: "As duas claves"),
        summary: String(localized: "O piano inteiro numa pauta dupla"),
        lessons: [
            Lesson(id: "grand-1", title: String(localized: "O Dó central é o mesmo"), summary: String(localized: "Onde as duas claves se encontram"), steps: [
                LessonStep(.learn, String(localized: "Duas pautas, um piano"), String(localized: "A clave de fá escreve a metade esquerda do piano e a clave de sol, a metade direita. Elas se encontram no Dó central, que aparece na linha curta de cada uma. Toque-o duas vezes."), notes: "C4/t C4/b", grand: true),
                LessonStep(.learn, String(localized: "Subindo o teclado"), String(localized: "Da esquerda para a direita, as notas sobem pela pauta de baixo e continuam na de cima. Comece com a mão esquerda e passe para a direita no Dó central."), notes: "C3 G3 C4 G4 C5", grand: true),
                LessonStep(.read, String(localized: "Descendo sem ajuda"), String(localized: "Leia as duas pautas."), notes: "C5 G4 C4 G3 C3", grand: true),
            ]),
            Lesson(id: "grand-2", title: String(localized: "Lendo as duas pautas"), summary: String(localized: "A nota pode vir de qualquer clave"), steps: [
                LessonStep(.read, String(localized: "Qual pauta?"), String(localized: "Primeiro veja a clave, depois a nota."), notes: "E3 E4 A3 A4 D3 D4 G3 F4", grand: true),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas nas duas pautas. \(drill)"), grand: true,
                           pool: "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5"),
            ]),
            Lesson(id: "grand-3", title: String(localized: "Desafio das duas claves"), summary: String(localized: "Notas sorteadas nas duas pautas"), steps: [
                LessonStep(.read, String(localized: "Desafio"), String(localized: "Dezesseis notas sorteadas nas duas pautas. \(drill)"), grand: true,
                           pool: "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5", draw: 16),
            ]),
        ]
    )

    // MARK: - Sustenido e Bemol

    private static let accidentals = LessonModule(
        id: "accidentals",
        title: String(localized: "Sustenido e bemol"),
        summary: String(localized: "As teclas pretas"),
        lessons: [
            Lesson(id: "acc-1", title: String(localized: "O sustenido"), summary: String(localized: "Sobe a nota meio tom"), steps: [
                LessonStep(.learn, String(localized: "O sinal ♯"), String(localized: "O sustenido sobe a nota meio tom: toque a tecla logo à direita. Ele fica antes da nota, na mesma altura dela. Toque Fá e Fá♯."), notes: "F4 F#4"),
                LessonStep(.learn, String(localized: "As teclas pretas"), String(localized: "Dó♯, Ré♯, Fá♯, Sol♯ e Lá♯ são as cinco teclas pretas de cada oitava. Toque as cinco."), notes: "C#4 D#4 F#4 G#4 A#4"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas, brancas e pretas. \(drill)"),
                           pool: "C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4", focus: "C#4 D#4 F#4 G#4 A#4"),
            ]),
            Lesson(id: "acc-2", title: String(localized: "O bemol"), summary: String(localized: "Desce a nota meio tom"), steps: [
                LessonStep(.learn, String(localized: "O sinal ♭"), String(localized: "O bemol desce a nota meio tom: toque a tecla logo à esquerda. Toque Si e Si♭."), notes: "B4 Bb4"),
                LessonStep(.learn, String(localized: "As teclas pretas de novo"), String(localized: "Ré♭, Mi♭, Sol♭, Lá♭ e Si♭ são as mesmas cinco teclas pretas, com outros nomes. Toque as cinco."), notes: "Db4 Eb4 Gb4 Ab4 Bb4"),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas, brancas e pretas. \(drill)"),
                           pool: "C4 Db4 D4 Eb4 E4 F4 Gb4 G4 Ab4 A4 Bb4 B4", focus: "Db4 Eb4 Gb4 Ab4 Bb4"),
            ]),
            Lesson(id: "acc-3", title: String(localized: "Uma tecla, dois nomes"), summary: String(localized: "Dó♯ e Ré♭ são a mesma tecla"), steps: [
                LessonStep(.learn, String(localized: "O mesmo som"), String(localized: "Dó♯ e Ré♭ se escrevem em lugares diferentes da pauta, mas são a mesma tecla preta. Toque as duas."), notes: "C#4 Db4"),
                LessonStep(.read, String(localized: "Pares"), String(localized: "Cada par de notas vizinhas é uma tecla só."), notes: "C#4 Db4 F#4 Gb4 Eb4 D#4 Bb4 A#4"),
            ]),
            Lesson(id: "acc-4", title: String(localized: "O bequadro"), summary: String(localized: "Cancela o sustenido ou o bemol"), steps: [
                LessonStep(.learn, String(localized: "Vale até o fim do compasso"), String(localized: "Depois de um sustenido, as mesmas notas seguintes continuam alteradas até a barra de compasso, mesmo sem o sinal. Toque os dois Fá♯."), notes: "F#4 F#4"),
                LessonStep(.learn, String(localized: "O sinal ♮"), String(localized: "O bequadro cancela a alteração, e a nota volta à tecla branca. Toque as três."), notes: "F#4 F#4 F4"),
                LessonStep(.read, String(localized: "A barra apaga o sinal"), String(localized: "No segundo compasso, o sustenido precisa aparecer de novo. Atenção à nota sem sinal."),
                           notes: "C#4 C#4 C4 D4 C#4 D4 C#4:h", meter: 4),
            ]),
            Lesson(id: "acc-5", title: String(localized: "Desafio dos sinais"), summary: String(localized: "Brancas e pretas sorteadas"), steps: [
                LessonStep(.read, String(localized: "Sustenidos"), String(localized: "Dez notas sorteadas. \(drill)"), pool: "C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4"),
                LessonStep(.read, String(localized: "Bemóis"), String(localized: "Dez notas sorteadas. \(drill)"), pool: "C4 Db4 D4 Eb4 E4 F4 Gb4 G4 Ab4 A4 Bb4 B4"),
            ]),
        ]
    )

    // MARK: - Ritmo

    private static let rhythm = LessonModule(
        id: "rhythm",
        title: String(localized: "Ritmo"),
        summary: String(localized: "Quanto tempo cada nota dura"),
        lessons: [
            Lesson(id: "rhy-1", title: String(localized: "O pulso e a semínima"), summary: String(localized: "Tocar junto com o metrônomo"), steps: [
                LessonStep(.rhythm, String(localized: "Uma nota por pulso"), String(localized: "A música tem uma batida regular, o pulso, que o metrônomo marca. A semínima dura um pulso. Toque em Começar: o metrônomo conta 4 tempos e você toca uma nota em cada clique."), notes: "C4:q C4:q C4:q C4:q", meter: 4),
                LessonStep(.rhythm, String(localized: "Mudando de nota"), String(localized: "O mesmo pulso, com notas diferentes."), notes: "C4 D4 E4 C4 E4 D4 C4 C4", meter: 4),
            ]),
            Lesson(id: "rhy-2", title: String(localized: "Mínima e semibreve"), summary: String(localized: "Notas de 2 e de 4 pulsos"), steps: [
                LessonStep(.rhythm, String(localized: "A mínima"), String(localized: "A mínima tem a cabeça vazia e dura dois pulsos: toque e segure por dois cliques."), notes: "C4:h D4:h E4:h C4:h", meter: 4),
                LessonStep(.rhythm, String(localized: "A semibreve"), String(localized: "A semibreve não tem haste e dura quatro pulsos, o compasso inteiro."), notes: "C4:q C4:q D4:h E4:w", meter: 4),
            ]),
            Lesson(id: "rhy-3", title: String(localized: "O compasso"), summary: String(localized: "Os pulsos agrupados"), steps: [
                LessonStep(.rhythm, String(localized: "Dois compassos"), String(localized: "As barras dividem a música em grupos de pulsos. O 4 de cima diz que cada compasso tem quatro pulsos; o 4 de baixo, que a semínima vale um pulso. O primeiro clique de cada compasso é mais forte."), notes: "C4 D4 E4 F4 G4 F4 E4 D4", meter: 4),
                LessonStep(.playAlong, String(localized: "Música: Mary Had a Little Lamb"), String(localized: "Agora uma canção no tempo, com o app tocando junto."), notes: maryHalf, meter: 4),
            ]),
            Lesson(id: "rhy-4", title: String(localized: "Pausas"), summary: String(localized: "O silêncio também tem duração"), steps: [
                LessonStep(.rhythm, String(localized: "Pausa de semínima"), String(localized: "A pausa é um tempo em silêncio. Esta dura um pulso: não toque nada e espere o clique seguinte."), notes: "C4:q R:q D4:q R:q", meter: 4),
                LessonStep(.rhythm, String(localized: "Pausas longas"), String(localized: "A pausa de mínima fica em cima da terceira linha e dura dois pulsos. Conte os cliques durante ela."), notes: "C4:h R:h E4:q E4:q R:h", meter: 4),
            ]),
            Lesson(id: "rhy-5", title: String(localized: "Colcheias"), summary: String(localized: "Duas notas em cada pulso"), steps: [
                LessonStep(.rhythm, String(localized: "Duas por pulso"), String(localized: "A colcheia tem uma bandeirinha e dura meio pulso: uma no clique e a outra entre os cliques."), notes: "C4:e C4:e D4:e D4:e E4:q E4:q", meter: 4, tempo: 60),
                LessonStep(.playAlong, String(localized: "Música: Hot Cross Buns no tempo"), String(localized: "A canção da aula Dó, Ré, Mi, agora com as colcheias no tempo."), notes: hotCrossBuns, meter: 4, tempo: 66),
            ]),
            Lesson(id: "rhy-6", title: String(localized: "O ponto de aumento"), summary: String(localized: "O ponto soma metade da duração"), steps: [
                LessonStep(.rhythm, String(localized: "Mínima com ponto"), String(localized: "O ponto depois da nota soma metade do valor dela. A mínima com ponto dura três pulsos."), notes: "C4:h. D4:q E4:h. C4:q", meter: 4),
                LessonStep(.rhythm, String(localized: "Semínima com ponto"), String(localized: "Dura um pulso e meio, e costuma vir seguida de uma colcheia, que entra entre o segundo e o terceiro clique."), notes: "C4:q. D4:e E4:h E4:q. D4:e C4:h", meter: 4, tempo: 60),
                LessonStep(.playAlong, String(localized: "Música: Ode à Alegria no tempo"), String(localized: "A semínima com ponto aparece no fim da frase."), notes: odeToJoy, meter: 4),
            ]),
            Lesson(id: "rhy-7", title: String(localized: "Compasso de 3"), summary: String(localized: "A valsa"), steps: [
                LessonStep(.rhythm, String(localized: "Conte até 3"), String(localized: "Com o 3 em cima, cada compasso tem três pulsos. O primeiro continua mais forte: um, dois, três."), notes: "C4:q E4:q G4:q C5:h.", meter: 3),
                LessonStep(.playAlong, String(localized: "Música: Minueto em Sol"), String(localized: "O começo do minueto do caderno de Anna Magdalena Bach, em três tempos."),
                           notes: "D5:q G4:e A4:e B4:e C5:e D5:q G4:q G4:q E5:q C5:e D5:e E5:e F#5:e G5:q G4:q G4:q", meter: 3),
            ]),
        ]
    )

    // MARK: - Tonalidades

    private static let keySignatures = LessonModule(
        id: "keys",
        title: String(localized: "Tonalidades"),
        summary: String(localized: "Armadura de clave e escalas"),
        lessons: [
            Lesson(id: "key-1", title: String(localized: "A armadura de clave"), summary: String(localized: "Sustenidos e bemóis fixos"), steps: [
                LessonStep(.learn, String(localized: "Sinais logo depois da clave"), String(localized: "A armadura vale para a música toda. Aqui o sustenido está na linha do Fá: todo Fá é Fá♯, mesmo sem sinal ao lado da nota. Toque os dois."), notes: "F#4 F#5", key: 1),
                LessonStep(.read, String(localized: "Lembre da armadura"), String(localized: "Todo Fá desta pauta é Fá♯."), notes: "G4 F#4 E4 F#4 G4 A4 F#4 G4", key: 1),
            ]),
            Lesson(id: "key-2", title: String(localized: "Escala de Sol maior"), summary: String(localized: "Um sustenido na armadura"), steps: [
                LessonStep(.learn, String(localized: "Sol maior"), String(localized: "Começa no Sol e tem o Fá♯. É o mesmo desenho de distâncias da escala de Dó. Suba pelas teclas acesas."), notes: "G4 A4 B4 C5 D5 E5 F#5 G5", key: 1),
                LessonStep(.read, String(localized: "Descendo sem ajuda"), String(localized: "Agora o caminho de volta."), notes: "G5 F#5 E5 D5 C5 B4 A4 G4", key: 1),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas em Sol maior. \(drill)"), key: 1, pool: "F#4 G4 A4 B4 C5 D5 E5 F#5 G5", focus: "F#4 F#5"),
            ]),
            Lesson(id: "key-3", title: String(localized: "Escala de Fá maior"), summary: String(localized: "Um bemol na armadura"), steps: [
                LessonStep(.learn, String(localized: "Fá maior"), String(localized: "Começa no Fá e tem o Si♭. O bemol na armadura fica na linha do Si. Suba pelas teclas acesas."), notes: "F4 G4 A4 Bb4 C5 D5 E5 F5", key: -1),
                LessonStep(.read, String(localized: "Descendo sem ajuda"), String(localized: "Agora o caminho de volta."), notes: "F5 E5 D5 C5 Bb4 A4 G4 F4", key: -1),
                LessonStep(.read, String(localized: "Treino"), String(localized: "Dez notas sorteadas em Fá maior. \(drill)"), key: -1, pool: "F4 G4 A4 Bb4 C5 D5 E5 F5", focus: "Bb4"),
            ]),
            Lesson(id: "key-4", title: String(localized: "Desafio das armaduras"), summary: String(localized: "Notas sorteadas em cada tonalidade"), steps: [
                LessonStep(.read, String(localized: "Sol maior"), String(localized: "Todo Fá é sustenido. \(drill)"), key: 1, pool: "G4 A4 B4 C5 D5 E5 F#5 G5"),
                LessonStep(.read, String(localized: "Fá maior"), String(localized: "Todo Si é bemol. \(drill)"), key: -1, pool: "F4 G4 A4 Bb4 C5 D5 E5 F5"),
            ]),
        ]
    )

    // MARK: - Mãos Juntas e Acordes

    private static let handsAndChords = LessonModule(
        id: "hands",
        title: String(localized: "Mãos juntas e acordes"),
        summary: String(localized: "Várias notas ao mesmo tempo"),
        lessons: [
            Lesson(id: "hands-1", title: String(localized: "As duas mãos juntas"), summary: String(localized: "Uma nota em cada pauta"), steps: [
                LessonStep(.learn, String(localized: "Notas alinhadas"), String(localized: "Notas na mesma coluna das duas pautas são tocadas ao mesmo tempo: a mesma nota em cada mão, uma oitava de distância. Com o microfone, toque as duas juntas."), notes: "C3+C4 D3+D4 E3+E4", grand: true),
                LessonStep(.read, String(localized: "Sem ajuda"), String(localized: "Leia as duas pautas."), notes: "E3+E4 C3+C4 D3+D4 C3+C4 E3+E4 D3+D4 C3+C4", grand: true),
            ]),
            Lesson(id: "hands-2", title: String(localized: "Melodia e baixo"), summary: String(localized: "Cada mão com a sua nota"), steps: [
                LessonStep(.learn, String(localized: "Mão esquerda parada"), String(localized: "A mão esquerda fica no Dó e a direita caminha. Siga as teclas acesas."), notes: "C3+E4 C3+F4 C3+G4 C3+E4", grand: true),
                LessonStep(.read, String(localized: "As duas mãos mudam"), String(localized: "Agora a mão esquerda também muda."), notes: "C3+E4 G3+D4 C3+C4 G3+D4 C3+E4", grand: true),
            ]),
            Lesson(id: "chord-1", title: String(localized: "O acorde de Dó maior"), summary: String(localized: "Três notas juntas"), steps: [
                LessonStep(.learn, String(localized: "O que é um acorde"), String(localized: "São três ou mais notas tocadas juntas. O acorde de Dó maior usa Dó, Mi e Sol, empilhadas na pauta. Na tela, pode tocar uma tecla de cada vez; no piano, toque as três juntas."), notes: "C4+E4+G4"),
                LessonStep(.read, String(localized: "Três vezes"), String(localized: "Toque o acorde três vezes."), notes: "C4+E4+G4 C4+E4+G4 C4+E4+G4"),
            ]),
            Lesson(id: "chord-2", title: String(localized: "Fá e Sol maior"), summary: String(localized: "Mais dois acordes"), steps: [
                LessonStep(.learn, String(localized: "Mesmo desenho"), String(localized: "Os acordes de Fá maior e de Sol maior têm o mesmo formato: uma nota sim, uma não. Toque os dois."), notes: "F4+A4+C5 G4+B4+D5"),
                LessonStep(.read, String(localized: "Leia os acordes"), String(localized: "Leia as notas empilhadas."), notes: "G4+B4+D5 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
            ]),
            Lesson(id: "chord-3", title: String(localized: "Sequência de acordes"), summary: String(localized: "Dó, Fá, Sol, Dó"), steps: [
                LessonStep(.read, String(localized: "Dó, Fá, Sol, Dó"), String(localized: "Esta sequência aparece em muitas músicas."), notes: "C4+E4+G4 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
                LessonStep(.rhythm, String(localized: "No tempo"), String(localized: "Um acorde a cada compasso."), notes: "C4+E4+G4:w F4+A4+C5:w G4+B4+D5:w C4+E4+G4:w", meter: 4, tempo: 80),
            ]),
        ]
    )

    // MARK: - Primeiras Músicas

    /// Reads the whole song at one's own pace, then plays it in time along with the app.
    private static func song(id: String, title: String, summary: String, intro: String, phrases: [String], tempo: Int = 72) -> Lesson {
        let melody = phrases.joined(separator: " ")
        return Lesson(id: id, title: title, summary: summary, steps: [
            LessonStep(.read, String(localized: "Leia a música"), "\(intro) \(atYourPace)", notes: melody, meter: 4, tempo: tempo),
            LessonStep(.playAlong, String(localized: "Tocando junto"), String(localized: "Agora no tempo: o app toca a música com você."), notes: melody, meter: 4, tempo: tempo),
        ])
    }

    private static let songs = LessonModule(
        id: "songs",
        title: String(localized: "Primeiras músicas"),
        summary: String(localized: "Melodias conhecidas, do início ao fim"),
        lessons: [
            song(id: "song-1", title: String(localized: "Brilha, Brilha, Estrelinha"), summary: String(localized: "Melodia tradicional"),
                 intro: String(localized: "Uma melodia tradicional, só com semínimas e mínimas."),
                 phrases: [
                     "C4 C4 G4 G4 A4 A4 G4:h",
                     "F4 F4 E4 E4 D4 D4 C4:h",
                     "G4 G4 F4 F4 E4 E4 D4:h",
                     "G4 G4 F4 F4 E4 E4 D4:h",
                     "C4 C4 G4 G4 A4 A4 G4:h",
                     "F4 F4 E4 E4 D4 D4 C4:h",
                 ]),
            song(id: "song-2", title: "Mary Had a Little Lamb", summary: String(localized: "Canção tradicional"),
                 intro: String(localized: "Canção tradicional, com a mão direita perto do Dó central."),
                 phrases: [
                     "E4 D4 C4 D4 E4 E4 E4:h",
                     "D4 D4 D4:h E4 G4 G4:h",
                     "E4 D4 C4 D4 E4 E4 E4 E4",
                     "D4 D4 E4 D4 C4:w",
                 ]),
            song(id: "song-3", title: "Frère Jacques", summary: String(localized: "Canção tradicional francesa"),
                 intro: String(localized: "Canção tradicional francesa. O último trecho desce até o Sol abaixo do Dó central."),
                 phrases: [
                     "C4 D4 E4 C4 C4 D4 E4 C4",
                     "E4 F4 G4:h E4 F4 G4:h",
                     "G4:e A4:e G4:e F4:e E4 C4",
                     "G4:e A4:e G4:e F4:e E4 C4",
                     "C4 G3 C4:h C4 G3 C4:h",
                 ]),
            song(id: "song-4", title: String(localized: "Ode à Alegria"), summary: String(localized: "Beethoven, 9ª Sinfonia"),
                 intro: String(localized: "O tema da 9ª Sinfonia de Beethoven. Atenção à semínima com ponto no fim das frases."),
                 phrases: [
                     "E4 E4 F4 G4 G4 F4 E4 D4",
                     "C4 C4 D4 E4 E4:q. D4:e D4:h",
                     "E4 E4 F4 G4 G4 F4 E4 D4",
                     "C4 C4 D4 E4 D4:q. C4:e C4:h",
                 ]),
        ]
    )

    // MARK: - Ouvido

    private static let ear = LessonModule(
        id: "ear",
        title: String(localized: "Ouvido"),
        summary: String(localized: "Descobrir as notas sem ver a pauta"),
        lessons: [
            Lesson(id: "ear-1", title: String(localized: "Dó, Mi e Sol de ouvido"), summary: String(localized: "Três notas, sem pauta"), steps: [
                LessonStep(.listen, String(localized: "Três notas"), String(localized: "O app toca três notas entre Dó, Mi e Sol. Descubra quais são e toque na mesma ordem. Cada nota aparece na pauta quando você acerta."), pool: "C4 E4 G4", draw: 3),
                LessonStep(.listen, String(localized: "Quatro notas"), String(localized: "Agora quatro notas entre Dó, Mi e Sol. Toque em Ouvir para escutar de novo."), pool: "C4 E4 G4", draw: 4),
            ]),
            Lesson(id: "ear-2", title: String(localized: "Do Dó ao Sol de ouvido"), summary: String(localized: "Cinco notas vizinhas"), steps: [
                LessonStep(.listen, String(localized: "Três notas"), String(localized: "Três notas entre Dó e Sol. Comece pelo Dó central e vá comparando."), pool: "C4 D4 E4 F4 G4", draw: 3),
                LessonStep(.listen, String(localized: "Quatro notas"), String(localized: "Quatro notas entre Dó e Sol."), pool: "C4 D4 E4 F4 G4", draw: 4),
            ]),
        ]
    )
}
