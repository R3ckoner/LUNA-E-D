import SwiftUI

// MARK: - Model

struct GalnetArticle: Identifiable {
    let id = UUID()
    let title: String
    let link: String
    var rawHTML: String? = nil
}

// MARK: - Main View

struct GalnetTab: View {
    @State private var articles: [GalnetArticle] = []
    @State private var selectedArticle: GalnetArticle? = nil
    @State private var showSheet = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            List(articles) { article in
                Button {
                    Task {
                        await fetchArticleHTML(article)
                    }
                } label: {
                    Text(article.title)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("Galnet News")
            .task {
                await fetchGalnetNews()
            }

            .sheet(isPresented: $showSheet) {
                if let article = selectedArticle {
                    ScrollView {
                        Text(article.rawHTML ?? "No content")
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    .navigationTitle(article.title)
                }
            }
        }
    }

    @MainActor
    func fetchGalnetNews() async {
        guard let url = URL(string: "https://community.elitedangerous.com/galnet-rss") else {
            errorMessage = "Invalid RSS feed URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = XMLParser(data: data)
            let delegate = RSSParserDelegate()
            parser.delegate = delegate

            if parser.parse() {
                articles = delegate.articles
            } else {
                errorMessage = "Failed to parse RSS feed"
            }
        } catch {
            errorMessage = "Error fetching RSS: \(error.localizedDescription)"
        }
    }

    @MainActor
    func fetchArticleHTML(_ article: GalnetArticle) async {
        let cleanLink = article.link.htmlDecoded().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanLink) else {
            errorMessage = "Invalid article URL"
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let rawHTML = String(data: data, encoding: .utf8) ?? "Unable to load content."

            if let idx = articles.firstIndex(where: { $0.id == article.id }) {
                articles[idx].rawHTML = rawHTML
                selectedArticle = articles[idx]
                showSheet = true
            }
        } catch {
            errorMessage = "Failed to load article: \(error.localizedDescription)"
        }
    }
}

// MARK: - RSS XML Parsing Delegate

class RSSParserDelegate: NSObject, XMLParserDelegate {
    var articles: [GalnetArticle] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var insideItem = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines).htmlDecoded()

            if !title.isEmpty && !link.isEmpty {
                articles.append(GalnetArticle(title: title, link: link))
            }
            insideItem = false
        }
        currentElement = ""
    }
}

// MARK: - String HTML decoding extension

extension String {
    func htmlDecoded() -> String {
        let data = Data(self.utf8)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return self
    }
}
