import SwiftUI

// How to play, in English, Nepali and Hindi. Every string sits beside its
// translations so a reviewer reads all three together; English is canonical
// and uses "tricks", glossed once as "hands".

enum RulesLanguage: Int, CaseIterable {
    case english, nepali, hindi

    /// The language's own name, as on its switch.
    var name: String {
        switch self {
        case .english: "English"
        case .nepali: "नेपाली"
        case .hindi: "हिंदी"
        }
    }

    var accessibilityName: String {
        switch self {
        case .english: "English"
        case .nepali: "Nepali"
        case .hindi: "Hindi"
        }
    }

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en")
        case .nepali: Locale(identifier: "ne")
        case .hindi: Locale(identifier: "hi")
        }
    }
}

struct Localized {
    let en: String
    let ne: String
    let hi: String

    subscript(language: RulesLanguage) -> String {
        switch language {
        case .english: en
        case .nepali: ne
        case .hindi: hi
        }
    }
}

struct RuleTopic: Identifiable {
    let id: String
    let title: Localized
    let pages: [RulePage]
}

struct RulePage {
    let title: Localized
    let body: Localized
    var diagram: RuleDiagram? = nil
    var note: Localized? = nil
}

/// Cards on the table so far, then an arrow and your choices, if any.
struct RuleDiagram {
    let table: [DiagramCard]
    var choices: [DiagramCard] = []
}

struct DiagramCard {
    enum Mark { case plain, ringed, dimmed, chosen }

    let card: Card
    var label: DiagramLabel? = nil
    var mark: Mark = .plain

    init(_ rank: Rank, _ suit: Suit, _ label: DiagramLabel? = nil, _ mark: Mark = .plain) {
        self.card = Card(suit: suit, rank: rank)
        self.label = label
        self.mark = mark
    }
}

enum DiagramLabel {
    case led, winning, wins, mustPlay, mayPlay, tooLow, notAllowed, cantWin

    var text: Localized {
        switch self {
        case .led: Localized(en: "led", ne: "पहिलो", hi: "पहला")
        case .winning: Localized(en: "winning", ne: "जित्दै", hi: "जीत रहा")
        case .wins: Localized(en: "wins", ne: "जित्छ", hi: "जीतता है")
        case .mustPlay: Localized(en: "must play", ne: "फाल्नैपर्छ", hi: "चलना ज़रूरी")
        case .mayPlay: Localized(en: "may play", ne: "फाल्न पाइन्छ", hi: "चल सकते हैं")
        case .tooLow: Localized(en: "too low", ne: "अझ ठूलो चाहिन्छ", hi: "बड़ा पत्ता चाहिए")
        case .notAllowed: Localized(en: "not allowed", ne: "पाइँदैन", hi: "मना है")
        case .cantWin: Localized(en: "can’t win", ne: "जित्न सक्दैन", hi: "जीत नहीं सकता")
        }
    }
}

enum RulesText {
    static let title = Localized(en: "How to play", ne: "खेल्ने तरिका", hi: "कैसे खेलें")
    static let previous = Localized(en: "Previous", ne: "अघिल्लो", hi: "पिछला")
    static let next = Localized(en: "Next", ne: "अर्को", hi: "अगला")

    /// "Playing · 2 of 4"
    static func position(_ page: Int, of count: Int, in language: RulesLanguage) -> String {
        switch language {
        case .english: "\(page) of \(count)"
        case .nepali: "\(count.formatted(.number.locale(language.locale))) मध्ये \(page.formatted(.number.locale(language.locale)))"
        case .hindi: "\(count) में से \(page)"
        }
    }

