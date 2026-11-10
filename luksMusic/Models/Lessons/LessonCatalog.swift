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

    private static let drill = "Sem ajuda. Se errar duas vezes, a tecla acende."
    private static let atYourPace = "Toque em Ouvir para escutar, depois leia e toque no seu ritmo."

    // Pieces used in more than one lesson
    private static let hotCrossBuns = "E4 D4 C4:h E4 D4 C4:h C4:e C4:e C4:e C4:e D4:e D4:e D4:e D4:e E4 D4 C4:h"
    private static let odeToJoy = "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:q. D4:e D4:h"
    private static let twinkle = "C4 C4 G4 G4 A4 A4 G4:h F4 F4 E4 E4 D4 D4 C4:h"
    private static let maryHalf = "E4 D4 C4 D4 E4 E4 E4:h D4 D4 D4:h E4 G4 G4:h"

    // MARK: - Clave de Sol

    private static let trebleClef = LessonModule(
        id: "treble",
        title: "Clave de sol",
        summary: "Mão direita, do Dó central para cima",
        lessons: [
            Lesson(id: "treble-1", title: "O Dó central", summary: "Como achar o Dó no piano e na pauta", steps: [
                LessonStep(.learn, "Ache o Dó",
                           "As teclas pretas vêm em grupos de 2 e de 3. O Dó é a tecla branca logo à esquerda de cada grupo de 2. Toque os dois Dós acesos.",
                           notes: "C4 C5"),
                LessonStep(.learn, "Nota nova: Dó central",
                           "É o Dó mais perto do meio do piano. Na clave de sol, ele fica numa linha curta, logo abaixo das cinco linhas. Toque com o polegar direito.",
                           notes: "C4"),
                LessonStep(.read, "Sua vez", "Toque o Dó central três vezes. Cada toque vale uma nota.", notes: "C4 C4 C4"),
            ]),
            Lesson(id: "treble-2", title: "Dó, Ré, Mi", summary: "As três primeiras notas", steps: [
                LessonStep(.learn, "Nota nova: Ré", "É a tecla branca logo à direita do Dó. Na pauta, fica logo abaixo da primeira linha. Toque o Ré.", notes: "D4"),
                LessonStep(.learn, "Nota nova: Mi", "É a tecla branca seguinte. Na pauta, fica em cima da primeira linha. Toque o Mi.", notes: "E4"),
                LessonStep(.read, "Treino", "Dez notas sorteadas entre Dó, Ré e Mi. \(drill)", pool: "C4 D4 E4", focus: "D4 E4"),
                LessonStep(.read, "Música: Hot Cross Buns", "Uma canção infantil inglesa só com Mi, Ré e Dó. \(atYourPace)", notes: hotCrossBuns, meter: 4),
            ]),
            Lesson(id: "treble-3", title: "Fá e Sol", summary: "A clave de sol marca a linha do Sol", steps: [
                LessonStep(.learn, "Nota nova: Fá", "É a tecla branca logo à esquerda do grupo de 3 teclas pretas. Na pauta, fica no primeiro espaço. Toque o Fá.", notes: "F4"),
                LessonStep(.learn, "Nota nova: Sol", "Fica na segunda linha, a que a curva da clave de sol envolve. É daí que vem o nome da clave. Toque o Sol.", notes: "G4"),
                LessonStep(.read, "Treino", "Dez notas sorteadas do Dó ao Sol. \(drill)", pool: "C4 D4 E4 F4 G4", focus: "F4 G4"),
                LessonStep(.read, "Música: Ode à Alegria", "O tema de Beethoven usa só as notas do Dó ao Sol. \(atYourPace)", notes: odeToJoy, meter: 4),
            ]),
            Lesson(id: "treble-4", title: "Lá, Si e o outro Dó", summary: "Até o Dó de cima", steps: [
                LessonStep(.learn, "Nota nova: Lá", "Vem depois do Sol. Na pauta, fica no segundo espaço. Toque o Lá.", notes: "A4"),
                LessonStep(.learn, "Nota nova: Si", "Fica na terceira linha, bem no meio da pauta. Toque o Si.", notes: "B4"),
                LessonStep(.learn, "Nota nova: o Dó de cima", "Depois do Si, os nomes recomeçam. Este Dó é o oitavo som a partir do Dó central e fica no terceiro espaço. Toque-o.", notes: "C5"),
                LessonStep(.read, "Treino", "Dez notas sorteadas do Dó central ao Dó de cima. \(drill)", pool: "C4 D4 E4 F4 G4 A4 B4 C5", focus: "A4 B4 C5"),
                LessonStep(.read, "Música: Brilha, Brilha, Estrelinha", "Melodia tradicional que sobe até o Lá. \(atYourPace)", notes: twinkle, meter: 4),
            ]),
            Lesson(id: "treble-5", title: "A escala subindo", summary: "Do Dó central ao Dó de cima", steps: [
                LessonStep(.learn, "A escala de Dó", "São oito notas vizinhas, todas em teclas brancas. Na pauta, cada nota sobe um degrau: linha, espaço, linha, espaço. Suba pelas teclas acesas.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.read, "Subindo sem ajuda", "Leia a pauta e suba até o Dó de cima.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.read, "Linhas e espaços", "Primeiro as notas nas linhas, depois as dos espaços: pulando uma tecla de cada vez.", notes: "E4 G4 B4 F4 A4 C5"),
            ]),
            Lesson(id: "treble-6", title: "A escala descendo", summary: "O caminho de volta", steps: [
                LessonStep(.learn, "Descendo", "Agora o caminho contrário: comece no Dó de cima e desça um degrau por vez até o Dó central, pelas teclas acesas.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(.read, "Descendo sem ajuda", "Leia a pauta e desça até o Dó central.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(.read, "Treino", "Dez notas sorteadas do Dó ao Dó. \(drill)", pool: "C4 D4 E4 F4 G4 A4 B4 C5"),
            ]),
            Lesson(id: "treble-7", title: "Ré, Mi, Fá e Sol de cima", summary: "O alto da pauta", steps: [
                LessonStep(.learn, "Notas novas: Ré e Mi", "O Ré fica na quarta linha, e o Mi no quarto espaço. Toque os dois.", notes: "D5 E5"),
                LessonStep(.learn, "Notas novas: Fá e Sol", "O Fá fica na quinta linha, a última. O Sol fica logo acima dela. Toque os dois.", notes: "F5 G5"),
                LessonStep(.read, "Treino", "Dez notas sorteadas do Sol ao Sol de cima. \(drill)", pool: "G4 A4 B4 C5 D5 E5 F5 G5", focus: "D5 E5 F5 G5"),
                LessonStep(.read, "Música: Ode à Alegria, uma oitava acima", "A mesma melodia da aula Fá e Sol, oito notas mais aguda: mesmas teclas, mais à direita. \(atYourPace)",
                           notes: "E5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 E5:q. D5:e D5:h", meter: 4),
            ]),
            Lesson(id: "treble-8", title: "Linhas extras em cima", summary: "Lá, Si e Dó acima da pauta", steps: [
                LessonStep(.learn, "Nota nova: Lá agudo", "Quando a nota passa das cinco linhas, a pauta ganha linhas curtas. O Lá fica na primeira linha curta acima da pauta. Toque o Lá.", notes: "A5"),
                LessonStep(.learn, "Notas novas: Si e Dó agudos", "O Si fica logo acima dessa linha. O Dó fica na segunda linha curta. Toque os dois.", notes: "B5 C6"),
                LessonStep(.read, "Treino", "Dez notas sorteadas no alto da pauta. \(drill)", pool: "E5 F5 G5 A5 B5 C6", focus: "A5 B5 C6"),
            ]),
            Lesson(id: "treble-9", title: "Desafio da clave de sol", summary: "Notas sorteadas, sem ajuda", steps: [
                LessonStep(.read, "Até o Dó de cima", "Dez notas sorteadas. \(drill)", pool: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.read, "Pauta inteira", "Dez notas sorteadas, do Dó central ao Dó mais alto. \(drill)",
                           pool: "C4 D4 E4 F4 G4 A4 B4 C5 D5 E5 F5 G5 A5 B5 C6"),
            ]),
        ]
    )

    // MARK: - Clave de Fá

    private static let bassClef = LessonModule(
        id: "bass",
        title: "Clave de fá",
        summary: "Mão esquerda, do Dó central para baixo",
        lessons: [
            Lesson(id: "bass-1", title: "A clave de fá", summary: "A pauta da mão esquerda", steps: [
                LessonStep(.learn, "Nota nova: o Fá da clave", "A mão esquerda costuma ler esta clave. Os dois pontos dela ficam em volta da quarta linha, e essa linha é o Fá. Toque com a mão esquerda.", notes: "F3", staff: .bass),
                LessonStep(.learn, "O mesmo Dó central", "Nesta clave, o Dó central fica numa linha curta acima das cinco linhas. É a mesma tecla da clave de sol. Toque-o.", notes: "C4", staff: .bass),
                LessonStep(.read, "Sua vez", "Leia a pauta: só Fá e Dó.", notes: "F3 C4 F3 F3 C4", staff: .bass),
            ]),
            Lesson(id: "bass-2", title: "Si, Lá e Sol", summary: "Descendo a partir do Dó central", steps: [
                LessonStep(.learn, "Nota nova: Si", "É a tecla logo à esquerda do Dó central. Na pauta, fica logo acima da quinta linha. Toque o Si.", notes: "B3", staff: .bass),
                LessonStep(.learn, "Notas novas: Lá e Sol", "O Lá fica na quinta linha, a de cima. O Sol fica no quarto espaço. Toque os dois.", notes: "A3 G3", staff: .bass),
                LessonStep(.read, "Treino", "Dez notas sorteadas do Dó central ao Fá. \(drill)", staff: .bass, pool: "C4 B3 A3 G3 F3", focus: "B3 A3 G3"),
                LessonStep(.read, "Música: Hot Cross Buns com a mão esquerda", "A canção da clave de sol, agora com Si, Lá e Sol. \(atYourPace)",
                           notes: "B3 A3 G3:h B3 A3 G3:h G3:e G3:e G3:e G3:e A3:e A3:e A3:e A3:e B3 A3 G3:h", staff: .bass, meter: 4),
            ]),
            Lesson(id: "bass-3", title: "Mi, Ré e Dó", summary: "O meio da pauta da mão esquerda", steps: [
                LessonStep(.learn, "Nota nova: Mi", "Fica no terceiro espaço, logo abaixo do Fá. Toque o Mi.", notes: "E3", staff: .bass),
                LessonStep(.learn, "Notas novas: Ré e Dó", "O Ré fica na terceira linha, no meio da pauta. O Dó fica no segundo espaço. Toque os dois.", notes: "D3 C3", staff: .bass),
                LessonStep(.read, "Treino", "Dez notas sorteadas do Dó central ao Dó de baixo. \(drill)", staff: .bass, pool: "C4 B3 A3 G3 F3 E3 D3 C3", focus: "E3 D3 C3"),
                LessonStep(.read, "Música: Ode à Alegria com a mão esquerda", "O tema de Beethoven oito notas abaixo. \(atYourPace)",
                           notes: "E3 E3 F3 G3 G3 F3 E3 D3 C3 C3 D3 E3 E3:q. D3:e D3:h", staff: .bass, meter: 4),
            ]),
            Lesson(id: "bass-4", title: "Descendo e subindo", summary: "Do Dó central ao Dó de baixo, e de volta", steps: [
                LessonStep(.learn, "A escala na clave de fá", "As mesmas oito notas de nomes, uma oitava abaixo: do Dó central ao Dó do segundo espaço. Desça pelas teclas acesas.", notes: "C4 B3 A3 G3 F3 E3 D3 C3", staff: .bass),
                LessonStep(.read, "Descendo sem ajuda", "Leia a pauta e desça.", notes: "C4 B3 A3 G3 F3 E3 D3 C3", staff: .bass),
                LessonStep(.read, "Subindo sem ajuda", "Agora o caminho contrário.", notes: "C3 D3 E3 F3 G3 A3 B3 C4", staff: .bass),
            ]),
            Lesson(id: "bass-5", title: "As notas mais graves", summary: "Até o Dó com linhas extras embaixo", steps: [
                LessonStep(.learn, "Notas novas: Si, Lá e Sol graves", "O Si fica na segunda linha, o Lá no primeiro espaço, e o Sol na primeira linha. Toque os três.", notes: "B2 A2 G2", staff: .bass),
                LessonStep(.learn, "Abaixo da pauta", "O Fá fica logo abaixo da primeira linha. O Mi fica numa linha curta, o Ré logo abaixo dela, e o Dó na segunda linha curta. Toque os quatro.", notes: "F2 E2 D2 C2", staff: .bass),
                LessonStep(.read, "Treino", "Dez notas sorteadas no grave. \(drill)", staff: .bass, pool: "C2 D2 E2 F2 G2 A2 B2 C3"),
            ]),
            Lesson(id: "bass-6", title: "Desafio da clave de fá", summary: "Notas sorteadas, sem ajuda", steps: [
                LessonStep(.read, "Até o Dó de baixo", "Dez notas sorteadas. \(drill)", staff: .bass, pool: "C4 B3 A3 G3 F3 E3 D3 C3"),
                LessonStep(.read, "Pauta inteira", "Dez notas sorteadas, do Dó central ao Dó mais grave. \(drill)", staff: .bass,
                           pool: "C4 B3 A3 G3 F3 E3 D3 C3 B2 A2 G2 F2 E2 D2 C2"),
            ]),
        ]
    )

    // MARK: - As Duas Claves

    private static let bothClefs = LessonModule(
        id: "grand",
        title: "As duas claves",
        summary: "O piano inteiro numa pauta dupla",
        lessons: [
            Lesson(id: "grand-1", title: "O Dó central é o mesmo", summary: "Onde as duas claves se encontram", steps: [
                LessonStep(.learn, "Duas pautas, um piano", "A clave de fá escreve a metade esquerda do piano e a clave de sol, a metade direita. Elas se encontram no Dó central, que aparece na linha curta de cada uma. Toque-o duas vezes.", notes: "C4/t C4/b", grand: true),
                LessonStep(.learn, "Subindo o teclado", "Da esquerda para a direita, as notas sobem pela pauta de baixo e continuam na de cima. Comece com a mão esquerda e passe para a direita no Dó central.", notes: "C3 G3 C4 G4 C5", grand: true),
                LessonStep(.read, "Descendo sem ajuda", "Leia as duas pautas.", notes: "C5 G4 C4 G3 C3", grand: true),
            ]),
            Lesson(id: "grand-2", title: "Lendo as duas pautas", summary: "A nota pode vir de qualquer clave", steps: [
                LessonStep(.read, "Qual pauta?", "Primeiro veja a clave, depois a nota.", notes: "E3 E4 A3 A4 D3 D4 G3 F4", grand: true),
                LessonStep(.read, "Treino", "Dez notas sorteadas nas duas pautas. \(drill)", grand: true,
                           pool: "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5"),
            ]),
            Lesson(id: "grand-3", title: "Desafio das duas claves", summary: "Notas sorteadas nas duas pautas", steps: [
                LessonStep(.read, "Desafio", "Dezesseis notas sorteadas nas duas pautas. \(drill)", grand: true,
                           pool: "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5", draw: 16),
            ]),
        ]
    )

    // MARK: - Sustenido e Bemol

    private static let accidentals = LessonModule(
        id: "accidentals",
        title: "Sustenido e bemol",
        summary: "As teclas pretas",
        lessons: [
            Lesson(id: "acc-1", title: "O sustenido", summary: "Sobe a nota meio tom", steps: [
                LessonStep(.learn, "O sinal ♯", "O sustenido sobe a nota meio tom: toque a tecla logo à direita. Ele fica antes da nota, na mesma altura dela. Toque Fá e Fá♯.", notes: "F4 F#4"),
                LessonStep(.learn, "As teclas pretas", "Dó♯, Ré♯, Fá♯, Sol♯ e Lá♯ são as cinco teclas pretas de cada oitava. Toque as cinco.", notes: "C#4 D#4 F#4 G#4 A#4"),
                LessonStep(.read, "Treino", "Dez notas sorteadas, brancas e pretas. \(drill)",
                           pool: "C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4", focus: "C#4 D#4 F#4 G#4 A#4"),
            ]),
            Lesson(id: "acc-2", title: "O bemol", summary: "Desce a nota meio tom", steps: [
                LessonStep(.learn, "O sinal ♭", "O bemol desce a nota meio tom: toque a tecla logo à esquerda. Toque Si e Si♭.", notes: "B4 Bb4"),
                LessonStep(.learn, "As teclas pretas de novo", "Ré♭, Mi♭, Sol♭, Lá♭ e Si♭ são as mesmas cinco teclas pretas, com outros nomes. Toque as cinco.", notes: "Db4 Eb4 Gb4 Ab4 Bb4"),
                LessonStep(.read, "Treino", "Dez notas sorteadas, brancas e pretas. \(drill)",
                           pool: "C4 Db4 D4 Eb4 E4 F4 Gb4 G4 Ab4 A4 Bb4 B4", focus: "Db4 Eb4 Gb4 Ab4 Bb4"),
            ]),
            Lesson(id: "acc-3", title: "Uma tecla, dois nomes", summary: "Dó♯ e Ré♭ são a mesma tecla", steps: [
                LessonStep(.learn, "O mesmo som", "Dó♯ e Ré♭ se escrevem em lugares diferentes da pauta, mas são a mesma tecla preta. Toque as duas.", notes: "C#4 Db4"),
                LessonStep(.read, "Pares", "Cada par de notas vizinhas é uma tecla só.", notes: "C#4 Db4 F#4 Gb4 Eb4 D#4 Bb4 A#4"),
            ]),
            Lesson(id: "acc-4", title: "O bequadro", summary: "Cancela o sustenido ou o bemol", steps: [
                LessonStep(.learn, "Vale até o fim do compasso", "Depois de um sustenido, as mesmas notas seguintes continuam alteradas até a barra de compasso, mesmo sem o sinal. Toque os dois Fá♯.", notes: "F#4 F#4"),
                LessonStep(.learn, "O sinal ♮", "O bequadro cancela a alteração, e a nota volta à tecla branca. Toque as três.", notes: "F#4 F#4 F4"),
                LessonStep(.read, "A barra apaga o sinal", "No segundo compasso, o sustenido precisa aparecer de novo. Atenção à nota sem sinal.",
                           notes: "C#4 C#4 C4 D4 C#4 D4 C#4:h", meter: 4),
            ]),
            Lesson(id: "acc-5", title: "Desafio dos sinais", summary: "Brancas e pretas sorteadas", steps: [
                LessonStep(.read, "Sustenidos", "Dez notas sorteadas. \(drill)", pool: "C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4"),
                LessonStep(.read, "Bemóis", "Dez notas sorteadas. \(drill)", pool: "C4 Db4 D4 Eb4 E4 F4 Gb4 G4 Ab4 A4 Bb4 B4"),
            ]),
        ]
    )

    // MARK: - Ritmo

    private static let rhythm = LessonModule(
        id: "rhythm",
        title: "Ritmo",
        summary: "Quanto tempo cada nota dura",
        lessons: [
            Lesson(id: "rhy-1", title: "O pulso e a semínima", summary: "Tocar junto com o metrônomo", steps: [
                LessonStep(.rhythm, "Uma nota por pulso", "A música tem uma batida regular, o pulso, que o metrônomo marca. A semínima dura um pulso. Toque em Começar: o metrônomo conta 4 tempos e você toca uma nota em cada clique.", notes: "C4:q C4:q C4:q C4:q", meter: 4),
                LessonStep(.rhythm, "Mudando de nota", "O mesmo pulso, com notas diferentes.", notes: "C4 D4 E4 C4 E4 D4 C4 C4", meter: 4),
            ]),
            Lesson(id: "rhy-2", title: "Mínima e semibreve", summary: "Notas de 2 e de 4 pulsos", steps: [
                LessonStep(.rhythm, "A mínima", "A mínima tem a cabeça vazia e dura dois pulsos: toque e segure por dois cliques.", notes: "C4:h D4:h E4:h C4:h", meter: 4),
                LessonStep(.rhythm, "A semibreve", "A semibreve não tem haste e dura quatro pulsos, o compasso inteiro.", notes: "C4:q C4:q D4:h E4:w", meter: 4),
            ]),
            Lesson(id: "rhy-3", title: "O compasso", summary: "Os pulsos agrupados", steps: [
                LessonStep(.rhythm, "Dois compassos", "As barras dividem a música em grupos de pulsos. O 4 de cima diz que cada compasso tem quatro pulsos; o 4 de baixo, que a semínima vale um pulso. O primeiro clique de cada compasso é mais forte.", notes: "C4 D4 E4 F4 G4 F4 E4 D4", meter: 4),
                LessonStep(.playAlong, "Música: Mary Had a Little Lamb", "Agora uma canção no tempo, com o app tocando junto.", notes: maryHalf, meter: 4),
            ]),
            Lesson(id: "rhy-4", title: "Pausas", summary: "O silêncio também tem duração", steps: [
                LessonStep(.rhythm, "Pausa de semínima", "A pausa é um tempo em silêncio. Esta dura um pulso: não toque nada e espere o clique seguinte.", notes: "C4:q R:q D4:q R:q", meter: 4),
                LessonStep(.rhythm, "Pausas longas", "A pausa de mínima fica em cima da terceira linha e dura dois pulsos. Conte os cliques durante ela.", notes: "C4:h R:h E4:q E4:q R:h", meter: 4),
            ]),
            Lesson(id: "rhy-5", title: "Colcheias", summary: "Duas notas em cada pulso", steps: [
                LessonStep(.rhythm, "Duas por pulso", "A colcheia tem uma bandeirinha e dura meio pulso: uma no clique e a outra entre os cliques.", notes: "C4:e C4:e D4:e D4:e E4:q E4:q", meter: 4, tempo: 60),
                LessonStep(.playAlong, "Música: Hot Cross Buns no tempo", "A canção da aula Dó, Ré, Mi, agora com as colcheias no tempo.", notes: hotCrossBuns, meter: 4, tempo: 66),
            ]),
            Lesson(id: "rhy-6", title: "O ponto de aumento", summary: "O ponto soma metade da duração", steps: [
                LessonStep(.rhythm, "Mínima com ponto", "O ponto depois da nota soma metade do valor dela. A mínima com ponto dura três pulsos.", notes: "C4:h. D4:q E4:h. C4:q", meter: 4),
                LessonStep(.rhythm, "Semínima com ponto", "Dura um pulso e meio, e costuma vir seguida de uma colcheia, que entra entre o segundo e o terceiro clique.", notes: "C4:q. D4:e E4:h E4:q. D4:e C4:h", meter: 4, tempo: 60),
                LessonStep(.playAlong, "Música: Ode à Alegria no tempo", "A semínima com ponto aparece no fim da frase.", notes: odeToJoy, meter: 4),
            ]),
            Lesson(id: "rhy-7", title: "Compasso de 3", summary: "A valsa", steps: [
                LessonStep(.rhythm, "Conte até 3", "Com o 3 em cima, cada compasso tem três pulsos. O primeiro continua mais forte: um, dois, três.", notes: "C4:q E4:q G4:q C5:h.", meter: 3),
                LessonStep(.playAlong, "Música: Minueto em Sol", "O começo do minueto do caderno de Anna Magdalena Bach, em três tempos.",
                           notes: "D5:q G4:e A4:e B4:e C5:e D5:q G4:q G4:q E5:q C5:e D5:e E5:e F#5:e G5:q G4:q G4:q", meter: 3),
            ]),
        ]
    )

    // MARK: - Tonalidades

    private static let keySignatures = LessonModule(
        id: "keys",
        title: "Tonalidades",
        summary: "Armadura de clave e escalas",
        lessons: [
            Lesson(id: "key-1", title: "A armadura de clave", summary: "Sustenidos e bemóis fixos", steps: [
                LessonStep(.learn, "Sinais logo depois da clave", "A armadura vale para a música toda. Aqui o sustenido está na linha do Fá: todo Fá é Fá♯, mesmo sem sinal ao lado da nota. Toque os dois.", notes: "F#4 F#5", key: 1),
                LessonStep(.read, "Lembre da armadura", "Todo Fá desta pauta é Fá♯.", notes: "G4 F#4 E4 F#4 G4 A4 F#4 G4", key: 1),
            ]),
            Lesson(id: "key-2", title: "Escala de Sol maior", summary: "Um sustenido na armadura", steps: [
                LessonStep(.learn, "Sol maior", "Começa no Sol e tem o Fá♯. É o mesmo desenho de distâncias da escala de Dó. Suba pelas teclas acesas.", notes: "G4 A4 B4 C5 D5 E5 F#5 G5", key: 1),
                LessonStep(.read, "Descendo sem ajuda", "Agora o caminho de volta.", notes: "G5 F#5 E5 D5 C5 B4 A4 G4", key: 1),
                LessonStep(.read, "Treino", "Dez notas sorteadas em Sol maior. \(drill)", key: 1, pool: "F#4 G4 A4 B4 C5 D5 E5 F#5 G5", focus: "F#4 F#5"),
            ]),
            Lesson(id: "key-3", title: "Escala de Fá maior", summary: "Um bemol na armadura", steps: [
                LessonStep(.learn, "Fá maior", "Começa no Fá e tem o Si♭. O bemol na armadura fica na linha do Si. Suba pelas teclas acesas.", notes: "F4 G4 A4 Bb4 C5 D5 E5 F5", key: -1),
                LessonStep(.read, "Descendo sem ajuda", "Agora o caminho de volta.", notes: "F5 E5 D5 C5 Bb4 A4 G4 F4", key: -1),
                LessonStep(.read, "Treino", "Dez notas sorteadas em Fá maior. \(drill)", key: -1, pool: "F4 G4 A4 Bb4 C5 D5 E5 F5", focus: "Bb4"),
            ]),
            Lesson(id: "key-4", title: "Desafio das armaduras", summary: "Notas sorteadas em cada tonalidade", steps: [
                LessonStep(.read, "Sol maior", "Todo Fá é sustenido. \(drill)", key: 1, pool: "G4 A4 B4 C5 D5 E5 F#5 G5"),
                LessonStep(.read, "Fá maior", "Todo Si é bemol. \(drill)", key: -1, pool: "F4 G4 A4 Bb4 C5 D5 E5 F5"),
            ]),
        ]
    )

    // MARK: - Mãos Juntas e Acordes

    private static let handsAndChords = LessonModule(
        id: "hands",
        title: "Mãos juntas e acordes",
        summary: "Várias notas ao mesmo tempo",
        lessons: [
            Lesson(id: "hands-1", title: "As duas mãos juntas", summary: "Uma nota em cada pauta", steps: [
                LessonStep(.learn, "Notas alinhadas", "Notas na mesma coluna das duas pautas são tocadas ao mesmo tempo: a mesma nota em cada mão, uma oitava de distância. Com o microfone, toque as duas juntas.", notes: "C3+C4 D3+D4 E3+E4", grand: true),
                LessonStep(.read, "Sem ajuda", "Leia as duas pautas.", notes: "E3+E4 C3+C4 D3+D4 C3+C4 E3+E4 D3+D4 C3+C4", grand: true),
            ]),
            Lesson(id: "hands-2", title: "Melodia e baixo", summary: "Cada mão com a sua nota", steps: [
                LessonStep(.learn, "Mão esquerda parada", "A mão esquerda fica no Dó e a direita caminha. Siga as teclas acesas.", notes: "C3+E4 C3+F4 C3+G4 C3+E4", grand: true),
                LessonStep(.read, "As duas mãos mudam", "Agora a mão esquerda também muda.", notes: "C3+E4 G3+D4 C3+C4 G3+D4 C3+E4", grand: true),
            ]),
            Lesson(id: "chord-1", title: "O acorde de Dó maior", summary: "Três notas juntas", steps: [
                LessonStep(.learn, "O que é um acorde", "São três ou mais notas tocadas juntas. O acorde de Dó maior usa Dó, Mi e Sol, empilhadas na pauta. Na tela, pode tocar uma tecla de cada vez; no piano, toque as três juntas.", notes: "C4+E4+G4"),
                LessonStep(.read, "Três vezes", "Toque o acorde três vezes.", notes: "C4+E4+G4 C4+E4+G4 C4+E4+G4"),
            ]),
            Lesson(id: "chord-2", title: "Fá e Sol maior", summary: "Mais dois acordes", steps: [
                LessonStep(.learn, "Mesmo desenho", "Os acordes de Fá maior e de Sol maior têm o mesmo formato: uma nota sim, uma não. Toque os dois.", notes: "F4+A4+C5 G4+B4+D5"),
                LessonStep(.read, "Leia os acordes", "Leia as notas empilhadas.", notes: "G4+B4+D5 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
            ]),
            Lesson(id: "chord-3", title: "Sequência de acordes", summary: "Dó, Fá, Sol, Dó", steps: [
                LessonStep(.read, "Dó, Fá, Sol, Dó", "Esta sequência aparece em muitas músicas.", notes: "C4+E4+G4 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
                LessonStep(.rhythm, "No tempo", "Um acorde a cada compasso.", notes: "C4+E4+G4:w F4+A4+C5:w G4+B4+D5:w C4+E4+G4:w", meter: 4, tempo: 80),
            ]),
        ]
    )

    // MARK: - Primeiras Músicas

    /// Reads the whole song at one's own pace, then plays it in time along with the app.
    private static func song(id: String, title: String, summary: String, intro: String, phrases: [String], tempo: Int = 72) -> Lesson {
        let melody = phrases.joined(separator: " ")
        return Lesson(id: id, title: title, summary: summary, steps: [
            LessonStep(.read, "Leia a música", "\(intro) \(atYourPace)", notes: melody, meter: 4, tempo: tempo),
            LessonStep(.playAlong, "Tocando junto", "Agora no tempo: o app toca a música com você.", notes: melody, meter: 4, tempo: tempo),
        ])
    }

    private static let songs = LessonModule(
        id: "songs",
        title: "Primeiras músicas",
        summary: "Melodias conhecidas, do início ao fim",
        lessons: [
            song(id: "song-1", title: "Brilha, Brilha, Estrelinha", summary: "Melodia tradicional",
                 intro: "Uma melodia tradicional, só com semínimas e mínimas.",
                 phrases: [
                     "C4 C4 G4 G4 A4 A4 G4:h",
                     "F4 F4 E4 E4 D4 D4 C4:h",
                     "G4 G4 F4 F4 E4 E4 D4:h",
                     "G4 G4 F4 F4 E4 E4 D4:h",
                     "C4 C4 G4 G4 A4 A4 G4:h",
                     "F4 F4 E4 E4 D4 D4 C4:h",
                 ]),
            song(id: "song-2", title: "Mary Had a Little Lamb", summary: "Canção tradicional",
                 intro: "Canção tradicional, com a mão direita perto do Dó central.",
                 phrases: [
                     "E4 D4 C4 D4 E4 E4 E4:h",
                     "D4 D4 D4:h E4 G4 G4:h",
                     "E4 D4 C4 D4 E4 E4 E4 E4",
                     "D4 D4 E4 D4 C4:w",
                 ]),
            song(id: "song-3", title: "Frère Jacques", summary: "Canção tradicional francesa",
                 intro: "Canção tradicional francesa. O último trecho desce até o Sol abaixo do Dó central.",
                 phrases: [
                     "C4 D4 E4 C4 C4 D4 E4 C4",
                     "E4 F4 G4:h E4 F4 G4:h",
                     "G4:e A4:e G4:e F4:e E4 C4",
                     "G4:e A4:e G4:e F4:e E4 C4",
                     "C4 G3 C4:h C4 G3 C4:h",
                 ]),
            song(id: "song-4", title: "Ode à Alegria", summary: "Beethoven, 9ª Sinfonia",
                 intro: "O tema da 9ª Sinfonia de Beethoven. Atenção à semínima com ponto no fim das frases.",
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
        title: "Ouvido",
        summary: "Descobrir as notas sem ver a pauta",
        lessons: [
            Lesson(id: "ear-1", title: "Dó, Mi e Sol de ouvido", summary: "Três notas, sem pauta", steps: [
                LessonStep(.listen, "Três notas", "O app toca três notas entre Dó, Mi e Sol. Descubra quais são e toque na mesma ordem. Cada nota aparece na pauta quando você acerta.", pool: "C4 E4 G4", draw: 3),
                LessonStep(.listen, "Quatro notas", "Agora quatro notas entre Dó, Mi e Sol. Toque em Ouvir para escutar de novo.", pool: "C4 E4 G4", draw: 4),
            ]),
            Lesson(id: "ear-2", title: "Do Dó ao Sol de ouvido", summary: "Cinco notas vizinhas", steps: [
                LessonStep(.listen, "Três notas", "Três notas entre Dó e Sol. Comece pelo Dó central e vá comparando.", pool: "C4 D4 E4 F4 G4", draw: 3),
                LessonStep(.listen, "Quatro notas", "Quatro notas entre Dó e Sol.", pool: "C4 D4 E4 F4 G4", draw: 4),
            ]),
        ]
    )
}
