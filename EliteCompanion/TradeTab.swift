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

// MARK: - View

struct TradingTab: View {
    @State private var systemName: String = ""
    @State private var systemInfo: SystemInfo? = nil
    @State private var cargoCapacity: Int = 100
    @State private var padSize: Int = 3      // Large pad default (unused now)
    @State private var maxJumpRange: Double = 20
    @State private var recommendations: [TradeRecommendation] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    let highlightColor: Color


    let padSizes = ["Small", "Medium", "Large"]

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
                            Text("Load System & Calculate Trades")
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
                            HStack {
                                Text("Economy:")
                                Spacer()
                                Text(info.economy ?? "Unknown")
                            }
                            HStack {
                                Text("Government:")
                                Spacer()
                                Text(info.government ?? "Unknown")
                            }
                            HStack {
                                Text("Security:")
                                Spacer()
                                Text(info.security ?? "Unknown")
                            }
                            HStack {
                                Text("Population:")
                                Spacer()
                                Text(info.population.map { String($0) } ?? "Unknown")
                            }
                            if let coords = info.coords {
                                HStack {
                                    Text("Coordinates:")
                                    Spacer()
                                    Text(String(format: "%.2f, %.2f, %.2f", coords.x, coords.y, coords.z))
                                }
                            }

                            Divider()

                            Text("Stations:")
                                .font(.headline)
                            if info.stations.isEmpty {
                                Text("No additional User Data found.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(info.stations) { station in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(station.name) (Pad size: \(padSizes[station.maxPadSize - 1]))")
                                            .bold()
                                        ForEach(station.commodities) { commodity in
                                            HStack {
                                                Text(commodity.name)
                                                Spacer()
                                                Text("Buy: \(commodity.sellPrice ?? 0)")
                                                Text("Sell: \(commodity.buyPrice ?? 0)")
                                            }
                                            .font(.caption)
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

    // MARK: - Networking & Parsing

    func loadSystemData() async {
        isLoading = true
        errorMessage = nil
        systemInfo = nil
        recommendations = []

        let encodedName = systemName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? systemName
        let urlString = "https://www.edsm.net/api-v1/system?systemName=\(encodedName)&showInformation=1&showCoordinates=1&showStations=1&showPrices=1"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid system name."
            isLoading = false
            return
        }

        print("Fetching data from URL: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResp = response as? HTTPURLResponse {
                print("HTTP Status code: \(httpResp.statusCode)")
                guard httpResp.statusCode == 200 else {
                    errorMessage = "Failed to load system data: HTTP \(httpResp.statusCode)"
                    isLoading = false
                    return
                }
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON response:\n\(jsonString)")
            }

            let decoder = JSONDecoder()
            let raw = try decoder.decode(RawSystemResponse.self, from: data)

            print("Decoded system name: \(raw.name)")
            print("Economy: \(raw.information?.economy ?? "nil")")
            print("Government: \(raw.information?.government ?? "nil")")
            print("Security: \(raw.information?.security ?? "nil")")
            print("Population: \(raw.information?.population ?? -1)")
            if let coords = raw.coords {
                print("Coordinates: \(coords.x), \(coords.y), \(coords.z)")
            } else {
                print("Coordinates: nil")
            }
            if let stations = raw.stations {
                print("Stations count: \(stations.count)")
                for station in stations {
                    print("Station: \(station.name ?? "nil"), pad size: \(station.maxLandingPadSize ?? -1)")
                    if let commodities = station.commodities {
                        print(" Commodities count: \(commodities.count)")
                    } else {
                        print(" Commodities: nil")
                    }
                }
            } else {
                print("Stations: nil")
            }

            // RELAXED: No pad size filter — take all stations
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

            print("Filtered stations count: \(stations.count)")

            calculateTradeRecommendations()
        } catch {
            print("Decoding or fetch error: \(error)")
            errorMessage = "Error loading system data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Trade Calculations

    func calculateTradeRecommendations() {
        guard let system = systemInfo else { return }
        var recs: [TradeRecommendation] = []

        // DEBUG: Print all commodity prices per station
        for station in system.stations {
            print("Station: \(station.name), pad size: \(station.maxPadSize)")
            for commodity in station.commodities {
                print(" - Commodity: \(commodity.name), buyPrice: \(commodity.buyPrice ?? -1), sellPrice: \(commodity.sellPrice ?? -1)")
            }
        }

        for buyStation in system.stations {
            for sellStation in system.stations {
                if buyStation.id == sellStation.id { continue }

                for buyCommodity in buyStation.commodities {
                    guard let buyPrice = buyCommodity.sellPrice, buyPrice > 0 else { continue }

                    for sellCommodity in sellStation.commodities {
                        guard let sellPrice = sellCommodity.buyPrice, sellPrice > 0 else { continue }

                        if buyCommodity.name == sellCommodity.name && sellPrice > buyPrice {
                            print("Found profitable trade: \(buyCommodity.name) buy at \(buyPrice) (\(buyStation.name)) sell at \(sellPrice) (\(sellStation.name))")

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
