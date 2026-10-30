// luksMusic - library of the web player.
// `id` names the score's Firestore docs (scoreSettings/{id}, scores/{id}); `slug` is its ?partitura= link.
// `data` sets window.SCORE_DATA / MEASURE_LAYOUT / NOTE_COLUMNS for the engraved `pages`.
// Scores without a scoreSettings doc use `defaultPrivacy`: copyrighted songs stay private to the author (who can
// invite people by e-mail), public-domain and openly licensed editions are public.
window.SCORE_CATALOG = [
    {
        id: "lotm",
        slug: "dark-dream",
        title: "DARK DREAM (LOTM ED)",
        sidebarTitle: "Dark Dream – Curley Gao",
        credits: "Curley Gao • Arr. lukscli • Lord of the Mysteries",
        shortCredits: "Curley Gao • LOTM ED",
        arranger: "lukscli",
        authorId: "lukscli",
        defaultPrivacy: "private",
        license: null,
        bpm: 70,
        beatsPerMeasure: 4,
        measures: 56,
        durationLabel: "03:12",
        pages: [1, 2, 3, 4, 5, 6, 7].map(n => `score_page_${n}.svg`),
        data: "dark_dream_score.js",
        audio: "dark_dream_audio_clean.mp3",
        tags: ["Advanced", "Soundtrack", "Solo Piano", "Piano", "Piano for Advanced"],
        downloads: [
            { href: "dark_dream_official.mid", filename: "Dark_Dream_Curley_Gao.mid", icon: "🎹", iconClass: "midi-icon",
              title: "Arquivo MIDI (.mid)", desc: "Todas as 56 medidas, canais independentes de mão direita e esquerda." },
            { href: "dark_dream_audio_clean.mp3", filename: "Dark_Dream_Curley_Gao.mp3", icon: "🎵", iconClass: "audio-icon",
              title: "Áudio Master (.mp3 320 kbps)", desc: "Gravação completa sem ruídos ou chiados." },
            { href: "dark_dream_score.json", filename: "Dark_Dream_Curley_Gao_Score.json", icon: "🎼", iconClass: "json-icon",
              title: "Dados da Partitura (.json)", desc: "Estrutura vetorial compatível com sintetizadores e sequenciadores." }
        ]
    },
    // Public-domain music in CC0 digital editions from MuseScore, taken from the PDMX dataset
    // (https://zenodo.org/records/15571083) and engraved with web/tools/build_score.py
    {
        id: "waltz-of-the-flowers",
        slug: "waltz-of-the-flowers",
        title: "WALTZ OF THE FLOWERS (O QUEBRA-NOZES)",
        sidebarTitle: "Waltz of the Flowers – Tchaikovsky",
        credits: "P. I. Tchaikovsky • Arr. Eduard Langer • Piano a 4 mãos",
        shortCredits: "Tchaikovsky • Op. 71",
        arranger: "Eduard Langer (1835–1905)",
        authorId: null,
        defaultPrivacy: "public",
        license: { name: "Domínio público (CC0 1.0)", url: "https://creativecommons.org/publicdomain/zero/1.0/" },
        edition: "O Quebra-Nozes, Op. 71, nº 13. Arranjo para piano a 4 mãos de Eduard Langer, digitado por hmscomp no MuseScore. Ritornelos escritos por extenso.",
        editionUrl: "https://musescore.com/user/24069/scores/1460071",
        bpm: 150,
        beatsPerMeasure: 3,
        measures: 389,
        durationLabel: "07:42",
        pages: Array.from({ length: 13 }, (_, i) => `scores/waltz-of-the-flowers/page_${i + 1}.svg`),
        data: "scores/waltz-of-the-flowers/score.js",
        audio: null,
        channels: {
            treble: { name: "Primo", notes: "Primo (agudos)", desc: "Pianista 1 • Melodia", preset: "Só Primo", short: "Primo" },
            bass: { name: "Secondo", notes: "Secondo (graves)", desc: "Pianista 2 • Harmonia & Baixo", preset: "Só Secondo", short: "Sec." }
        },
        tags: ["Classical", "Ballet", "Waltz", "Piano Duet", "Public Domain"],
        downloads: [
            { href: "scores/waltz-of-the-flowers/waltz-of-the-flowers.mxl", filename: "Waltz_of_the_Flowers_Langer_4_hands.mxl", icon: "🎼", iconClass: "json-icon",
              title: "MusicXML (.mxl)", desc: "Edição CC0 original, com ritornelos, para abrir no MuseScore e outros editores." },
            { href: "scores/waltz-of-the-flowers/score.mid", filename: "Waltz_of_the_Flowers_Langer_4_hands.mid", icon: "🎹", iconClass: "midi-icon",
              title: "Arquivo MIDI (.mid)", desc: "Todas as 389 medidas na ordem de execução, com as mudanças de andamento." }
        ]
    },
    {
        id: "waltz-of-the-flowers-3-hands",
        slug: "waltz-of-the-flowers-3-hands",
        title: "WALTZ OF THE FLOWERS (3 MÃOS)",
        sidebarTitle: "Waltz of the Flowers (3 mãos) – Tchaikovsky",
        credits: "P. I. Tchaikovsky • Arr. Hinci • Piano a 3 mãos",
        shortCredits: "Tchaikovsky • Op. 71",
        arranger: "Hinci",
        authorId: null,
        defaultPrivacy: "public",
        license: { name: "CC0 1.0", url: "https://creativecommons.org/publicdomain/zero/1.0/" },
        edition: "O Quebra-Nozes, Op. 71, nº 13. Arranjo de Hinci para piano a 3 mãos, publicado no MuseScore. Ritornelos escritos por extenso.",
        editionUrl: "https://musescore.com/user/29637645/scores/6159042",
        bpm: 146,
        beatsPerMeasure: 3,
        measures: 389,
        durationLabel: "06:47",
        pages: Array.from({ length: 10 }, (_, i) => `scores/waltz-of-the-flowers-3-hands/page_${i + 1}.svg`),
        data: "scores/waltz-of-the-flowers-3-hands/score.js",
        audio: null,
        tags: ["Classical", "Ballet", "Waltz", "Piano", "Public Domain"],
        downloads: [
            { href: "scores/waltz-of-the-flowers-3-hands/waltz-of-the-flowers-3-hands.mxl", filename: "Waltz_of_the_Flowers_3_hands.mxl", icon: "🎼", iconClass: "json-icon",
              title: "MusicXML (.mxl)", desc: "Edição CC0 original, com ritornelos, para abrir no MuseScore e outros editores." },
            { href: "scores/waltz-of-the-flowers-3-hands/score.mid", filename: "Waltz_of_the_Flowers_3_hands.mid", icon: "🎹", iconClass: "midi-icon",
              title: "Arquivo MIDI (.mid)", desc: "Todas as 389 medidas na ordem de execução, com as mudanças de andamento." }
        ]
    },
    {
        id: "october-autumn-song",
        slug: "october-autumn-song",
        title: "OCTOBER: AUTUMN SONG (AS ESTAÇÕES)",
        sidebarTitle: "October (Autumn Song) – Tchaikovsky",
        credits: "P. I. Tchaikovsky • As Estações, Op. 37a nº 10 • Piano solo",
        shortCredits: "Tchaikovsky • Op. 37a",
        arranger: "P. I. Tchaikovsky (original para piano)",
        authorId: null,
        defaultPrivacy: "public",
        license: { name: "CC0 1.0", url: "https://creativecommons.org/publicdomain/zero/1.0/" },
        edition: "As Estações, Op. 37a, nº 10 (Outubro: Canção de Outono), obra original para piano, digitada no MuseScore.",
        editionUrl: "https://musescore.com/user/20994881/scores/5333841",
        bpm: 80,
        beatsPerMeasure: 4,
        measures: 56,
        durationLabel: "02:50",
        pages: [1, 2].map(n => `scores/october-autumn-song/page_${n}.svg`),
        data: "scores/october-autumn-song/score.js",
        audio: null,
        tags: ["Classical", "Romantic", "Solo Piano", "Piano", "Public Domain"],
        downloads: [
            { href: "scores/october-autumn-song/october-autumn-song.mxl", filename: "October_Autumn_Song_Tchaikovsky.mxl", icon: "🎼", iconClass: "json-icon",
              title: "MusicXML (.mxl)", desc: "Edição CC0 original para abrir no MuseScore e outros editores." },
            { href: "scores/october-autumn-song/score.mid", filename: "October_Autumn_Song_Tchaikovsky.mid", icon: "🎹", iconClass: "midi-icon",
              title: "Arquivo MIDI (.mid)", desc: "As 56 medidas com as mudanças de andamento." }
        ]
    }
];