    static let topics: [RuleTopic] = [
        RuleTopic(id: "basics", title: Localized(en: "Basics", ne: "आधारभूत कुरा", hi: "बुनियादी बातें"), pages: [
            RulePage(
                title: Localized(
                    en: "Four players, 13 tricks",
                    ne: "चार खेलाडी, १३ हात",
                    hi: "चार खिलाड़ी, 13 हाथ"
                ),
                body: Localized(
                    en: "You play against three bots. Everyone is dealt 13 cards, and a round is 13 tricks (also called hands): each player plays one card, and the best card takes the trick.",
                    ne: "तपाईं तीन बोटसँग खेल्नुहुन्छ। सबैलाई १३ पत्ती बाँडिन्छ, र एक राउन्डमा १३ हात हुन्छन्: हरेक खेलाडीले एउटा पत्ती फाल्छ, र सबैभन्दा बलियो पत्तीले हात जित्छ।",
                    hi: "आप तीन बॉट्स के साथ खेलते हैं। सबको 13 पत्ते बाँटे जाते हैं, और एक राउंड में 13 हाथ होते हैं: हर खिलाड़ी एक पत्ता चलता है, और सबसे बड़ा पत्ता हाथ जीतता है।"
                ),
                diagram: RuleDiagram(table: [
                    DiagramCard(.seven, .hearts, .led),
                    DiagramCard(.ten, .hearts),
                    DiagramCard(.queen, .hearts, .wins, .ringed),
                    DiagramCard(.nine, .hearts),
                ])
            ),
            RulePage(
                title: Localized(
                    en: "Spades are always trump",
                    ne: "हुकुम सधैं तुरुप हो",
                    hi: "हुकुम हमेशा तुरुप है"
                ),
                body: Localized(
                    en: "A Spade beats any card of another suit. Within a suit, the Ace is highest, then King, Queen, Jack, and 10 down to 2.",
                    ne: "हुकुमले अरू जुनसुकै रङको पत्तीलाई काट्छ। एउटै रङमा एक्का सबैभन्दा ठूलो हुन्छ, त्यसपछि बादशाह, बेगम, गुलाम, अनि १० देखि २ सम्म।",
                    hi: "हुकुम किसी भी दूसरे रंग के पत्ते को काटता है। एक ही रंग में इक्का सबसे बड़ा है, फिर बादशाह, बेगम, गुलाम, और 10 से 2 तक।"
                ),
                diagram: RuleDiagram(
                    table: [DiagramCard(.ace, .hearts, .led)],
                    choices: [DiagramCard(.two, .spades, .wins, .ringed)]
                ),
                note: Localized(
                    en: "Even the 2 of Spades beats the Ace of Hearts.",
                    ne: "हुकुमको २ ले पनि पानको एक्कालाई काट्छ।",
                    hi: "हुकुम की दुक्की भी पान के इक्के को काटती है।"
                )
            ),
            RulePage(
                title: Localized(
                    en: "Play goes anti-clockwise",
                    ne: "पालो घडीको उल्टो दिशामा घुम्छ",
                    hi: "बारी घड़ी की उल्टी दिशा में चलती है"
                ),
                body: Localized(
                    en: "The player after the dealer calls first and leads the first trick. Play then passes anti-clockwise: from you to the player on your right, then across, then left. Whoever wins a trick leads the next.",
                    ne: "डिलरपछिको खेलाडीले पहिले कल गर्छ र पहिलो हात सुरु गर्छ। त्यसपछि पालो घडीको उल्टो दिशामा जान्छ: तपाईंबाट दायाँको खेलाडी, त्यसपछि अगाडिको, अनि बायाँको। जसले हात जित्छ, उसैले अर्को हात सुरु गर्छ।",
                    hi: "डीलर के बाद वाला खिलाड़ी पहले कॉल करता है और पहला हाथ शुरू करता है। फिर बारी घड़ी की उल्टी दिशा में चलती है: आपसे आपके दाईं ओर वाले खिलाड़ी तक, फिर सामने वाले, फिर बाईं ओर वाले। जो हाथ जीतता है, वही अगला हाथ शुरू करता है।"
                ),
                note: Localized(
                    en: "The faint arrows printed on the felt show the direction.",
                    ne: "टेबलमा छापिएका मधुरा तीरहरूले दिशा देखाउँछन्।",
                    hi: "टेबल पर बने हल्के तीर दिशा दिखाते हैं।"
                )
            ),
            RulePage(
                title: Localized(
                    en: "Five rounds make a game",
                    ne: "पाँच राउन्डको एक गेम",
                    hi: "पाँच राउंड का एक गेम"
                ),
                body: Localized(
                    en: "Scores add up over 5 rounds, and the highest total wins. Equal totals share the win. Thok can end a game early: see House rules.",
                    ne: "५ राउन्डको अंक जोडिन्छ, र सबैभन्दा धेरै कुल अंक हुनेले जित्छ। सबैभन्दा धेरै अंकमा बराबरी भए ती सबै खेलाडी विजेता हुन्छन्। थोकले गेम चाँडै सक्याउन सक्छ: घरेलु नियम हेर्नुहोस्।",
                    hi: "5 राउंड के स्कोर जुड़ते हैं, और सबसे ज़्यादा कुल स्कोर वाला जीतता है। सबसे ज़्यादा स्कोर पर बराबरी हो तो वे सभी खिलाड़ी विजेता होते हैं। थोक से गेम जल्दी खत्म हो सकता है: घरेलू नियम देखें।"
                )
            ),
        ]),

        RuleTopic(id: "calling", title: Localized(en: "Calling", ne: "कल", hi: "कॉल"), pages: [
            RulePage(
                title: Localized(
                    en: "Call your tricks",
                    ne: "कति हात जित्ने हो, कल गर्नुहोस्",
                    hi: "कितने हाथ जीतेंगे, उसकी कॉल करें"
                ),
                body: Localized(
                    en: "After the deal, each player calls how many tricks they expect to win, from 1 to 13. There is no call of 0. Calls go round in turn, starting after the dealer, and everyone sees each call.",
                    ne: "पत्ती बाँडेपछि हरेक खेलाडीले आफूले जित्न सक्ने हातको सङ्ख्या १ देखि १३ सम्म कल गर्छ। ० कल गर्न पाइँदैन। डिलरपछिको खेलाडीबाट पालैपालो कल हुन्छ, र सबैले हरेक कल देख्छन्।",
                    hi: "पत्ते बँटने के बाद हर खिलाड़ी कॉल करता है कि वह कितने हाथ जीतेगा, 1 से 13 तक। 0 की कॉल नहीं होती। डीलर के बाद वाले खिलाड़ी से बारी-बारी कॉल होती है, और हर कॉल सबको दिखती है।"
                )
            ),
            RulePage(
                title: Localized(
                    en: "Tap a number, then Call",
                    ne: "नम्बर छान्नुहोस्, अनि Call थिच्नुहोस्",
                    hi: "नंबर चुनें, फिर Call दबाएँ"
                ),
                body: Localized(
                    en: "Tap a number to see what it stakes, such as “Make 4 or more: +4 · Miss: −4”, then tap Call. Calls of 8 or more have a gold ring: with Thok on, making one wins the game.",
                    ne: "नम्बर थिच्दा त्यसमा के दाउमा छ भनेर देखिन्छ, जस्तै “Make 4 or more: +4 · Miss: −4”, त्यसपछि Call थिच्नुहोस्। ८ वा बढीको कलमा सुनौलो घेरा हुन्छ: थोक चालु भए त्यो कल पुर्‍याउनेले गेम जित्छ।",
                    hi: "नंबर दबाने पर दिखता है कि दाँव पर क्या है, जैसे “Make 4 or more: +4 · Miss: −4”, फिर Call दबाएँ। 8 या उससे ज़्यादा की कॉल पर सुनहरा घेरा होता है: थोक चालू हो तो वह कॉल पूरी करने वाला गेम जीत जाता है।"
                ),
                note: Localized(
                    en: "Want a hint? Turn on Bid Suggestion in Settings, under Assists.",
                    ne: "सुझाव चाहियो? Settings को Assists मा Bid Suggestion चालु गर्नुहोस्।",
                    hi: "सुझाव चाहिए? Settings में Assists के अंदर Bid Suggestion चालू करें।"
                )
            ),
        ]),

        RuleTopic(id: "playing", title: Localized(en: "Playing", ne: "खेल्ने", hi: "खेलना"), pages: [
            RulePage(
                title: Localized(
                    en: "Follow suit",
                    ne: "उही रङ फाल्नुहोस्",
                    hi: "वही रंग चलें"
                ),
                body: Localized(
                    en: "If you hold the suit that was led, you must play it.",
                    ne: "सुरुमा फालिएको रङ तपाईंसँग छ भने त्यही फाल्नुपर्छ।",
                    hi: "हाथ के पहले पत्ते का रंग आपके पास हो, तो उसी रंग का पत्ता चलना होगा।"
                ),
                diagram: RuleDiagram(
                    table: [DiagramCard(.seven, .diamonds, .led)],
                    choices: [
                        DiagramCard(.queen, .diamonds, .mustPlay, .chosen),
                        DiagramCard(.three, .spades, .notAllowed, .dimmed),
                    ]
                ),
                note: Localized(
                    en: "You can’t trump while you still hold the led suit.",
                    ne: "त्यो रङ हातमा हुँदासम्म हुकुमले काट्न पाइँदैन।",
                    hi: "जब तक वह रंग आपके पास है, हुकुम से नहीं काट सकते।"
                )
            ),
            RulePage(
                title: Localized(
                    en: "Follow suit, and beat it if you can",
                    ne: "उही रङ, र सके ठूलो",
                    hi: "वही रंग, और हो सके तो बड़ा"
                ),
                body: Localized(
                    en: "Until someone plays a Spade, you must also beat the highest card of the led suit whenever you can.",
                    ne: "कसैले हुकुम नफालेसम्म, सकिन्छ भने सुरुको रङको सबैभन्दा ठूलो पत्तीभन्दा ठूलो फाल्नुपर्छ।",
                    hi: "जब तक इस हाथ में हुकुम न खेला गया हो, पहले पत्ते के रंग में अब तक खेले गए सबसे बड़े पत्ते से बड़ा पत्ता आपके पास हो, तो उसे चलना ज़रूरी है।"
                ),
                diagram: RuleDiagram(
                    table: [
                        DiagramCard(.nine, .hearts, .led),
                        DiagramCard(.king, .hearts, .winning, .ringed),
                    ],
                    choices: [
                        DiagramCard(.five, .hearts, .tooLow, .dimmed),
                        DiagramCard(.queen, .hearts, .tooLow, .dimmed),
                        DiagramCard(.ace, .hearts, .mustPlay, .chosen),
                    ]
                ),
                note: Localized(
                    en: "Once a Spade is winning, any Heart is allowed.",
                    ne: "हुकुमले जितिरहेको छ भने जुनसुकै पान फाल्न पाइन्छ।",
                    hi: "हुकुम जीत रहा हो तो कोई भी पान चल सकते हैं।"
                )
            ),
            RulePage(
                title: Localized(
                    en: "No suit? Play a Spade",
                    ne: "रङ छैन? हुकुम फाल्नुहोस्",
                    hi: "रंग नहीं? हुकुम चलें"
                ),
                body: Localized(
                    en: "If you have none of the led suit but hold a Spade, you must play one, and beat a Spade that is already winning if you can. If you can’t beat it, Free Discard (on by default) lets you play any card.",
                    ne: "सुरुमा फालिएको रङ छैन तर हुकुम छ भने हुकुम फाल्नुपर्छ। हुकुमले हात जितिरहेको छ र तपाईंसँग त्योभन्दा ठूलो हुकुम छ भने ठूलो हुकुम फाल्नैपर्छ। काट्न सकिँदैन भने फ्री डिस्कार्ड (पहिलेबाटै चालु) ले जुनसुकै पत्ती फाल्न दिन्छ।",
                    hi: "हाथ के पहले पत्ते का रंग आपके पास नहीं है, लेकिन हुकुम है, तो हुकुम चलना होगा। अगर हुकुम पहले से जीत रहा है और आपके पास उससे बड़ा हुकुम है, तो बड़ा हुकुम चलना ज़रूरी है। न काट सकें, तो फ्री डिस्कार्ड (पहले से चालू) से कोई भी पत्ता चल सकते हैं।"
                ),
                diagram: RuleDiagram(
                    table: [
                        DiagramCard(.ten, .clubs, .led),
                        DiagramCard(.six, .spades, .winning, .ringed),
                    ],
                    choices: [
                        DiagramCard(.nine, .spades, .mustPlay, .chosen),
                        DiagramCard(.four, .spades, .tooLow, .dimmed),
                        DiagramCard(.king, .hearts, .notAllowed, .dimmed),
                    ]
                ),
                note: Localized(
                    en: "With no Spade either, play any card.",
                    ne: "हुकुम पनि छैन भने जुनसुकै पत्ती फाल्न पाइन्छ।",
                    hi: "हुकुम भी नहीं है तो कोई भी पत्ता चल सकते हैं।"
                )
            ),
            RulePage(
                title: Localized(
                    en: "Who takes the trick",
                    ne: "हात कसले जित्छ",
                    hi: "हाथ कौन जीतता है"
                ),
                body: Localized(
                    en: "The highest Spade wins. With no Spade played, the highest card of the led suit wins. Other suits never win, however high.",
                    ne: "सबैभन्दा ठूलो हुकुमले हात जित्छ। हुकुम नफालिएको भए सुरुमा फालिएको रङको सबैभन्दा ठूलो पत्तीले जित्छ। अरू रङका पत्ती जति ठूला भए पनि जित्दैनन्।",
                    hi: "सबसे बड़ा हुकुम हाथ जीतता है। हुकुम न खेला गया हो तो हाथ के पहले पत्ते के रंग का सबसे बड़ा पत्ता जीतता है। दूसरे रंगों के पत्ते कितने भी बड़े हों, नहीं जीतते।"
                ),
                diagram: RuleDiagram(table: [
                    DiagramCard(.jack, .diamonds, .led),
                    DiagramCard(.ace, .clubs, .cantWin),
                    DiagramCard(.queen, .diamonds, .wins, .ringed),
                    DiagramCard(.three, .diamonds),
                ])
            ),
        ]),

        RuleTopic(id: "scoring", title: Localized(en: "Scoring", ne: "अंक", hi: "स्कोर"), pages: [
            RulePage(
                title: Localized(
                    en: "Make your call",
                    ne: "कल पुर्‍याउनुहोस्",
                    hi: "अपनी कॉल पूरी करें"
                ),
                body: Localized(
                    en: "Win at least as many tricks as you called and you score your call. Each extra trick adds 0.1.",
                    ne: "कल गरेजति वा त्योभन्दा बढी हात जिते कल बराबर अंक पाइन्छ। हरेक थप हातको ०.१ अंक पाइन्छ।",
                    hi: "जितने हाथों की कॉल की थी, उतने या उससे ज़्यादा हाथ जीतने पर कॉल के बराबर अंक मिलते हैं। हर अतिरिक्त हाथ पर 0.1 अंक और मिलता है।"
                ),
                note: Localized(
                    en: "Call 4, win 4: +4 · Call 4, win 6: +4.2",
                    ne: "कल ४, जितेका हात ४: +४ · कल ४, जितेका हात ६: +४.२",
                    hi: "कॉल 4, जीते 4: +4 · कॉल 4, जीते 6: +4.2"
                )
            ),
            RulePage(
                title: Localized(
                    en: "Miss it and lose it",
                    ne: "कल नपुगे घट्छ",
                    hi: "कॉल पूरी न हुई तो अंक कटेंगे"
                ),
                body: Localized(
                    en: "Win fewer tricks than you called and you lose your call.",
                    ne: "कल गरेभन्दा कम हात जिते कल बराबरको अंक घट्छ।",
                    hi: "कॉल से कम हाथ जीते तो कॉल जितने अंक कटते हैं।"
                ),
                note: Localized(
                    en: "Call 5, win 4: −5",
                    ne: "कल ५, जितेका हात ४: −५",
                    hi: "कॉल 5, जीते 4: −5"
                )
            ),
        ]),

        RuleTopic(id: "houseRules", title: Localized(en: "House rules", ne: "घरेलु नियम", hi: "घरेलू नियम"), pages: [
            RulePage(
                title: Localized(en: "Thok", ne: "थोक", hi: "थोक"),
                body: Localized(
                    en: "Call 8 or more and make it, and you win the game on the spot. A bot can do it too. It’s on unless you turn it off.",
                    ne: "८ वा बढी कल गरेर पुर्‍याए तुरुन्तै गेम जितिन्छ। बोटले पनि यसो गर्न सक्छ। यो नियम पहिलेबाटै चालु हुन्छ; चाहनुहुन्छ भने बन्द गर्न सक्नुहुन्छ।",
                    hi: "8 या उससे ज़्यादा हाथों की कॉल करें और उसे पूरा करें, तो तुरंत गेम जीत जाते हैं। बॉट भी ऐसा कर सकते हैं। यह नियम पहले से चालू होता है; चाहें तो इसे बंद कर सकते हैं।"
                ),
                note: Localized(
                    en: "Change house rules in Settings. They apply from your next game.",
                    ne: "घरेलु नियम Settings मा बदल्नुहोस्। ती अर्को गेमदेखि लागू हुन्छन्।",
                    hi: "घरेलू नियम Settings में बदलें। ये अगले गेम से लागू होते हैं।"
                )
            ),
            RulePage(
                title: Localized(en: "Free Discard", ne: "फ्री डिस्कार्ड", hi: "फ्री डिस्कार्ड"),
                body: Localized(
                    en: "If you have none of the led suit, a Spade is winning, and you can’t beat it, you may play any card instead of a lower Spade. On by default.",
                    ne: "सुरुको रङ छैन, हुकुमले जितिरहेको छ, र तपाईं त्योभन्दा ठूलो हुकुम फाल्न सक्नुहुन्न भने सानो हुकुमको सट्टा जुनसुकै पत्ती फाल्न पाइन्छ। यो नियम पहिलेबाटै चालु हुन्छ।",
                    hi: "हाथ के पहले पत्ते का रंग आपके पास नहीं है, हुकुम जीत रहा है, और आप उससे बड़ा हुकुम नहीं चल सकते, तो छोटे हुकुम की जगह कोई भी पत्ता चल सकते हैं। यह नियम पहले से चालू होता है।"
                ),
                diagram: RuleDiagram(
                    table: [
                        DiagramCard(.eight, .hearts, .led),
                        DiagramCard(.jack, .spades, .winning, .ringed),
                    ],
                    choices: [
                        DiagramCard(.five, .spades, .mayPlay, .chosen),
                        DiagramCard(.two, .clubs, .mayPlay, .chosen),
                    ]
                ),
                note: Localized(
                    en: "With Free Discard off, you must play the 5♠.",
                    ne: "फ्री डिस्कार्ड बन्द भए ५♠ नै फाल्नुपर्छ।",
                    hi: "फ्री डिस्कार्ड बंद हो तो 5♠ ही चलना होगा।"
                )
            ),
            RulePage(
                title: Localized(en: "Fair Deal", ne: "फेयर डिल", hi: "फेयर डील"),
                body: Localized(
                    en: "If anyone is dealt no Spade, or no Jack, Queen, King or Ace, all the cards are dealt again. On by default.",
                    ne: "कसैलाई एउटा पनि हुकुम परेन, वा गुलाम, बेगम, बादशाह र एक्कामध्ये एउटा पनि परेन भने सबै पत्ती फेरि बाँडिन्छ। यो नियम पहिलेबाटै चालु हुन्छ।",
                    hi: "किसी को एक भी हुकुम न मिले, या गुलाम, बेगम, बादशाह और इक्के में से एक भी पत्ता न मिले, तो सारे पत्ते फिर से बाँटे जाते हैं। शुरू से चालू रहता है।"
                )
            ),
        ]),
    ]
}
