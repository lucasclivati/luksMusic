// LessonCatalog.swift
// luksMusic
//
// The lessons themselves, in teaching order. Each one introduces a little, has it played with help, then without.
// Songs are traditional melodies or by composers long in the public domain, written out here.

import Foundation

enum LessonCatalog {

    static let modules: [LessonModule] = [
        trebleClef, bassClef, bothClefs, accidentals, rhythm, keySignatures, handsAndChords, songs,
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

    private static let ear = "Primeiro o app toca. Depois é a sua vez."

    // MARK: - Clave de Sol

    private static let trebleClef = LessonModule(
        id: "treble",
        title: "Clave de sol",
        summary: "Mão direita, do Dó central para cima",
        lessons: [
            Lesson(id: "treble-1", title: "O Dó central", summary: "Como achar o Dó no piano e na pauta", steps: [
                LessonStep(.explain, "Ache o Dó no piano",
                           "As teclas pretas vêm em grupos de 2 e de 3. O Dó é a tecla branca logo à esquerda de cada grupo de 2.",
                           litKeys: "C4 C5"),
                LessonStep(.explain, "O Dó central",
                           "É o Dó mais perto do meio do piano. Na clave de sol, ele fica numa linha curta, logo abaixo das cinco linhas da pauta.",
                           notes: "C4"),
                LessonStep(.guided, "Toque o Dó central", "Use o polegar da mão direita.", notes: "C4"),
                LessonStep(.alone, "Agora sem ajuda", "Toque o Dó central três vezes. Cada toque vale uma nota.", notes: "C4 C4 C4"),
            ]),
            Lesson(id: "treble-2", title: "Dó, Ré, Mi", summary: "As três primeiras notas", steps: [
                LessonStep(.explain, "O Ré", "É a tecla branca logo à direita do Dó. Na pauta, ele fica logo abaixo da primeira linha.", notes: "C4 D4"),
                LessonStep(.explain, "O Mi", "É a tecla branca seguinte. Na pauta, ele fica em cima da primeira linha.", notes: "C4 D4 E4"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "C4 D4 E4"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "E4 D4 C4"),
                LessonStep(.alone, "Misturando", "As notas agora vêm fora de ordem.", notes: "D4 E4 C4 D4"),
            ]),
            Lesson(id: "treble-3", title: "Fá e Sol", summary: "A clave de sol marca a linha do Sol", steps: [
                LessonStep(.explain, "O Fá", "É a tecla branca logo à esquerda do grupo de 3 teclas pretas. Na pauta, ele fica no primeiro espaço, entre a primeira e a segunda linha.", notes: "E4 F4"),
                LessonStep(.explain, "O Sol", "Fica na segunda linha, a que a curva da clave de sol envolve. É daí que vem o nome da clave.", notes: "F4 G4"),
                LessonStep(.guided, "Toque com ajuda", "Do Dó ao Sol: um dedo para cada nota.", notes: "C4 D4 E4 F4 G4"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "G4 F4 E4"),
                LessonStep(.alone, "Misturando", "As notas agora vêm fora de ordem.", notes: "E4 G4 F4 D4"),
                LessonStep(.listen, "Ouça e repita", ear, notes: "C4 E4 G4"),
            ]),
            Lesson(id: "treble-4", title: "Lá, Si e o outro Dó", summary: "Até o Dó de cima", steps: [
                LessonStep(.explain, "O Lá", "Vem depois do Sol. Na pauta, ele fica no segundo espaço.", notes: "G4 A4"),
                LessonStep(.explain, "O Si", "Fica na terceira linha, bem no meio da pauta.", notes: "A4 B4"),
                LessonStep(.explain, "O outro Dó", "Depois do Si, os nomes recomeçam. Este Dó é o oitavo som a partir do Dó central e fica no terceiro espaço.", notes: "C4 C5"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "G4 A4 B4 C5"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "C5 B4 A4 G4"),
                LessonStep(.alone, "Misturando", "As notas agora vêm fora de ordem.", notes: "A4 C5 G4 B4"),
                LessonStep(.listen, "Ouça e repita", ear, notes: "G4 B4 C5"),
            ]),
            Lesson(id: "treble-5", title: "A escala subindo", summary: "Do Dó central ao Dó de cima", steps: [
                LessonStep(.explain, "A escala de Dó", "São oito notas vizinhas, todas em teclas brancas. Na pauta, cada nota sobe um degrau: linha, espaço, linha, espaço.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.guided, "Toque com ajuda", "Suba devagar, nota por nota.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e suba até o Dó de cima.", notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.listen, "Ouça e repita", ear, notes: "C4 D4 E4 F4 G4 A4 B4 C5"),
            ]),
            Lesson(id: "treble-6", title: "A escala descendo", summary: "O caminho de volta", steps: [
                LessonStep(.explain, "Descendo", "Agora o caminho contrário: comece no Dó de cima e desça um degrau por vez até o Dó central.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(.guided, "Toque com ajuda", "Desça devagar, nota por nota.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e desça até o Dó central.", notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
                LessonStep(.listen, "Ouça e repita", ear, notes: "C5 B4 A4 G4 F4 E4 D4 C4"),
            ]),
            Lesson(id: "treble-7", title: "Ré, Mi, Fá e Sol de cima", summary: "O alto da pauta", steps: [
                LessonStep(.explain, "Ré e Mi", "O Ré fica na quarta linha, e o Mi no quarto espaço.", notes: "C5 D5 E5"),
                LessonStep(.explain, "Fá e Sol", "O Fá fica na quinta linha, a última. O Sol fica logo acima dela.", notes: "E5 F5 G5"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "C5 D5 E5 F5 G5"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "G5 E5 F5 D5"),
                LessonStep(.listen, "Ouça e repita", ear, notes: "C5 E5 G5"),
            ]),
            Lesson(id: "treble-8", title: "Linhas extras em cima", summary: "Lá, Si e Dó acima da pauta", steps: [
                LessonStep(.explain, "Linhas suplementares", "Quando a nota passa das cinco linhas, a pauta ganha linhas curtas. O Lá fica na primeira linha curta acima da pauta.", notes: "G5 A5"),
                LessonStep(.explain, "Si e Dó", "O Si fica logo acima dessa linha. O Dó fica na segunda linha curta.", notes: "A5 B5 C6"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "G5 A5 B5 C6"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "C6 A5 B5 G5"),
            ]),
            Lesson(id: "treble-9", title: "Desafio da clave de sol", summary: "Notas sorteadas, sem ajuda", steps: [
                LessonStep(.alone, "Até o Sol", "Oito notas sorteadas.", pool: "C4 D4 E4 F4 G4"),
                LessonStep(.alone, "Até o Dó de cima", "Oito notas sorteadas.", pool: "C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.alone, "Pauta inteira", "Oito notas sorteadas, do Dó central ao Dó mais alto.",
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
                LessonStep(.explain, "A clave de fá", "A mão esquerda costuma ler esta clave. Os dois pontos dela ficam em volta da quarta linha, e essa linha é o Fá.", notes: "F3", staff: .bass),
                LessonStep(.explain, "O mesmo Dó central", "Nesta clave, o Dó central fica numa linha curta acima das cinco linhas. É a mesma tecla da clave de sol.", notes: "C4", staff: .bass),
                LessonStep(.guided, "Toque com a mão esquerda", "Siga as teclas acesas.", notes: "C4 F3", staff: .bass),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "F3 C4 F3", staff: .bass),
            ]),
            Lesson(id: "bass-2", title: "Si, Lá e Sol", summary: "Descendo a partir do Dó central", steps: [
                LessonStep(.explain, "O Si", "É a tecla logo à esquerda do Dó central. Na pauta, fica logo acima da quinta linha.", notes: "C4 B3", staff: .bass),
                LessonStep(.explain, "Lá e Sol", "O Lá fica na quinta linha, a de cima. O Sol fica no quarto espaço.", notes: "B3 A3 G3", staff: .bass),
                LessonStep(.guided, "Toque com ajuda", "Desça do Dó ao Fá.", notes: "C4 B3 A3 G3 F3", staff: .bass),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "G3 B3 A3 F3", staff: .bass),
                LessonStep(.listen, "Ouça e repita", ear, notes: "C4 A3 F3", staff: .bass),
            ]),
            Lesson(id: "bass-3", title: "Mi, Ré e Dó", summary: "O meio da pauta da mão esquerda", steps: [
                LessonStep(.explain, "O Mi", "Fica no terceiro espaço, logo abaixo do Fá.", notes: "F3 E3", staff: .bass),
                LessonStep(.explain, "Ré e Dó", "O Ré fica na terceira linha, no meio da pauta. O Dó fica no segundo espaço.", notes: "E3 D3 C3", staff: .bass),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "F3 E3 D3 C3", staff: .bass),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "C3 E3 D3 F3", staff: .bass),
                LessonStep(.listen, "Ouça e repita", ear, notes: "C3 E3 G3", staff: .bass),
            ]),
            Lesson(id: "bass-4", title: "Descendo e subindo", summary: "Do Dó central ao Dó de baixo, e de volta", steps: [
                LessonStep(.explain, "A escala na clave de fá", "São as mesmas oito notas de nomes, agora uma oitava abaixo: do Dó central ao Dó do segundo espaço.", notes: "C4 B3 A3 G3 F3 E3 D3 C3", staff: .bass),
                LessonStep(.guided, "Descendo com ajuda", "Desça devagar, nota por nota.", notes: "C4 B3 A3 G3 F3 E3 D3 C3", staff: .bass),
                LessonStep(.alone, "Descendo sem ajuda", "Leia a pauta e desça.", notes: "C4 B3 A3 G3 F3 E3 D3 C3", staff: .bass),
                LessonStep(.guided, "Subindo com ajuda", "Agora o caminho contrário.", notes: "C3 D3 E3 F3 G3 A3 B3 C4", staff: .bass),
                LessonStep(.alone, "Subindo sem ajuda", "Leia a pauta e suba.", notes: "C3 D3 E3 F3 G3 A3 B3 C4", staff: .bass),
            ]),
            Lesson(id: "bass-5", title: "As notas mais graves", summary: "Até o Dó com linhas extras embaixo", steps: [
                LessonStep(.explain, "Si, Lá e Sol graves", "O Si fica na segunda linha, o Lá no primeiro espaço, e o Sol na primeira linha.", notes: "C3 B2 A2 G2", staff: .bass),
                LessonStep(.explain, "Abaixo da pauta", "O Fá fica logo abaixo da primeira linha. O Mi fica numa linha curta, o Ré logo abaixo dela, e o Dó na segunda linha curta.", notes: "G2 F2 E2 D2 C2", staff: .bass),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "C3 B2 A2 G2 F2 E2 D2 C2", staff: .bass),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "G2 C2 E2 B2 D2", staff: .bass),
            ]),
            Lesson(id: "bass-6", title: "Desafio da clave de fá", summary: "Notas sorteadas, sem ajuda", steps: [
                LessonStep(.alone, "Perto do Dó central", "Oito notas sorteadas.", staff: .bass, pool: "C4 B3 A3 G3 F3"),
                LessonStep(.alone, "Até o Dó de baixo", "Oito notas sorteadas.", staff: .bass, pool: "C4 B3 A3 G3 F3 E3 D3 C3"),
                LessonStep(.alone, "Pauta inteira", "Oito notas sorteadas, do Dó central ao Dó mais grave.", staff: .bass,
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
                LessonStep(.explain, "Duas pautas, um piano", "A clave de fá escreve a metade esquerda do piano e a clave de sol, a metade direita. Elas se encontram no Dó central, que aparece na linha curta de cada uma.", notes: "C4/t C4/b", grand: true),
                LessonStep(.explain, "Subindo o teclado", "Da esquerda para a direita, as notas sobem pela pauta de baixo e continuam na de cima.", notes: "C3 G3 C4 G4 C5", grand: true),
                LessonStep(.guided, "Toque com ajuda", "Comece com a mão esquerda e passe para a direita no Dó central.", notes: "C3 G3 C4 G4 C5", grand: true),
                LessonStep(.alone, "Agora sem ajuda", "Leia as duas pautas.", notes: "C5 G4 C4 G3 C3", grand: true),
            ]),
            Lesson(id: "grand-2", title: "Lendo as duas pautas", summary: "A nota pode vir de qualquer clave", steps: [
                LessonStep(.guided, "Toque com ajuda", "Olhe em qual pauta está cada nota.", notes: "E3 E4 A3 A4 D3 D4", grand: true),
                LessonStep(.alone, "Agora sem ajuda", "Primeiro veja a clave, depois a nota.", notes: "G3 F4 C3 B4 E3 A4", grand: true),
            ]),
            Lesson(id: "grand-3", title: "Desafio das duas claves", summary: "Notas sorteadas nas duas pautas", steps: [
                LessonStep(.alone, "Sorteio", "Oito notas sorteadas nas duas pautas.", grand: true,
                           pool: "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5"),
                LessonStep(.alone, "Mais um sorteio", "Oito notas novas.", grand: true,
                           pool: "C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5"),
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
                LessonStep(.explain, "O sinal ♯", "O sustenido sobe a nota meio tom: toque a tecla logo à direita. Ele fica antes da nota, na mesma altura dela.", notes: "F4 F#4"),
                LessonStep(.explain, "As teclas pretas", "Dó♯, Ré♯, Fá♯, Sol♯ e Lá♯ são as cinco teclas pretas de cada oitava.", notes: "C#4 D#4 F#4 G#4 A#4"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "C#4 D#4 F#4 G#4 A#4"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "G#4 C#4 A#4 D#4 F#4"),
            ]),
            Lesson(id: "acc-2", title: "O bemol", summary: "Desce a nota meio tom", steps: [
                LessonStep(.explain, "O sinal ♭", "O bemol desce a nota meio tom: toque a tecla logo à esquerda.", notes: "B4 Bb4"),
                LessonStep(.explain, "As teclas pretas de novo", "Ré♭, Mi♭, Sol♭, Lá♭ e Si♭ são as mesmas cinco teclas pretas, com outros nomes.", notes: "Db4 Eb4 Gb4 Ab4 Bb4"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "Db4 Eb4 Gb4 Ab4 Bb4"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "Ab4 Db4 Bb4 Eb4 Gb4"),
            ]),
            Lesson(id: "acc-3", title: "Uma tecla, dois nomes", summary: "Dó♯ e Ré♭ são a mesma tecla", steps: [
                LessonStep(.explain, "O mesmo som", "Dó♯ e Ré♭ se escrevem em lugares diferentes da pauta, mas são a mesma tecla preta.", notes: "C#4 Db4", litKeys: "C#4"),
                LessonStep(.guided, "Toque com ajuda", "As duas notas de cada par são a mesma tecla.", notes: "C#4 Db4 F#4 Gb4"),
                LessonStep(.alone, "Agora sem ajuda", "Leia a pauta e toque.", notes: "Eb4 D#4 Bb4 A#4"),
            ]),
            Lesson(id: "acc-4", title: "O bequadro", summary: "Cancela o sustenido ou o bemol", steps: [
                LessonStep(.explain, "Vale até o fim do compasso", "Depois de um sustenido, as mesmas notas seguintes continuam alteradas até a barra de compasso, mesmo sem o sinal.", notes: "F#4 F#4"),
                LessonStep(.explain, "O sinal ♮", "O bequadro cancela a alteração e a nota volta à tecla branca.", notes: "F#4 F#4 F4"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "F#4 F#4 F4 G4"),
                LessonStep(.alone, "Agora sem ajuda", "Atenção à nota sem sinal depois do sustenido.", notes: "C#4 C#4 C4 D4"),
            ]),
            Lesson(id: "acc-5", title: "Desafio dos sinais", summary: "Brancas e pretas sorteadas", steps: [
                LessonStep(.alone, "Sustenidos", "Oito notas sorteadas.", pool: "C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4"),
                LessonStep(.alone, "Bemóis", "Oito notas sorteadas.", pool: "C4 Db4 D4 Eb4 E4 F4 Gb4 G4 Ab4 A4 Bb4 B4"),
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
                LessonStep(.explain, "O pulso", "A música tem uma batida regular, o pulso. O metrônomo marca essa batida. A semínima dura um pulso.", notes: "C4:q C4:q C4:q C4:q", meter: 4),
                LessonStep(.rhythm, "Uma nota por pulso", "O metrônomo conta 4 tempos antes de começar. Depois, toque uma nota em cada clique.", notes: "C4:q C4:q C4:q C4:q", meter: 4),
                LessonStep(.rhythm, "Mudando de nota", "O mesmo pulso, com notas diferentes.", notes: "C4:q D4:q E4:q C4:q", meter: 4),
            ]),
            Lesson(id: "rhy-2", title: "Mínima e semibreve", summary: "Notas de 2 e de 4 pulsos", steps: [
                LessonStep(.explain, "A mínima", "A mínima tem a cabeça vazia e dura dois pulsos: toque e segure.", notes: "C4:h C4:h", meter: 4),
                LessonStep(.explain, "A semibreve", "A semibreve não tem haste e dura quatro pulsos.", notes: "C4:w", meter: 4),
                LessonStep(.rhythm, "Mínimas", "Toque a cada dois cliques.", notes: "C4:h D4:h E4:h C4:h", meter: 4),
                LessonStep(.rhythm, "Misturando", "Semínimas, mínimas e semibreve.", notes: "C4:q C4:q D4:h E4:w", meter: 4),
            ]),
            Lesson(id: "rhy-3", title: "O compasso", summary: "Os pulsos agrupados", steps: [
                LessonStep(.explain, "O que é o compasso", "As barras dividem a música em grupos de pulsos. O 4 de cima diz que cada compasso tem quatro pulsos, e o 4 de baixo que a semínima vale um pulso.", notes: "C4:q D4:q E4:q F4:q G4:q F4:q E4:q D4:q", meter: 4),
                LessonStep(.rhythm, "Dois compassos", "O primeiro clique de cada compasso é mais forte.", notes: "C4:q D4:q E4:q F4:q G4:q F4:q E4:q D4:q", meter: 4),
            ]),
            Lesson(id: "rhy-4", title: "Pausas", summary: "O silêncio também tem duração", steps: [
                LessonStep(.explain, "Pausa de semínima", "A pausa é um tempo em silêncio. Esta dura um pulso: não toque nada e espere.", notes: "C4:q R:q C4:q R:q", meter: 4),
                LessonStep(.explain, "Pausas longas", "A pausa de mínima fica em cima da terceira linha e dura dois pulsos. A de semibreve fica pendurada na quarta linha e dura o compasso inteiro.", notes: "C4:h R:h R:w", meter: 4),
                LessonStep(.rhythm, "Toque e espere", "Toque nos tempos com nota e fique em silêncio nas pausas.", notes: "C4:q R:q D4:q R:q", meter: 4),
                LessonStep(.rhythm, "Pausa longa", "Conte os cliques durante a pausa.", notes: "C4:h R:h E4:q E4:q R:h", meter: 4),
            ]),
            Lesson(id: "rhy-5", title: "Colcheias", summary: "Duas notas em cada pulso", steps: [
                LessonStep(.explain, "A colcheia", "A colcheia tem uma bandeirinha e dura meio pulso. Duas colcheias cabem em um clique.", notes: "C4:e C4:e C4:e C4:e C4:q C4:q", meter: 4, tempo: 60),
                LessonStep(.rhythm, "Duas por pulso", "Uma colcheia no clique e a outra entre os cliques.", notes: "C4:e C4:e D4:e D4:e E4:q E4:q", meter: 4, tempo: 60),
            ]),
            Lesson(id: "rhy-6", title: "O ponto de aumento", summary: "O ponto soma metade da duração", steps: [
                LessonStep(.explain, "O ponto", "O ponto depois da nota soma metade do valor dela. A mínima com ponto dura três pulsos.", notes: "C4:h. D4:q", meter: 4),
                LessonStep(.rhythm, "Mínima com ponto", "Segure por três cliques.", notes: "C4:h. D4:q E4:h. C4:q", meter: 4),
                LessonStep(.explain, "Semínima com ponto", "A semínima com ponto dura um pulso e meio, e costuma vir seguida de uma colcheia.", notes: "C4:q. D4:e E4:h", meter: 4, tempo: 60),
                LessonStep(.rhythm, "Semínima com ponto", "A colcheia entra entre o segundo e o terceiro clique.", notes: "C4:q. D4:e E4:h", meter: 4, tempo: 60),
            ]),
            Lesson(id: "rhy-7", title: "Compasso de 3", summary: "A valsa", steps: [
                LessonStep(.explain, "Três pulsos", "Com o 3 em cima, cada compasso tem três pulsos. O primeiro continua mais forte.", notes: "C4:q E4:q G4:q C5:h.", meter: 3),
                LessonStep(.rhythm, "Conte até 3", "Um, dois, três; um, dois, três.", notes: "C4:q E4:q G4:q C5:h.", meter: 3),
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
                LessonStep(.explain, "Sinais logo depois da clave", "A armadura vale para a música toda. Aqui o sustenido está na linha do Fá: todo Fá é Fá♯, mesmo sem sinal ao lado da nota.", notes: "F#4 F#5", key: 1),
                LessonStep(.guided, "Toque com ajuda", "Veja que a tecla do Fá é preta.", notes: "E4 F#4 G4 F#4", key: 1),
                LessonStep(.alone, "Agora sem ajuda", "Lembre da armadura.", notes: "G4 F#4 E4 F#4", key: 1),
            ]),
            Lesson(id: "key-2", title: "Escala de Sol maior", summary: "Um sustenido na armadura", steps: [
                LessonStep(.explain, "Sol maior", "Começa no Sol e tem o Fá♯. É o mesmo desenho de distâncias da escala de Dó.", notes: "G4 A4 B4 C5 D5 E5 F#5 G5", key: 1),
                LessonStep(.guided, "Subindo com ajuda", "Siga as teclas acesas.", notes: "G4 A4 B4 C5 D5 E5 F#5 G5", key: 1),
                LessonStep(.alone, "Subindo sem ajuda", "Leia a pauta e toque.", notes: "G4 A4 B4 C5 D5 E5 F#5 G5", key: 1),
                LessonStep(.alone, "Descendo", "Agora o caminho de volta.", notes: "G5 F#5 E5 D5 C5 B4 A4 G4", key: 1),
            ]),
            Lesson(id: "key-3", title: "Escala de Fá maior", summary: "Um bemol na armadura", steps: [
                LessonStep(.explain, "Fá maior", "Começa no Fá e tem o Si♭. O bemol na armadura fica na linha do Si.", notes: "F4 G4 A4 Bb4 C5 D5 E5 F5", key: -1),
                LessonStep(.guided, "Subindo com ajuda", "Siga as teclas acesas.", notes: "F4 G4 A4 Bb4 C5 D5 E5 F5", key: -1),
                LessonStep(.alone, "Subindo sem ajuda", "Leia a pauta e toque.", notes: "F4 G4 A4 Bb4 C5 D5 E5 F5", key: -1),
                LessonStep(.alone, "Descendo", "Agora o caminho de volta.", notes: "F5 E5 D5 C5 Bb4 A4 G4 F4", key: -1),
            ]),
            Lesson(id: "key-4", title: "Desafio das armaduras", summary: "Notas sorteadas em cada tonalidade", steps: [
                LessonStep(.alone, "Sol maior", "Todo Fá é sustenido.", key: 1, pool: "G4 A4 B4 C5 D5 E5 F#5 G5"),
                LessonStep(.alone, "Fá maior", "Todo Si é bemol.", key: -1, pool: "F4 G4 A4 Bb4 C5 D5 E5 F5"),
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
                LessonStep(.explain, "Notas alinhadas", "Notas na mesma coluna das duas pautas são tocadas ao mesmo tempo. Com o microfone, toque as duas juntas.", notes: "C3+C4 D3+D4 E3+E4", grand: true),
                LessonStep(.guided, "Toque com ajuda", "A mesma nota em cada mão, uma oitava de distância.", notes: "C3+C4 D3+D4 E3+E4 D3+D4 C3+C4", grand: true),
                LessonStep(.alone, "Agora sem ajuda", "Leia as duas pautas.", notes: "E3+E4 C3+C4 D3+D4 C3+C4", grand: true),
            ]),
            Lesson(id: "hands-2", title: "Melodia e baixo", summary: "Cada mão com a sua nota", steps: [
                LessonStep(.guided, "Toque com ajuda", "A mão esquerda fica no Dó e a direita caminha.", notes: "C3+E4 C3+F4 C3+G4 C3+E4", grand: true),
                LessonStep(.alone, "Agora sem ajuda", "Agora a mão esquerda também muda.", notes: "C3+E4 G3+D4 C3+C4 G3+D4 C3+E4", grand: true),
            ]),
            Lesson(id: "chord-1", title: "O acorde de Dó maior", summary: "Três notas juntas", steps: [
                LessonStep(.explain, "O que é um acorde", "São três ou mais notas tocadas juntas. O acorde de Dó maior usa Dó, Mi e Sol. Na pauta, as notas ficam empilhadas.", notes: "C4+E4+G4"),
                LessonStep(.guided, "Toque com ajuda", "Na tela, pode tocar uma tecla de cada vez. No piano, toque as três juntas.", notes: "C4+E4+G4"),
                LessonStep(.alone, "Agora sem ajuda", "Toque o acorde três vezes.", notes: "C4+E4+G4 C4+E4+G4 C4+E4+G4"),
            ]),
            Lesson(id: "chord-2", title: "Fá e Sol maior", summary: "Mais dois acordes", steps: [
                LessonStep(.explain, "Mesmo desenho", "Os acordes de Fá maior e de Sol maior têm o mesmo formato: uma nota sim, uma não.", notes: "F4+A4+C5 G4+B4+D5"),
                LessonStep(.guided, "Toque com ajuda", "Siga as teclas acesas.", notes: "F4+A4+C5 G4+B4+D5"),
                LessonStep(.alone, "Agora sem ajuda", "Leia as notas empilhadas.", notes: "G4+B4+D5 F4+A4+C5 G4+B4+D5"),
            ]),
            Lesson(id: "chord-3", title: "Sequência de acordes", summary: "Dó, Fá, Sol, Dó", steps: [
                LessonStep(.guided, "Toque com ajuda", "Esta sequência aparece em muitas músicas.", notes: "C4+E4+G4 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
                LessonStep(.alone, "Agora sem ajuda", "Leia e toque.", notes: "C4+E4+G4 F4+A4+C5 G4+B4+D5 C4+E4+G4"),
                LessonStep(.rhythm, "No tempo", "Um acorde a cada compasso.", notes: "C4+E4+G4:w F4+A4+C5:w G4+B4+D5:w C4+E4+G4:w", meter: 4, tempo: 80),
            ]),
        ]
    )

