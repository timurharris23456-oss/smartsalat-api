//
//  Ayah.swift
//  salattracker
//
//  A curated, offline collection of Qur'anic verses. One is shown per day,
//  rolling over at Fajr so a new ayah "releases" each morning.
//

import Foundation

struct Ayah: Identifiable, Hashable {
    let arabic: String
    let translation: String
    let reference: String

    var id: String { reference }
}

enum AyahLibrary {
    /// The ayah for a given day. The day is considered to begin at Fajr, so
    /// before Fajr the previous day's ayah is shown; after Fajr the new one.
    static func ayah(on date: Date, afterFajr fajr: Date?, calendar: Calendar = .current) -> Ayah {
        var day = calendar.startOfDay(for: date)
        if let fajr, date < fajr {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        let dayNumber = Int((day.timeIntervalSince1970 / 86400).rounded(.down))
        let count = all.count
        return all[((dayNumber % count) + count) % count]
    }

    /// Translations follow the Saheeh International rendering.
    static let all: [Ayah] = [
        Ayah(arabic: "إِنَّ مَعَ الْعُسْرِ يُسْرًا",
              translation: "Indeed, with hardship [will be] ease.",
              reference: "Ash-Sharh 94:6"),
        Ayah(arabic: "الَّذِينَ آمَنُوا وَتَطْمَئِنُّ قُلُوبُهُم بِذِكْرِ اللَّهِ ۗ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
              translation: "Those who have believed and whose hearts are assured by the remembrance of Allah. Unquestionably, by the remembrance of Allah hearts are assured.",
              reference: "Ar-Ra'd 13:28"),
        Ayah(arabic: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا",
              translation: "Allah does not charge a soul except [with that within] its capacity.",
              reference: "Al-Baqarah 2:286"),
        Ayah(arabic: "فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ",
              translation: "So remember Me; I will remember you. And be grateful to Me and do not deny Me.",
              reference: "Al-Baqarah 2:152"),
        Ayah(arabic: "يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ إِنَّ اللَّهَ مَعَ الصَّابِرِينَ",
              translation: "O you who have believed, seek help through patience and prayer. Indeed, Allah is with the patient.",
              reference: "Al-Baqarah 2:153"),
        Ayah(arabic: "قُلْ يَا عِبَادِيَ الَّذِينَ أَسْرَفُوا عَلَىٰ أَنفُسِهِمْ لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ ۚ إِنَّ اللَّهَ يَغْفِرُ الذُّنُوبَ جَمِيعًا",
              translation: "Say, 'O My servants who have transgressed against themselves, do not despair of the mercy of Allah. Indeed, Allah forgives all sins.'",
              reference: "Az-Zumar 39:53"),
        Ayah(arabic: "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ",
              translation: "And whoever relies upon Allah - then He is sufficient for him.",
              reference: "At-Talaq 65:3"),
        Ayah(arabic: "وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ",
              translation: "So do not weaken and do not grieve, and you will be superior if you are [true] believers.",
              reference: "Aal-E-Imran 3:139"),
        Ayah(arabic: "وَالَّذِينَ جَاهَدُوا فِينَا لَنَهْدِيَنَّهُمْ سُبُلَنَا ۚ وَإِنَّ اللَّهَ لَمَعَ الْمُحْسِنِينَ",
              translation: "And those who strive for Us - We will surely guide them to Our ways. And indeed, Allah is with the doers of good.",
              reference: "Al-'Ankabut 29:69"),
        Ayah(arabic: "لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ",
              translation: "If you are grateful, I will surely increase you [in favor].",
              reference: "Ibrahim 14:7"),
        Ayah(arabic: "وَقُل رَّبِّ زِدْنِي عِلْمًا",
              translation: "And say, 'My Lord, increase me in knowledge.'",
              reference: "Ta-Ha 20:114"),
        Ayah(arabic: "إِنَّ أَكْرَمَكُمْ عِندَ اللَّهِ أَتْقَاكُمْ",
              translation: "Indeed, the most noble of you in the sight of Allah is the most righteous of you.",
              reference: "Al-Hujurat 49:13"),
        Ayah(arabic: "وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ",
              translation: "And your Lord is going to give you, and you will be satisfied.",
              reference: "Ad-Duhaa 93:5"),
        Ayah(arabic: "مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ",
              translation: "Your Lord has not taken leave of you, nor has He detested [you].",
              reference: "Ad-Duhaa 93:3"),
        Ayah(arabic: "وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ ۖ أُجِيبُ دَعْوَةَ الدَّاعِ إِذَا دَعَانِ",
              translation: "And when My servants ask you concerning Me - indeed I am near. I respond to the invocation of the supplicant when he calls upon Me.",
              reference: "Al-Baqarah 2:186"),
        Ayah(arabic: "وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ ۖ إِنَّهُ لَا يَيْأَسُ مِن رَّوْحِ اللَّهِ إِلَّا الْقَوْمُ الْكَافِرُونَ",
              translation: "And do not despair of relief from Allah. Indeed, no one despairs of relief from Allah except the disbelieving people.",
              reference: "Yusuf 12:87"),
        Ayah(arabic: "لَا تَحْزَنْ إِنَّ اللَّهَ مَعَنَا",
              translation: "Do not grieve; indeed Allah is with us.",
              reference: "At-Tawbah 9:40"),
        Ayah(arabic: "الَّذِي خَلَقَ الْمَوْتَ وَالْحَيَاةَ لِيَبْلُوَكُمْ أَيُّكُمْ أَحْسَنُ عَمَلًا",
              translation: "[He] who created death and life to test you [as to] which of you is best in deed.",
              reference: "Al-Mulk 67:2"),
        Ayah(arabic: "مَنْ عَمِلَ صَالِحًا مِّن ذَكَرٍ أَوْ أُنثَىٰ وَهُوَ مُؤْمِنٌ فَلَنُحْيِيَنَّهُ حَيَاةً طَيِّبَةً",
              translation: "Whoever does righteousness, whether male or female, while being a believer - We will surely cause him to live a good life.",
              reference: "An-Nahl 16:97"),
        Ayah(arabic: "ادْعُونِي أَسْتَجِبْ لَكُمْ",
              translation: "Call upon Me; I will respond to you.",
              reference: "Ghafir 40:60"),
        Ayah(arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
              translation: "Our Lord, give us in this world [that which is] good and in the Hereafter [that which is] good and protect us from the punishment of the Fire.",
              reference: "Al-Baqarah 2:201"),
        Ayah(arabic: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
              translation: "It is You we worship and You we ask for help.",
              reference: "Al-Fatihah 1:5"),
        Ayah(arabic: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ",
              translation: "Allah - there is no deity except Him, the Ever-Living, the Sustainer of [all] existence.",
              reference: "Al-Baqarah 2:255"),
        Ayah(arabic: "وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ",
              translation: "But perhaps you hate a thing and it is good for you.",
              reference: "Al-Baqarah 2:216"),
        Ayah(arabic: "إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِ",
              translation: "Indeed, good deeds do away with misdeeds.",
              reference: "Hud 11:114"),
        Ayah(arabic: "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ",
              translation: "So which of the favors of your Lord would you deny?",
              reference: "Ar-Rahman 55:13"),
        Ayah(arabic: "رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا",
              translation: "Our Lord, grant us from among our spouses and offspring comfort to our eyes and make us a leader [i.e., example] for the righteous.",
              reference: "Al-Furqan 25:74"),
        Ayah(arabic: "وَبَشِّرِ الصَّابِرِينَ",
              translation: "And give good tidings to the patient.",
              reference: "Al-Baqarah 2:155"),
        Ayah(arabic: "إِنَّ اللَّهَ مَعَ الَّذِينَ اتَّقَوا وَّالَّذِينَ هُم مُّحْسِنُونَ",
              translation: "Indeed, Allah is with those who fear Him and those who are doers of good.",
              reference: "An-Nahl 16:128"),
        Ayah(arabic: "وَاصْبِرْ فَإِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ",
              translation: "And be patient, for indeed, Allah does not allow to be lost the reward of those who do good.",
              reference: "Hud 11:115"),
    ]
}
