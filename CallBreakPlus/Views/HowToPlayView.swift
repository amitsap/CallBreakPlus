import SwiftUI

/// How to play: topics in a sidebar, one illustrated rule per page, in English, Nepali or Hindi.
struct HowToPlayView: View {
    @AppStorage("rules.language") private var languageRaw = RulesLanguage.english.rawValue
    @State private var topicIndex = 0
    @State private var pageIndex = 0

    private let topics = RulesText.topics

    private var language: RulesLanguage { RulesLanguage(rawValue: languageRaw) ?? .english }
    private var topic: RuleTopic { topics[topicIndex] }
    private var page: RulePage { topic.pages[pageIndex] }

    var body: some View {
        PanelSidebarLayout(
            title: RulesText.title[language],
            sections: topics.map { $0.title[language] },
            selection: Binding(get: { topicIndex }, set: { topicIndex = $0; pageIndex = 0 })
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    text("\(topic.title[language]) · \(RulesText.position(pageIndex + 1, of: topic.pages.count, in: language))")
                        .font(TableType.kicker)
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(TablePalette.faded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Picker("Language", selection: $languageRaw) {
                        ForEach(RulesLanguage.allCases, id: \.rawValue) { language in
                            Text(language.name)
                                .accessibilityLabel(language.accessibilityName)
                                .tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
                .padding(.trailing, 44)
                .padding(.top, 14)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        text(page.title[language])
                            .font(TableType.title)
                            .foregroundStyle(TablePalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        text(page.body[language])
                            .font(TableType.body)
                            .foregroundStyle(TablePalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if page.diagram != nil || page.note != nil {
                            diagramBox
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                .id("\(topicIndex).\(pageIndex)")

                pageControls
            }
            .padding(.horizontal, 20)
        }
    }

    private var diagramBox: some View {
        VStack(spacing: 8) {
            if let diagram = page.diagram {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(diagram.table.indices, id: \.self) { cell(diagram.table[$0]) }
                    if !diagram.choices.isEmpty {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(TablePalette.faded)
                            .frame(height: CardView.height * Self.cardScale)
                            .padding(.horizontal, 6)
                            .accessibilityHidden(true)
                        ForEach(diagram.choices.indices, id: \.self) { cell(diagram.choices[$0]) }
                    }
                }
            }
            if let note = page.note {
                text(note[language])
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TablePalette.faded)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private static let cardScale: CGFloat = 0.6

    private func cell(_ item: DiagramCard) -> some View {
        VStack(spacing: 4) {
            CardView(card: item.card)
                .scaleEffect(Self.cardScale)
                .frame(width: CardView.width * Self.cardScale, height: CardView.height * Self.cardScale)
                .overlay {
                    switch item.mark {
                    case .ringed:
                        RoundedRectangle(cornerRadius: 5).strokeBorder(TablePalette.gold, lineWidth: 2.5)
                    case .chosen:
                        RoundedRectangle(cornerRadius: 5).strokeBorder(TablePalette.accentGreen, lineWidth: 2.5)
                    case .plain, .dimmed:
                        EmptyView()
                    }
                }
                .opacity(item.mark == .dimmed ? 0.45 : 1)
            if let label = item.label {
                text(label.text[language])
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(labelColor(item.mark))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 58)
        .accessibilityElement(children: .combine)
    }

    private func labelColor(_ mark: DiagramCard.Mark) -> Color {
        switch mark {
        case .chosen: TablePalette.paperGreen
        case .ringed: TablePalette.paperGold
        case .plain, .dimmed: TablePalette.faded
        }
    }

    private var pageControls: some View {
        let isFirst = topicIndex == 0 && pageIndex == 0
        let isLast = topicIndex == topics.count - 1 && pageIndex == topic.pages.count - 1
        return HStack {
            Button { step(by: -1) } label: {
                Label { text(RulesText.previous[language]) } icon: { Image(systemName: "chevron.left") }
            }
            .disabled(isFirst)
            Spacer()
            Button { step(by: 1) } label: {
                HStack(spacing: 6) {
                    text(RulesText.next[language])
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(isLast)
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(TablePalette.paperGreen)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .padding(.bottom, 4)
    }

    /// Moves one page, crossing into the next or previous topic at its ends.
    private func step(by delta: Int) {
        if delta > 0 {
            if pageIndex < topic.pages.count - 1 {
                pageIndex += 1
            } else if topicIndex < topics.count - 1 {
                topicIndex += 1
                pageIndex = 0
            }
        } else {
            if pageIndex > 0 {
                pageIndex -= 1
            } else if topicIndex > 0 {
                topicIndex -= 1
                pageIndex = topics[topicIndex].pages.count - 1
            }
        }
    }

    /// Text tagged with the rules language, so VoiceOver reads it in the right voice.
    private func text(_ string: String) -> Text {
        var attributed = AttributedString(string)
        attributed.languageIdentifier = language.locale.identifier
        return Text(attributed)
    }
}