    // MARK: - Primeiras Músicas

    /// Learns each different phrase with help and in time, then plays the whole song along with the app.
    private static func song(id: String, title: String, summary: String, intro: String, phrases: [String], tempo: Int = 72) -> Lesson {
        var learned: [String] = []
        var steps = [LessonStep(.explain, title, intro, notes: phrases[0], meter: 4, tempo: tempo)]
        for phrase in phrases where !learned.contains(phrase) {
            learned.append(phrase)
            let number = learned.count
            steps.append(LessonStep(.guided, "Trecho \(number) com ajuda", "Siga as teclas acesas, sem pressa.", notes: phrase, meter: 4, tempo: tempo))
            steps.append(LessonStep(.alone, "Trecho \(number) sem ajuda", "Leia a pauta e toque.", notes: phrase, meter: 4, tempo: tempo))
            steps.append(LessonStep(.rhythm, "Trecho \(number) no tempo", "Agora com o metrônomo.", notes: phrase, meter: 4, tempo: tempo))
        }
        for (index, phrase) in phrases.enumerated() {
            steps.append(LessonStep(.playAlong, "Tocando junto: \(index + 1) de \(phrases.count)", "O app toca a música e você toca junto.", notes: phrase, meter: 4, tempo: tempo))
        }
        return Lesson(id: id, title: title, summary: summary, steps: steps)
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
}
