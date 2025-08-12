import SwiftUI

// MARK: - Models

struct CommodityPrice: Identifiable {
    let id = UUID()
    let name: String
    let buyPrice: Int?    // Station buys at this price (you sell)
    let sellPrice: Int?   // Station sells at this price (you buy)
}

struct Station: Identifiable {
    let id = UUID()
    let name: String
    let maxPadSize: Int
    let commodities: [CommodityPrice]
}

struct SystemInfo {
    let name: String
    let economy: String?
    let government: String?
    let security: String?
    let population: Int?
    let coords: (x: Double, y: Double, z: Double)?
    let stations: [Station]
}

struct TradeRecommendation: Identifiable {
    let id = UUID()
    let commodity: String
    let buyStation: String
    let buyPrice: Int
    let sellStation: String
    let sellPrice: Int
    let profitPerUnit: Int
    let totalProfit: Int
}

struct RawBodiesResponse: Codable {
    let id: Int
    let name: String
    let bodies: [Body]
    
    struct Body: Codable, Identifiable {
        let id: Int
        let name: String
        let type: String
        let subType: String?
        let distanceToArrival: Double?
        let isMainStar: Bool?
        let isScoopable: Bool?
        let isLandable: Bool?
        let gravity: Double?
        let earthMasses: Double?
        let radius: Double?
        let surfaceTemperature: Double?
        let volcanismType: String?
        let atmosphereType: String?
        let terraformingState: String?
        let orbitalPeriod: Double?
        let semiMajorAxis: Double?
        let orbitalEccentricity: Double?
        let orbitalInclination: Double?
        let argOfPeriapsis: Double?
        let rotationalPeriod: Double?
        let rotationalPeriodTidallyLocked: Bool?
        let axialTilt: Double?
        let rings: [Ring]?
        
        struct Ring: Codable, Identifiable {
            var id: String { name }
            let name: String
            let type: String
            let mass: Double
            let innerRadius: Double
            let outerRadius: Double
        }
    }
}

// MARK: - View

struct TradeTab: View {
    @State private var systemName: String = ""
    @State private var systemInfo: SystemInfo? = nil
    @State private var systemBodies: [RawBodiesResponse.Body] = []
    @State private var cargoCapacity: Int = 100
    @State private var padSize: Int = 3      // Large pad default (unused now)
    @State private var maxJumpRange: Double = 20
    @State private var recommendations: [TradeRecommendation] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    let highlightColor: Color
    let padSizes = ["Small", "Medium", "Large"]
    
