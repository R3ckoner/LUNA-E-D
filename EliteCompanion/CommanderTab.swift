import SwiftUI
import PhotosUI
import Combine
import Foundation

// MARK: - CommanderData model + API response structs
struct CommanderData {
    var commanderName: String
    var credits: Int?
    var ranksVerbose: [String: String] = [:]
    var ranks: [String: Int] = [:]
    var progress: [String: Int] = [:]
}

struct EDSMCreditsResponse: Codable {
    struct Credit: Codable {
        let balance: Int
        let date: String?
        let loan: Int?
    }
    let msg: String
    let msgnum: Int
    let credits: [Credit]?
}

struct EDSMRanksResponse: Codable {
    let msgnum: Int
    let msg: String
    let ranksVerbose: [String: String]
    let ranks: [String: Int]
    let progress: [String: Int]
}

// MARK: - Position API models (from example JSON)
struct PositionCoordinates: Codable {
    let x: Double
    let y: Double
    let z: Double
}

struct PositionResponse: Codable {
    let msgnum: Int?
    let msg: String?
    let system: String?
    let systemId: Int?
    let firstDiscover: Bool?
    let date: String?
    let coordinates: PositionCoordinates?
    let url: String?
}

// MARK: - Position ViewModel
class PositionViewModel: ObservableObject {
    @Published var position: PositionResponse?
    @Published var errorMessage: String?

    private var task: URLSessionDataTask?

    /// Fetch position from EDSM endpoint. Uses commanderName & apiKey as query params if provided.
    func fetchPosition(commanderName: String, apiKey: String, completion: @escaping () -> Void = {}) {
        // Build URL with query items for commanderName and apiKey
        var components = URLComponents(string: "https://www.edsm.net/api-logs-v1/get-position")
        var queryItems: [URLQueryItem] = []
        if !commanderName.isEmpty {
            queryItems.append(URLQueryItem(name: "commanderName", value: commanderName))
        }
        if !apiKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apiKey", value: apiKey))
        }
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL for position request"
                completion()
            }
            return
        }

        task?.cancel()
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { completion() } }
            guard let self = self else { return }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                // cancelled, don't set error
                return
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(PositionResponse.self, from: data)
                DispatchQueue.main.async {
                    self.position = decoded
                    self.errorMessage = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Decode error: \(error.localizedDescription)"
                }
            }
        }

        task?.resume()
    }
}

// MARK: - GalNet RSS feed fetcher
class GalNetFeedFetcher: NSObject, ObservableObject, XMLParserDelegate {
    @Published var latestHeadline: String = "Loading..."

    private var currentElement = ""
    private var foundTitle = ""
    private var isParsingItem = false
    private var didFindFirstItem = false

    func fetchLatestHeadline() {
        guard let url = URL(string: "https://community.elitedangerous.com/galnet-rss") else {
            latestHeadline = "Invalid RSS URL"
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.latestHeadline = "Error: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.latestHeadline = "No data received"
                }
                return
            }

            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }

        task.resume()
    }

    // MARK: - XMLParserDelegate methods

    func parserDidStartDocument(_ parser: XMLParser) {
        foundTitle = ""
        currentElement = ""
        isParsingItem = false
        didFindFirstItem = false
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isParsingItem = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isParsingItem && currentElement == "title" && !didFindFirstItem {
            foundTitle += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "title" && isParsingItem && !didFindFirstItem {
            let trimmed = foundTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.latestHeadline = trimmed
            }
            didFindFirstItem = true
        }

        if elementName == "item" {
            isParsingItem = false
            foundTitle = ""
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        DispatchQueue.main.async {
            self.latestHeadline = "Parse error: \(parseError.localizedDescription)"
        }
    }
}

// MARK: - CommanderTab View
struct CommanderTab: View {
    let highlightColor: Color

    @AppStorage("edsmApiKey") private var inputApiKey: String = "5b240235cabb715584260738bdea667a313eb89d"
    @State private var inputCommanderName: String = "R3ckoner"
    @State private var commander = CommanderData(commanderName: "Loading...", credits: nil)
    @State private var isLoading = false

    @State private var profileImage: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var remoteProfilePicURL: URL? = nil

    @State private var showVerboseRanks = true

    @StateObject private var galNetFetcher = GalNetFeedFetcher()
    @StateObject private var positionVM = PositionViewModel()

    private let profilePicFileName = "profile_pic.png"

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func profilePicURL() -> URL {
        getDocumentsDirectory().appendingPathComponent(profilePicFileName)
    }

    private func saveProfileImage(_ image: UIImage) {
        if let data = image.pngData() {
            do {
                try data.write(to: profilePicURL())
                print("Profile pic saved")
            } catch {
                print("Error saving profile pic:", error)
            }
        }
    }

