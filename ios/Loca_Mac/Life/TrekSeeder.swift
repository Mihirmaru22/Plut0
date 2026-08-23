import SwiftData
import Foundation

// MARK: - TrekSeeder

/// Pre-populates Pluto's Trek & Mountain Atlas with comprehensive Indian mountain peaks,
/// covering every major summit, hill fort, and sacred mountain across Gujarat, Maharashtra,
/// Rajasthan, the Great Himalayas, Western Ghats, and iconic Seven Summits.
enum TrekSeeder {

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<TrekRecord>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map(\.name))

        var insertedCount = 0
        for trek in initialTreks {
            if !existingNames.contains(trek.name) {
                context.insert(trek)
                insertedCount += 1
            }
        }

        if insertedCount > 0 {
            try? context.save()
        }
    }

    @MainActor
    static func resetAllTreks(context: ModelContext) {
        let descriptor = FetchDescriptor<TrekRecord>()
        if let existing = try? context.fetch(descriptor) {
            for trek in existing {
                trek.status = .wishlist
                trek.dateConquered = nil
                trek.rating = 0
            }
            try? context.save()
        }
    }

    @MainActor
    static func reseedAllTreks(context: ModelContext) {
        let descriptor = FetchDescriptor<TrekRecord>()
        if let existing = try? context.fetch(descriptor) {
            for trek in existing {
                context.delete(trek)
            }
            try? context.save()
        }
        for trek in initialTreks {
            context.insert(trek)
        }
        try? context.save()
    }

    static let initialTreks: [TrekRecord] = [

        // =========================================================================
        // 🦁 1. GUJARAT MOUNTAINS & SACRED HILL FORTS
        // =========================================================================

        TrekRecord(
            name: "Girnar Peak (Gorakhnath)",
            region: "Junagadh, Gujarat",
            country: "India",
            latitude: 21.5280,
            longitude: 70.5280,
            elevationMeters: 1069,
            trailDistanceKm: 12.0,
            elevationGainMeters: 900,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            rating: 5,
            personalNotes: "Highest peak in Gujarat. Sacred 10,000 stone-step ascent through misty crags, Dattatreya peak, and ancient Jain temples rising out of the Gir lion forest."
        ),
        TrekRecord(
            name: "Pavagadh Hill & Kalika Mata",
            region: "Panchmahal, Champaner, Gujarat",
            country: "India",
            latitude: 22.4580,
            longitude: 73.5300,
            elevationMeters: 824,
            trailDistanceKm: 5.5,
            elevationGainMeters: 550,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            rating: 5,
            personalNotes: "UNESCO World Heritage fortress hill. Dramatic volcanic plateau with the ancient Mahakali Shaktipeeth temple perched atop the supreme cliff."
        ),
        TrekRecord(
            name: "Saputara (Governor's Hill & Sunset Point)",
            region: "Dang, Sahyadri Range, Gujarat",
            country: "India",
            latitude: 20.5750,
            longitude: 73.7500,
            elevationMeters: 1000,
            trailDistanceKm: 7.0,
            elevationGainMeters: 380,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Gujarat's sole hill station nestled in the deep bamboo forests of Dang. Sweeping views across the Western Ghats tableland."
        ),
        TrekRecord(
            name: "Shatrunjaya Hills",
            region: "Palitana, Bhavnagar, Gujarat",
            country: "India",
            latitude: 21.5000,
            longitude: 71.8200,
            elevationMeters: 591,
            trailDistanceKm: 6.8,
            elevationGainMeters: 450,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "Sacred city of 863 white marble Jain temples atop twin hill ridges. 3,750 carved steps overlooking the Shetrunji river."
        ),
        TrekRecord(
            name: "Kalo Dungar (Black Hill)",
            region: "Khavda, Kutch, Gujarat",
            country: "India",
            latitude: 23.9310,
            longitude: 69.8000,
            elevationMeters: 462,
            trailDistanceKm: 4.5,
            elevationGainMeters: 280,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -8, to: Date()),
            rating: 5,
            personalNotes: "Highest point in Kutch. Breathtaking panoramic horizon over the Great Rann of Kutch white salt desert and India-Pakistan border."
        ),
        TrekRecord(
            name: "Wilson Hills (Pangarbari Peak)",
            region: "Dharampur, Valsad, Gujarat",
            country: "India",
            latitude: 20.5100,
            longitude: 73.2200,
            elevationMeters: 750,
            trailDistanceKm: 6.0,
            elevationGainMeters: 350,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -5, to: Date()),
            rating: 5,
            personalNotes: "Dense teak forest hill station with cool sea breezes and Marble Chhatri viewpoint overlooking the Arabian Sea coastline."
        ),
        TrekRecord(
            name: "Chotila Hill (Chamunda Mata)",
            region: "Surendranagar, Gujarat",
            country: "India",
            latitude: 22.4200,
            longitude: 71.1900,
            elevationMeters: 340,
            trailDistanceKm: 2.2,
            elevationGainMeters: 220,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -2, to: Date()),
            rating: 5,
            personalNotes: "Volcanic cone monolith rising abruptly from the flat plains of Saurashtra. 635 steps to the revered Chamunda Devi summit."
        ),
        TrekRecord(
            name: "Barda Hills (Abhapara Peak)",
            region: "Porbandar / Devbhumi Dwarka, Gujarat",
            country: "India",
            latitude: 21.8000,
            longitude: 69.7500,
            elevationMeters: 637,
            trailDistanceKm: 9.5,
            elevationGainMeters: 480,
            status: .wishlist,
            difficulty: .moderate,
            rating: 5,
            personalNotes: "Highest peak in Saurashtra outside Girnar. Dense wildlife sanctuary home to leopards, medicinal herbs, and Khambala dam."
        ),
        TrekRecord(
            name: "Taranga Hills (Ajitnath Peak)",
            region: "Mehsana, Aravalli Outlier, Gujarat",
            country: "India",
            latitude: 23.9900,
            longitude: 72.7600,
            elevationMeters: 365,
            trailDistanceKm: 4.0,
            elevationGainMeters: 260,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -7, to: Date()),
            rating: 5,
            personalNotes: "Serene sandstone rock formations with 12th-century Solanki architecture and ancient Buddhist rock-cut caves."
        ),
        TrekRecord(
            name: "Idar Gadh (Ilva Durg)",
            region: "Sabarkantha, Gujarat",
            country: "India",
            latitude: 23.8300,
            longitude: 73.0000,
            elevationMeters: 270,
            trailDistanceKm: 3.5,
            elevationGainMeters: 180,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Famous natural granite boulder fortress mentioned in folklore. Ruthi Rani no Mahal and the historic clock tower."
        ),
        TrekRecord(
            name: "Datar Hill (Jamiyal Shah Datar)",
            region: "Junagadh, Gujarat",
            country: "India",
            latitude: 21.5150,
            longitude: 70.4850,
            elevationMeters: 847,
            trailDistanceKm: 7.0,
            elevationGainMeters: 650,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "3,000-step cliff ascent on the southern flank of Girnar. Sacred sufi shrine overlooking the Junagadh city ramparts."
        ),
        TrekRecord(
            name: "Gabbar Hill & Arasur (Ambaji)",
            region: "Banaskantha, Gujarat / Rajasthan Border",
            country: "India",
            latitude: 24.3300,
            longitude: 72.8500,
            elevationMeters: 480,
            trailDistanceKm: 3.0,
            elevationGainMeters: 240,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -9, to: Date()),
            rating: 5,
            personalNotes: "Original abode of Goddess Amba with the eternal divine flame on the high Aravalli ridge (999 stone steps)."
        ),
        TrekRecord(
            name: "Dhinodhar Hills",
            region: "Nakhatrana, Kutch, Gujarat",
            country: "India",
            latitude: 23.4500,
            longitude: 69.3400,
            elevationMeters: 386,
            trailDistanceKm: 4.8,
            elevationGainMeters: 290,
            status: .wishlist,
            difficulty: .moderate,
            rating: 5,
            personalNotes: "Extinct volcanic plug with dramatic basalt columns and the hilltop monastery of Saint Dhoramnath."
        ),

        // =========================================================================
        // 🏰 2. MAHARASHTRA (SAHYADRI MOUNTAINS, FORTS & PINNACLES)
        // =========================================================================

        TrekRecord(
            name: "Kalsubai Peak",
            region: "Igatpuri, Ahmednagar, Maharashtra",
            country: "India",
            latitude: 19.6010,
            longitude: 73.7050,
            elevationMeters: 1646,
            trailDistanceKm: 6.6,
            elevationGainMeters: 820,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -2, to: Date()),
            rating: 5,
            personalNotes: "Highest peak in Maharashtra ('Everest of Sahyadri'). Steel ladders on sheer rock faces with sunrise over Bhandardara lake."
        ),
        TrekRecord(
            name: "Salher Fort",
            region: "Baglan, Nashik, Maharashtra",
            country: "India",
            latitude: 20.7220,
            longitude: 73.9400,
            elevationMeters: 1567,
            trailDistanceKm: 8.5,
            elevationGainMeters: 780,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Highest fort in Maharashtra and 2nd highest peak in the Sahyadris. Site of the epic 1672 Battle of Salher."
        ),
        TrekRecord(
            name: "Salota Fort",
            region: "Baglan, Nashik, Maharashtra",
            country: "India",
            latitude: 20.7150,
            longitude: 73.9350,
            elevationMeters: 1495,
            trailDistanceKm: 6.0,
            elevationGainMeters: 620,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Twin rock-cut fortress facing Salher with five consecutive fortified stone entrance gateways."
        ),
        TrekRecord(
            name: "Harishchandragad & Konkan Kada",
            region: "Ahmednagar, Maharashtra",
            country: "India",
            latitude: 19.3870,
            longitude: 73.7780,
            elevationMeters: 1424,
            trailDistanceKm: 14.0,
            elevationGainMeters: 900,
            status: .wishlist,
            difficulty: .strenuous,
            dateConquered: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            rating: 5,
            personalNotes: "Iconic concave cliff dropping 2,000ft into the Konkan plains. Kedareshwar cave temple and Brocken Spectre optical phenomenon."
        ),
        TrekRecord(
            name: "Rajgad Fort (Suvela Machi)",
            region: "Pune, Maharashtra",
            country: "India",
            latitude: 18.2460,
            longitude: 73.6820,
            elevationMeters: 1376,
            trailDistanceKm: 10.5,
            elevationGainMeters: 750,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            rating: 5,
            personalNotes: "Royal capital of Chhatrapati Shivaji Maharaj for 26 years. Magnificent double-walled bastions and natural rock needle eye (Nedhe)."
        ),
        TrekRecord(
            name: "Torna Fort (Prachandagad)",
            region: "Pune, Maharashtra",
            country: "India",
            latitude: 18.2770,
            longitude: 73.6230,
            elevationMeters: 1403,
            trailDistanceKm: 9.0,
            elevationGainMeters: 820,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -2, to: Date()),
            rating: 5,
            personalNotes: "The massive fortress captured by 16-year-old Shivaji in 1646 to launch the Maratha Empire. Thrilling Zunjar Machi ridge."
        ),
        TrekRecord(
            name: "Sinhagad Fort (Kondhana)",
            region: "Haveli, Pune, Maharashtra",
            country: "India",
            latitude: 18.3660,
            longitude: 73.7550,
            elevationMeters: 1312,
            trailDistanceKm: 6.0,
            elevationGainMeters: 550,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            rating: 5,
            personalNotes: "The historic 'Lion Fort' immortalized by Tanaji Malusare's heroic night climb of 1670. Famous for pithla bhakri at the top."
        ),
        TrekRecord(
            name: "Raigad Fort (Royal Capital)",
            region: "Mahad, Konkan, Maharashtra",
            country: "India",
            latitude: 18.2350,
            longitude: 73.4450,
            elevationMeters: 820,
            trailDistanceKm: 7.5,
            elevationGainMeters: 680,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -5, to: Date()),
            rating: 5,
            personalNotes: "The supreme seat of the Maratha Empire where Shivaji Maharaj was crowned Chhatrapati in 1674. Massive Takmak Tok execution cliff."
        ),
        TrekRecord(
            name: "Pratapgad Fort",
            region: "Mahabaleshwar, Satara, Maharashtra",
            country: "India",
            latitude: 17.9300,
            longitude: 73.5800,
            elevationMeters: 1080,
            trailDistanceKm: 4.5,
            elevationGainMeters: 420,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "Jungle mountain fort overlooking the Jawali forest. Site of the famous encounter between Shivaji Maharaj and Afzal Khan."
        ),
        TrekRecord(
            name: "Ratangad Fort (Jewel of Sahyadri)",
            region: "Bhandardara, Ahmednagar, Maharashtra",
            country: "India",
            latitude: 19.5000,
            longitude: 73.6900,
            elevationMeters: 1297,
            trailDistanceKm: 8.0,
            elevationGainMeters: 620,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -2, to: Date()),
            rating: 5,
            personalNotes: "Features the iconic 'Eye of the Needle' rock cavity opening up 360-degree vistas across Alang, Madan, Kulang, and Lake Arthur."
        ),
        TrekRecord(
            name: "Alang Madan Kulang (AMK Trio)",
            region: "Kalsubai Range, Nashik, Maharashtra",
            country: "India",
            latitude: 19.5840,
            longitude: 73.6520,
            elevationMeters: 1470,
            trailDistanceKm: 28.0,
            elevationGainMeters: 1700,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "The ultimate technical endurance test of Sahyadri trekking: 90-degree rock wall climbs, blind traverses, and cave bivouacking."
        ),
        TrekRecord(
            name: "Sandhan Valley (Valley of Shadows)",
            region: "Samrad, Bhandardara, Maharashtra",
            country: "India",
            latitude: 19.5200,
            longitude: 73.6900,
            elevationMeters: 1200,
            trailDistanceKm: 16.0,
            elevationGainMeters: 800,
            status: .wishlist,
            difficulty: .strenuous,
            dateConquered: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            rating: 5,
            personalNotes: "200ft deep canyon where sun rays cannot penetrate. Rappelling down sheer rock walls and boulder hopping into Konkan."
        ),
        TrekRecord(
            name: "Kalavantin Durg",
            region: "Panvel, Raigad, Maharashtra",
            country: "India",
            latitude: 18.9800,
            longitude: 73.2200,
            elevationMeters: 686,
            trailDistanceKm: 6.0,
            elevationGainMeters: 510,
            status: .wishlist,
            difficulty: .strenuous,
            dateConquered: Calendar.current.date(byAdding: .month, value: -2, to: Date()),
            rating: 5,
            personalNotes: "World-famous vertical rock needle with exposed stone steps carved directly into the 70-degree basalt slope with no handrails."
        ),
        TrekRecord(
            name: "Prabalmachi & Prabalgad",
            region: "Panvel, Raigad, Maharashtra",
            country: "India",
            latitude: 18.9750,
            longitude: 73.2250,
            elevationMeters: 700,
            trailDistanceKm: 8.5,
            elevationGainMeters: 580,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            rating: 5,
            personalNotes: "Massive forested plateau overlooking Kalavantin Durg and the Mumbai-Pune expressway."
        ),
        TrekRecord(
            name: "Lohagad Fort (Iron Fort)",
            region: "Lonavala, Pune, Maharashtra",
            country: "India",
            latitude: 18.7000,
            longitude: 73.4800,
            elevationMeters: 1033,
            trailDistanceKm: 5.0,
            elevationGainMeters: 380,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -5, to: Date()),
            rating: 5,
            personalNotes: "Monsoon fortress featuring the 1.5km scorpion's tail ridge (Vinchukata) jutting into the roaring mist."
        ),
        TrekRecord(
            name: "Visapur Fort",
            region: "Lonavala, Pune, Maharashtra",
            country: "India",
            latitude: 18.7200,
            longitude: 73.4900,
            elevationMeters: 1084,
            trailDistanceKm: 6.5,
            elevationGainMeters: 450,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -5, to: Date()),
            rating: 5,
            personalNotes: "Ascend directly through a gushing waterfall on the ancient stone staircase during peak monsoon."
        ),
        TrekRecord(
            name: "Rajmachi Fort (Shrivardhan & Manaranjan)",
            region: "Karjat / Lonavala, Maharashtra",
            country: "India",
            latitude: 18.8250,
            longitude: 73.4000,
            elevationMeters: 826,
            trailDistanceKm: 14.0,
            elevationGainMeters: 620,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Historic twin fort strategic outpost overseeing the Bor Ghat trade route. World-famous pre-monsoon firefly festival."
        ),
        TrekRecord(
            name: "Dhodap Fort",
            region: "Chandwad, Nashik, Maharashtra",
            country: "India",
            latitude: 20.3800,
            longitude: 74.0300,
            elevationMeters: 1472,
            trailDistanceKm: 9.0,
            elevationGainMeters: 750,
            status: .wishlist,
            difficulty: .strenuous,
            rating: 5,
            personalNotes: "Second highest fort in Maharashtra with an astonishing knife-edge rock-cut cleft at the summit pinnacle."
        ),
        TrekRecord(
            name: "Brahmagiri & Anjaneri Hill",
            region: "Trimbakeshwar, Nashik, Maharashtra",
            country: "India",
            latitude: 19.9300,
            longitude: 73.5300,
            elevationMeters: 1295,
            trailDistanceKm: 7.0,
            elevationGainMeters: 550,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "Source of the sacred Godavari River and legendary birthplace of Lord Hanuman amid vertical rock walls."
        ),
        TrekRecord(
            name: "Tikona Fort (Vitandgad)",
            region: "Pawna Lake, Pune, Maharashtra",
            country: "India",
            latitude: 18.6300,
            longitude: 73.5200,
            elevationMeters: 1060,
            trailDistanceKm: 4.0,
            elevationGainMeters: 380,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            rating: 5,
            personalNotes: "Striking triangular pyramid fort rising directly beside the blue waters of Pawna Dam reservoir."
        ),
        TrekRecord(
            name: "Vasota Fort (Vyaghragad)",
            region: "Koyna Wildlife Sanctuary, Satara, Maharashtra",
            country: "India",
            latitude: 17.6500,
            longitude: 73.6800,
            elevationMeters: 1171,
            trailDistanceKm: 12.0,
            elevationGainMeters: 650,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -7, to: Date()),
            rating: 5,
            personalNotes: "Deep jungle wilderness trek accessed via a scenic boat ride across the backwaters of Shivsagar Lake."
        ),
        TrekRecord(
            name: "Karnala Pinnacle & Fort",
            region: "Panvel, Raigad, Maharashtra",
            country: "India",
            latitude: 18.8900,
            longitude: 73.1200,
            elevationMeters: 440,
            trailDistanceKm: 5.5,
            elevationGainMeters: 360,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            rating: 5,
            personalNotes: "Famous basalt 'thumbs-up' volcanic chimney rising above the lush Karnala Bird Sanctuary forest."
        ),
        TrekRecord(
            name: "Chanderi Fort",
            region: "Badlapur / Vangani, Maharashtra",
            country: "India",
            latitude: 19.0400,
            longitude: 73.2800,
            elevationMeters: 704,
            trailDistanceKm: 7.0,
            elevationGainMeters: 620,
            status: .wishlist,
            difficulty: .strenuous,
            rating: 5,
            personalNotes: "Crown-shaped monolithic rock tower requiring steep scree scrambling and a narrow rock col crossing."
        ),
        TrekRecord(
            name: "Peb Fort (Vikatgad)",
            region: "Neral, Matheran Range, Maharashtra",
            country: "India",
            latitude: 19.0000,
            longitude: 73.3000,
            elevationMeters: 640,
            trailDistanceKm: 8.0,
            elevationGainMeters: 550,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Thrilling ridge trail following the historic Matheran narrow-gauge railway line with ladder sections."
        ),

        // =========================================================================
        // 🏜️ 3. RAJASTHAN (ARAVALLI RANGE & DESERT FORTS)
        // =========================================================================

        TrekRecord(
            name: "Guru Shikhar",
            region: "Mount Abu, Sirohi, Rajasthan",
            country: "India",
            latitude: 24.6500,
            longitude: 72.7800,
            elevationMeters: 1722,
            trailDistanceKm: 7.0,
            elevationGainMeters: 450,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -9, to: Date()),
            rating: 5,
            personalNotes: "Highest peak of Rajasthan and the entire 1.5-billion-year-old Aravalli Mountain Range. Dattatreya temple at the apex."
        ),
        TrekRecord(
            name: "Ser (Sher) Peak",
            region: "Mount Abu, Sirohi, Rajasthan",
            country: "India",
            latitude: 24.6300,
            longitude: 72.7600,
            elevationMeters: 1597,
            trailDistanceKm: 8.0,
            elevationGainMeters: 520,
            status: .wishlist,
            difficulty: .moderate,
            rating: 5,
            personalNotes: "Second highest peak in Rajasthan offering serene wilderness trails away from tourist tracks."
        ),
        TrekRecord(
            name: "Kumbhalgarh Fort (Great Wall of India)",
            region: "Rajsamand, Aravallis, Rajasthan",
            country: "India",
            latitude: 25.1500,
            longitude: 73.5800,
            elevationMeters: 1087,
            trailDistanceKm: 10.0,
            elevationGainMeters: 580,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -7, to: Date()),
            rating: 5,
            personalNotes: "Birthplace of Maharana Pratap encircled by a 36km continuous stone fortification wall — the 2nd longest on Earth."
        ),
        TrekRecord(
            name: "Chittorgarh Fort (Bhimlat Plateau)",
            region: "Chittorgarh, Rajasthan",
            country: "India",
            latitude: 24.8800,
            longitude: 74.6400,
            elevationMeters: 580,
            trailDistanceKm: 9.0,
            elevationGainMeters: 380,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -8, to: Date()),
            rating: 5,
            personalNotes: "Largest fortress in Asia spread across 700 acres on an isolated 180m high plateau. Tower of Victory (Vijay Stambha)."
        ),
        TrekRecord(
            name: "Nahargarh & Jaigarh Forts",
            region: "Jaipur, Aravallis, Rajasthan",
            country: "India",
            latitude: 26.9380,
            longitude: 75.8150,
            elevationMeters: 648,
            trailDistanceKm: 6.5,
            elevationGainMeters: 340,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -5, to: Date()),
            rating: 5,
            personalNotes: "Dramatic cobblestone ridge trail connecting the Tiger Fort of Nahargarh to Jaigarh, home to the world's largest cannon on wheels."
        ),
        TrekRecord(
            name: "Taragarh Fort (Star Fort)",
            region: "Ajmer, Aravallis, Rajasthan",
            country: "India",
            latitude: 26.4400,
            longitude: 74.6200,
            elevationMeters: 870,
            trailDistanceKm: 5.0,
            elevationGainMeters: 420,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "Built in the 12th century on a sheer 800ft crag overlooking the sacred city of Ajmer and Ana Sagar lake."
        ),
        TrekRecord(
            name: "Sajjangarh (Monsoon Palace)",
            region: "Udaipur, Aravallis, Rajasthan",
            country: "India",
            latitude: 24.5900,
            longitude: 73.6300,
            elevationMeters: 938,
            trailDistanceKm: 4.5,
            elevationGainMeters: 350,
            status: .wishlist,
            difficulty: .easy,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Palace perched on the Bansdara peak of the Aravalli range built by Maharana Sajjan Singh to watch monsoon clouds gather over Lake Pichola."
        ),
        TrekRecord(
            name: "Raghunathgarh Peak",
            region: "Sikar, Northern Aravallis, Rajasthan",
            country: "India",
            latitude: 27.6500,
            longitude: 75.3500,
            elevationMeters: 1055,
            trailDistanceKm: 7.5,
            elevationGainMeters: 550,
            status: .wishlist,
            difficulty: .moderate,
            rating: 5,
            personalNotes: "Highest mountain summit in northern Rajasthan (Shekhawati region) with sweeping views of the desert fringe."
        ),
        TrekRecord(
            name: "Harshnath Peak",
            region: "Sikar, Aravallis, Rajasthan",
            country: "India",
            latitude: 27.5200,
            longitude: 75.1800,
            elevationMeters: 950,
            trailDistanceKm: 6.0,
            elevationGainMeters: 460,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "Ancient 10th-century carved Shiva temple ruins perched atop a steep Aravalli ridge."
        ),

        // =========================================================================
        // 🏔️ 4. GREAT HIMALAYAS & HIGH KARAKORAM GIANTS
        // =========================================================================

        TrekRecord(
            name: "Kangchenjunga",
            region: "Sikkim Himalayas",
            country: "India / Nepal",
            latitude: 27.7025,
            longitude: 88.1475,
            elevationMeters: 8586,
            trailDistanceKm: 90.0,
            elevationGainMeters: 5200,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "Highest peak in India and 3rd highest on Earth. Revered as the sacred protector deity of Sikkim."
        ),
        TrekRecord(
            name: "Nanda Devi",
            region: "Garhwal, Uttarakhand",
            country: "India",
            latitude: 30.3753,
            longitude: 79.9703,
            elevationMeters: 7816,
            trailDistanceKm: 75.0,
            elevationGainMeters: 4800,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "Highest peak entirely within Indian territory. Surrounded by the protected UNESCO Biosphere ring of twin 7,000m barrier peaks."
        ),
        TrekRecord(
            name: "Kamet",
            region: "Zaskar Range, Uttarakhand",
            country: "India",
            latitude: 30.9200,
            longitude: 79.5700,
            elevationMeters: 7756,
            trailDistanceKm: 65.0,
            elevationGainMeters: 4100,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "Second highest summit in Garhwal near the Tibetan plateau. Massive pyramid monolith."
        ),
        TrekRecord(
            name: "Trisul",
            region: "Kumaon Himalayas, Uttarakhand",
            country: "India",
            latitude: 30.3100,
            longitude: 79.7750,
            elevationMeters: 7120,
            trailDistanceKm: 58.0,
            elevationGainMeters: 3900,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "The sacred Trident peak of Lord Shiva. Towering over the mysterious high-altitude Roopkund glacial tarn."
        ),
        TrekRecord(
            name: "Chaukhamba",
            region: "Gangotri Glacier, Uttarakhand",
            country: "India",
            latitude: 30.7460,
            longitude: 79.2800,
            elevationMeters: 7138,
            trailDistanceKm: 42.0,
            elevationGainMeters: 3600,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "The Four-Pillared Giant overlooking the sacred source of the Bhagirathi river at Gaumukh."
        ),
        TrekRecord(
            name: "Kedarnath Peak",
            region: "Garhwal, Uttarakhand",
            country: "India",
            latitude: 30.7960,
            longitude: 79.0300,
            elevationMeters: 6940,
            trailDistanceKm: 34.0,
            elevationGainMeters: 3200,
            status: .wishlist,
            difficulty: .alpineExpert,
            dateConquered: Calendar.current.date(byAdding: .month, value: -10, to: Date()),
            rating: 5,
            personalNotes: "Massive snowy ramparts rising directly behind the historic 8th-century Kedarnath temple shrine."
        ),
        TrekRecord(
            name: "Shivling",
            region: "Tapovan, Uttarakhand",
            country: "India",
            latitude: 30.8780,
            longitude: 79.0660,
            elevationMeters: 6543,
            trailDistanceKm: 48.0,
            elevationGainMeters: 2800,
            status: .wishlist,
            difficulty: .alpineExpert,
            dateConquered: Calendar.current.date(byAdding: .month, value: -8, to: Date()),
            rating: 5,
            personalNotes: "Known worldwide as the 'Matterhorn of India'. Striking sheer pyramid rising directly from the high-altitude meadow of Tapovan."
        ),
        TrekRecord(
            name: "Stok Kangri",
            region: "Hemis National Park, Ladakh",
            country: "India",
            latitude: 33.9850,
            longitude: 77.4470,
            elevationMeters: 6153,
            trailDistanceKm: 40.0,
            elevationGainMeters: 2600,
            status: .wishlist,
            difficulty: .strenuous,
            dateConquered: Calendar.current.date(byAdding: .year, value: -1, to: Date()),
            rating: 5,
            personalNotes: "Ladakh's crown 6,000m trekking peak. 360-degree summit views across the Karakoram, K2, and Zanskar ranges."
        ),
        TrekRecord(
            name: "Kedarkantha",
            region: "Govind Pashu Vihar, Uttarakhand",
            country: "India",
            latitude: 31.0250,
            longitude: 78.1730,
            elevationMeters: 3810,
            trailDistanceKm: 20.0,
            elevationGainMeters: 1850,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            rating: 5,
            personalNotes: "India's most beloved winter snow peak. 360-degree sunrise across Swargarohini, Black Peak, and Bandarpoonch."
        ),
        TrekRecord(
            name: "Deoriatal - Chandrashila",
            region: "Rudraprayag, Uttarakhand",
            country: "India",
            latitude: 30.4900,
            longitude: 79.2200,
            elevationMeters: 3690,
            trailDistanceKm: 15.0,
            elevationGainMeters: 1200,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Trek past the world's highest Shiva temple (Tungnath at 3,680m) to reach the cliff summit of Chandrashila."
        ),
        TrekRecord(
            name: "Sandakphu",
            region: "Singalila Ridge, West Bengal / Sikkim",
            country: "India",
            latitude: 27.1060,
            longitude: 88.0000,
            elevationMeters: 3636,
            trailDistanceKm: 45.0,
            elevationGainMeters: 1800,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -9, to: Date()),
            rating: 5,
            personalNotes: "Only vantage point on Earth where you can see the four highest 8000ers: Everest, Kangchenjunga, Lhotse, and Makalu in one frame."
        ),
        TrekRecord(
            name: "Anamudi",
            region: "Eravikulam National Park, Kerala",
            country: "India",
            latitude: 10.1690,
            longitude: 77.0640,
            elevationMeters: 2695,
            trailDistanceKm: 12.0,
            elevationGainMeters: 950,
            status: .wishlist,
            difficulty: .moderate,
            rating: 5,
            personalNotes: "Highest peak in South India and all of the Western Ghats ('Elephant's Forehead'). Home to the endangered Nilgiri Tahr."
        ),
        TrekRecord(
            name: "Doddabetta",
            region: "Nilgiris, Tamil Nadu",
            country: "India",
            latitude: 11.4010,
            longitude: 76.7360,
            elevationMeters: 2637,
            trailDistanceKm: 8.0,
            elevationGainMeters: 550,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "Highest summit of the Blue Nilgiri Mountains. Rolling clouds, eucalyptus groves, and high-altitude telescope deck."
        ),
        TrekRecord(
            name: "Mullayanagiri",
            region: "Chikkamagaluru, Karnataka",
            country: "India",
            latitude: 13.3910,
            longitude: 75.7210,
            elevationMeters: 1930,
            trailDistanceKm: 6.0,
            elevationGainMeters: 500,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -4, to: Date()),
            rating: 5,
            personalNotes: "Highest peak in Karnataka. Serene mist-covered ridge trail surrounded by lush coffee estates."
        ),
        TrekRecord(
            name: "Dhupgarh",
            region: "Pachmarhi, Satpura Range, Madhya Pradesh",
            country: "India",
            latitude: 22.4500,
            longitude: 78.4300,
            elevationMeters: 1352,
            trailDistanceKm: 8.0,
            elevationGainMeters: 480,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -5, to: Date()),
            rating: 5,
            personalNotes: "Highest peak in Madhya Pradesh and the Satpura Range. Famous for crimson ravine sunsets."
        ),

        // =========================================================================
        // 🌐 5. ICONIC GLOBAL SUMMITS & SEVEN SUMMITS
        // =========================================================================

        TrekRecord(
            name: "Mount Everest",
            region: "Mahalangur Himal",
            country: "Nepal / Tibet",
            latitude: 27.9881,
            longitude: 86.9250,
            elevationMeters: 8848,
            trailDistanceKm: 130.0,
            elevationGainMeters: 5500,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "The roof of the world (Sagarmatha). Ultimate mountaineering frontier."
        ),
        TrekRecord(
            name: "Mount Fuji",
            region: "Honshu",
            country: "Japan",
            latitude: 35.3606,
            longitude: 138.7274,
            elevationMeters: 3776,
            trailDistanceKm: 14.5,
            elevationGainMeters: 1450,
            status: .wishlist,
            difficulty: .moderate,
            dateConquered: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
            rating: 5,
            personalNotes: "Sunrise at 3,776m above the sea of clouds (Goraikō). Unforgettable volcanic trail."
        ),
        TrekRecord(
            name: "Mont Blanc",
            region: "Chamonix, Alps",
            country: "France / Italy",
            latitude: 45.8326,
            longitude: 6.8652,
            elevationMeters: 4809,
            trailDistanceKm: 32.0,
            elevationGainMeters: 3800,
            status: .wishlist,
            difficulty: .alpineExpert,
            dateConquered: Calendar.current.date(byAdding: .year, value: -1, to: Date()),
            rating: 5,
            personalNotes: "The monarch of the Alps. Glacial traverse via Goûter route. Pure alpine grandeur."
        ),
        TrekRecord(
            name: "Mount Kilimanjaro",
            region: "Kilimanjaro National Park",
            country: "Tanzania",
            latitude: -3.0674,
            longitude: 37.3556,
            elevationMeters: 5895,
            trailDistanceKm: 62.0,
            elevationGainMeters: 4100,
            status: .wishlist,
            difficulty: .strenuous,
            dateConquered: Calendar.current.date(byAdding: .month, value: -8, to: Date()),
            rating: 5,
            personalNotes: "Uhuru Peak at 5,895m. Roof of Africa across 5 distinct ecological climate zones."
        ),
        TrekRecord(
            name: "Matterhorn",
            region: "Zermatt, Pennine Alps",
            country: "Switzerland",
            latitude: 45.9763,
            longitude: 7.6586,
            elevationMeters: 4478,
            trailDistanceKm: 16.0,
            elevationGainMeters: 1900,
            status: .wishlist,
            difficulty: .alpineExpert,
            rating: 5,
            personalNotes: "The quintessential pyramid monolith."
        )
    ]
}