    // MARK: - Computed property to find a suitable planet or moon body
    var planetBody: RawBodiesResponse.Body? {
        // Debug print all bodies for troubleshooting
        for body in systemBodies {
            print("DEBUG: Body name: \(body.name), type: \(body.type), subType: \(body.subType ?? "nil")")
        }
        
        // Find first body matching common planet/moon keywords (expanded)
        return systemBodies.first(where: { body in
            let type = (body.subType ?? body.type).lowercased()
            return type.contains("planet") ||
                   type.contains("moon") ||
                   type.contains("terrestrial") ||
                   type.contains("barren") ||
                   type.contains("water") ||
                   type.contains("ice") ||
                   type.contains("icy") ||
                   type.contains("frozen") ||
                   type.contains("earth-like") ||
                   type.contains("metallic") ||
                   type.contains("ammonia")
        })
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    TextField("Enter System Name", text: $systemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(.horizontal)

                    Button {
                        Task {
                            await loadSystemData()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        } else {
                            Text("Load EDSM System Data")
                                .bold()
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(systemName.isEmpty ? Color.gray : Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(systemName.isEmpty || isLoading)
                    .padding(.horizontal)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    if let info = systemInfo {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("System: \(info.name)")
                                .font(.title2)
                                .bold()
                            HStack { Text("Economy:"); Spacer(); Text(info.economy ?? "Unknown") }
                            HStack { Text("Government:"); Spacer(); Text(info.government ?? "Unknown") }
                            HStack { Text("Security:"); Spacer(); Text(info.security ?? "Unknown") }
                            HStack { Text("Population:"); Spacer(); Text(info.population.map { String($0) } ?? "Unknown") }
                            if let coords = info.coords {
                                HStack {
                                    Text("Coordinates:")
                                    Spacer()
                                    Text(String(format: "%.2f, %.2f, %.2f", coords.x, coords.y, coords.z))
                                }
                            }

                            Divider()

                            Text("System Planet Symbol:")
                                .font(.headline)

                            if let body = planetBody {
                                Image(systemName: sfSymbolName(for: body))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(highlightColor)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                // Fallback sparkle icon if no planet/moon found
                                Image(systemName: "sparkles")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            // Debug info: show how many bodies loaded
                            Text("Loaded bodies: \(systemBodies.count)")
                                .foregroundColor(.secondary)
                                .padding(.bottom)

                            Divider()
                            
                            Text("System Bodies:")
                                .font(.headline)
                            if systemBodies.isEmpty {
                                Text("No body data found.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(systemBodies) { body in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(body.name) – \(body.subType ?? body.type)")
                                            .bold()
                                        if let dist = body.distanceToArrival {
                                            Text("Distance to arrival: \(dist, specifier: "%.0f") ls")
                                        }
                                        if let temp = body.surfaceTemperature {
                                            Text("Temperature: \(temp, specifier: "%.0f") K")
                                        }
                                        if let grav = body.gravity {
                                            Text("Gravity: \(grav, specifier: "%.2f") g")
                                        }
                                        if let rings = body.rings, !rings.isEmpty {
                                            Text("Rings:")
                                                .font(.subheadline)
                                            ForEach(rings) { ring in
                                                Text("\(ring.name) – \(ring.type)")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    if !recommendations.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Trade Recommendations:")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)
                            ForEach(recommendations) { rec in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rec.commodity)
                                        .font(.headline)
                                    Text("Buy at: \(rec.buyStation) for \(rec.buyPrice)")
                                    Text("Sell at: \(rec.sellStation) for \(rec.sellPrice)")
                                    Text("Profit per unit: \(rec.profitPerUnit)")
                                    Text("Total profit: \(rec.totalProfit)")
                                        .bold()
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                            }
                        }
                    } else if !isLoading && systemInfo != nil {
                        Text("No trading info logged for this system.")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .navigationTitle("System")
            }
        }
    }
    
    // MARK: - Helper to map body type to SF Symbol
    
    func sfSymbolName(for body: RawBodiesResponse.Body) -> String {
        let type = (body.subType ?? body.type).lowercased()
        
        if type.contains("earth-like") {
            return "globe.europe.africa.fill"  // Earth-like planet symbol
        }
        
        // For any other planet or moon, use moon symbol
        if type.contains("planet") ||
           type.contains("moon") ||
           type.contains("terrestrial") ||
           type.contains("barren") ||
           type.contains("water") ||
           type.contains("ice") ||
           type.contains("icy") ||
           type.contains("frozen") ||
           type.contains("metallic") ||
           type.contains("ammonia") {
            return "moon.stars.fill"
        }
        
        if type.contains("gas giant") || type.contains("jupiter") || type.contains("neptune") {
            return "circle.hexagongrid.fill"
        }
        if type.contains("star") || type.contains("sun") || type.contains("yellow star") || type.contains("white dwarf") || type.contains("neutron star") || type.contains("black hole") {
            return "sun.max.fill"
        }
        if type.contains("asteroid belt") || type.contains("belt") {
            return "circle.grid.hex"
        }
        if type.contains("ring") {
            return "circle.righthalf.filled"
        }
        if type.contains("comet") {
            return "sparkles"
        }
        if type.contains("nebula") || type.contains("cloud") || type.contains("dust") {
            return "cloud.fill"
        }
        if type.contains("galaxy") {
            return "globe.americas.fill"
        }
        
        return "sparkles" // generic fallback symbol
    }

    // MARK: - Networking & Parsing

    func loadSystemData() async {
        isLoading = true
        errorMessage = nil
        systemInfo = nil
        systemBodies = []
        recommendations = []

        let encodedName = systemName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? systemName
        let urlString = "https://www.edsm.net/api-v1/system?systemName=\(encodedName)&showInformation=1&showCoordinates=1&showStations=1&showPrices=1"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid system name."
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                errorMessage = "Failed to load system data: HTTP \(httpResp.statusCode)"
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            let raw = try decoder.decode(RawSystemResponse.self, from: data)

            let stations = raw.stations?.compactMap { rawStation -> Station? in
                guard let name = rawStation.name,
                      let maxPad = rawStation.maxLandingPadSize else { return nil }

                let commodities = rawStation.commodities?.map { commodity -> CommodityPrice in
                    CommodityPrice(name: commodity.name ?? "Unknown",
                                  buyPrice: commodity.buyPrice,
                                  sellPrice: commodity.sellPrice)
                } ?? []

                return Station(name: name, maxPadSize: maxPad, commodities: commodities)
            } ?? []

            systemInfo = SystemInfo(
                name: raw.name,
                economy: raw.information?.economy,
                government: raw.information?.government,
                security: raw.information?.security,
                population: raw.information?.population.map { Int($0) },
                coords: raw.coords.map { ($0.x, $0.y, $0.z) },
                stations: stations
            )
            
            await loadSystemBodies(systemName: raw.name)
            calculateTradeRecommendations()
        } catch {
            errorMessage = "Error loading system data: \(error.localizedDescription)"
        }

        isLoading = false
    }
    
    func loadSystemBodies(systemName: String) async {
        let encodedName = systemName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? systemName
        let urlString = "https://www.edsm.net/api-system-v1/bodies?systemName=\(encodedName)"
        
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let bodiesResponse = try decoder.decode(RawBodiesResponse.self, from: data)
            
            await MainActor.run {
                systemBodies = bodiesResponse.bodies
            }
        } catch {
            print("Error loading bodies: \(error)")
        }
    }

    // MARK: - Trade Calculations

    func calculateTradeRecommendations() {
        guard let system = systemInfo else { return }
        var recs: [TradeRecommendation] = []

        for buyStation in system.stations {
            for sellStation in system.stations {
                if buyStation.id == sellStation.id { continue }

                for buyCommodity in buyStation.commodities {
                    guard let buyPrice = buyCommodity.sellPrice, buyPrice > 0 else { continue }

                    for sellCommodity in sellStation.commodities {
                        guard let sellPrice = sellCommodity.buyPrice, sellPrice > 0 else { continue }

                        if buyCommodity.name == sellCommodity.name && sellPrice > buyPrice {
                            let profitPerUnit = sellPrice - buyPrice
                            let totalProfit = profitPerUnit * cargoCapacity

                            recs.append(TradeRecommendation(
                                commodity: buyCommodity.name,
                                buyStation: buyStation.name,
                                buyPrice: buyPrice,
                                sellStation: sellStation.name,
                                sellPrice: sellPrice,
                                profitPerUnit: profitPerUnit,
                                totalProfit: totalProfit
                            ))
                        }
                    }
                }
            }
        }
        recommendations = recs.sorted(by: { $0.totalProfit > $1.totalProfit })
    }
}

// MARK: - Raw API Response Structs

struct RawSystemResponse: Codable {
    struct Coords: Codable {
        let x: Double
        let y: Double
        let z: Double
    }

    struct Information: Codable {
        let allegiance: String?
        let government: String?
        let faction: String?
        let factionState: String?
        let population: Int64?
        let security: String?
        let economy: String?
        let secondEconomy: String?
        let reserve: String?
    }

    struct RawCommodity: Codable {
        let name: String?
        let buyPrice: Int?
        let sellPrice: Int?
    }

    struct RawStation: Codable {
        let name: String?
        let maxLandingPadSize: Int?
        let commodities: [RawCommodity]?
    }

    let name: String
    let coords: Coords?
    let coordsLocked: Bool?
    let information: Information?
    let stations: [RawStation]?
}