    private func loadProfileImage() -> UIImage? {
        let url = profilePicURL()
        if FileManager.default.fileExists(atPath: url.path) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 40) {
                    // --- Faction Ranks Row ---
                    HStack(spacing: 40) {
                        ForEach(["Alliance", "Federation", "Empire"], id: \.self) { faction in
                            VStack {
                                Image(faction)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .padding(10)
                                    .background(highlightColor)
                                    .cornerRadius(12)
                                    .shadow(color: highlightColor.opacity(0.4), radius: 6, x: 0, y: 4)

                                Text(commander.ranksVerbose[faction] ?? "N/A")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(highlightColor)

                                // Progress percent
                                if let progress = commander.progress[faction] {
                                    Text("\(progress)% to next")
                                        .font(.caption2)
                                        .foregroundColor(highlightColor.opacity(0.75))
                                } else {
                                    Text("No progress")
                                        .font(.caption2)
                                        .foregroundColor(highlightColor.opacity(0.5))
                                }
                            }
                            .frame(width: 80)
                        }
                    }
                    .padding(.horizontal)

                    // --- Wide GalNet Headline Box ---
                    Button(action: {
                        if let url = URL(string: "https://community.elitedangerous.com/galnet") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image("GalNet")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .padding(.leading, 16)

                            Text(galNetFetcher.latestHeadline)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .padding(.trailing, 16)

                            Spacer()
                        }
                        .frame(height: 100)
                        .background(highlightColor)
                        .cornerRadius(16)
                        .shadow(color: highlightColor.opacity(0.5), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Commander name display
                    Text(commander.commanderName)
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(highlightColor)

                    // Commander name input and load button
                    HStack {
                        TextField("Enter Commander Name", text: $inputCommanderName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        Button(action: loadCommanderData) {
                            Text(isLoading ? "Loading..." : "Load")
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isLoading ? Color.gray : highlightColor)
                                .cornerRadius(8)
                        }
                        .disabled(inputCommanderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    }
                    .padding(.horizontal)

                    // Profile picture picker
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        if let localImage = profileImage {
                            Image(uiImage: localImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(highlightColor, lineWidth: 4))
                                .shadow(radius: 7)
                        } else if let url = remoteProfilePicURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 140, height: 140)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 140, height: 140)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(highlightColor, lineWidth: 4))
                                        .shadow(radius: 7)
                                case .failure(_):
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 140, height: 140)
                                        .foregroundColor(highlightColor)
                                        .opacity(0.6)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 140, height: 140)
                                .foregroundColor(highlightColor)
                                .opacity(0.6)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showingImagePicker) {
                        ImagePicker(image: $profileImage)
                    }
                    .onChange(of: profileImage) { newImage in
                        guard let img = newImage else { return }
                        saveProfileImage(img)
                    }
                    .onAppear {
                        if profileImage == nil {
                            profileImage = loadProfileImage()
                        }
                        remoteProfilePicURL = URL(string: "https://images.edsm.net/cmdr/\(commander.commanderName).jpg")
                    }

                    // Credits section
                    infoSection(title: "Credits") {
                        HStack {
                            Text("Credits")
                            Spacer()
                            if let credits = commander.credits {
                                Text("\(credits.formatted())")
                                    .foregroundColor(.green)
                                    .bold()
                            } else {
                                Text("N/A")
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    // New: Position section (second box under commander info)
                    infoSection(title: "Position") {
                        if let pos = positionVM.position {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("System")
                                    Spacer()
                                    Text(pos.system ?? "Unknown")
                                        .fontWeight(.semibold)
                                }

                                if let systemId = pos.systemId {
                                    HStack {
                                        Text("System ID")
                                        Spacer()
                                        Text("\(systemId)")
                                    }
                                }

                                if let date = pos.date {
                                    HStack {
                                        Text("Date")
                                        Spacer()
                                        Text(date)
                                    }
                                }

                                HStack {
                                    Text("First Discover")
                                    Spacer()
                                    Text((pos.firstDiscover ?? false) ? "Yes" : "No")
                                }

                                if let coords = pos.coordinates {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Coordinates:")
                                            .fontWeight(.semibold)
                                        Text("x: \(String(format: "%.2f", coords.x))")
                                        Text("y: \(String(format: "%.2f", coords.y))")
                                        Text("z: \(String(format: "%.2f", coords.z))")
                                    }
                                }

                                if let urlString = pos.url, let url = URL(string: urlString) {
                                    Link("View profile on EDSM", destination: url)
                                        .font(.footnote)
                                        .padding(.top, 6)
                                }
                            }
                            .font(.subheadline)
                        } else if let error = positionVM.errorMessage {
                            Text("Error loading position: \(error)")
                                .foregroundColor(.red)
                        } else if isLoading {
                            Text("Loading position data...")
                                .foregroundColor(.gray)
                        } else {
                            Text("No position data loaded")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Ranks section with toggle button (numeric / verbose)
                    infoSection(title: "Ranks") {
                        Button(action: { showVerboseRanks.toggle() }) {
                            Text("Show \(showVerboseRanks ? "Numeric" : "Verbose") Ranks")
                                .font(.subheadline)
                                .foregroundColor(highlightColor)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(highlightColor.opacity(0.1))
                                .cornerRadius(8)
                        }

                        if showVerboseRanks {
                            ForEach(commander.ranksVerbose.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                    Spacer()
                                    Text(value)
                                }
                            }
                        } else {
                            ForEach(commander.ranks.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                    Spacer()
                                    Text("\(value)")
                                }
                            }
                        }
                    }

                    // Progress section with progress bars
                    infoSection(title: "Progress") {
                        ForEach(commander.progress.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(key)
                                    Spacer()
                                    Text("\(value)%")
                                }
                                ProgressView(value: Double(value), total: 100)
                                    .accentColor(highlightColor)
                            }
                        }
                    }

                    // MARK: - API Key input at bottom with explanation and link
                    VStack(alignment: .leading, spacing: 6) {
                        Text("You need an EDSM API Key to load your commander data. You can create or find your API key on the EDSM website.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Link("Get your EDSM API Key here", destination: URL(string: "https://www.edsm.net/en/account/edit")!)
                            .font(.footnote)
                            .foregroundColor(highlightColor)
                            .padding(.horizontal)

                        HStack {
                            TextField("Enter EDSM API Key", text: $inputApiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)

                            Button(action: loadCommanderData) {
                                Text(isLoading ? "Loading..." : "Load")
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isLoading ? Color.gray : highlightColor)
                                    .cornerRadius(8)
                            }
                            .disabled(inputApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Commander Profile")
            .onAppear {
                loadCommanderData()
                galNetFetcher.fetchLatestHeadline()
            }
        }
    }

    @ViewBuilder
    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(highlightColor)
                .padding(.bottom, 6)
            VStack(spacing: 10) {
                content()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: highlightColor.opacity(0.15), radius: 6, x: 0, y: 4)
        }
        .padding(.horizontal)
    }

    func loadCommanderData() {
        let trimmedName = inputCommanderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = inputApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedKey.isEmpty else { return }

        isLoading = true
        commander = CommanderData(commanderName: "Loading...", credits: nil)

        let group = DispatchGroup()

        group.enter()
        loadCommanderCredits(commanderName: trimmedName, apiKey: trimmedKey) {
            group.leave()
        }

        group.enter()
        loadCommanderRanks(commanderName: trimmedName, apiKey: trimmedKey) {
            group.leave()
        }

        // Fetch position as part of the group so the UI knows when loading is done
        group.enter()
        positionVM.fetchPosition(commanderName: trimmedName, apiKey: trimmedKey) {
            group.leave()
        }

        group.notify(queue: .main) {
            isLoading = false
            remoteProfilePicURL = URL(string: "https://images.edsm.net/cmdr/\(commander.commanderName).jpg")
        }
    }

    func loadCommanderCredits(commanderName: String, apiKey: String, completion: @escaping () -> Void) {
        let urlString = "https://www.edsm.net/api-commander-v1/get-credits?commanderName=\(commanderName)&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            defer { completion() }
            guard let data = data, error == nil else { return }
            do {
                let decoded = try JSONDecoder().decode(EDSMCreditsResponse.self, from: data)
                DispatchQueue.main.async {
                    commander.commanderName = commanderName
                    commander.credits = decoded.credits?.first?.balance
                }
            } catch {
                print("Credits decode error:", error)
            }
        }.resume()
    }

    func loadCommanderRanks(commanderName: String, apiKey: String, completion: @escaping () -> Void) {
        let urlString = "https://www.edsm.net/api-commander-v1/get-ranks?commanderName=\(commanderName)&apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            completion()
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            defer { completion() }
            guard let data = data, error == nil else { return }
            do {
                let decoded = try JSONDecoder().decode(EDSMRanksResponse.self, from: data)
                DispatchQueue.main.async {
                    commander.ranksVerbose = decoded.ranksVerbose
                    commander.ranks = decoded.ranks
                    commander.progress = decoded.progress
                }
            } catch {
                print("Ranks decode error:", error)
            }
        }.resume()
    }
}

// MARK: - ImagePicker (PHPicker)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}
