import Foundation

/// The five daily prayers we track and notify for.
enum PrayerName: String, CaseIterable, Identifiable, Codable {
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .fajr: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

struct PrayerTiming: Identifiable, Equatable {
    var id: String { name.rawValue }
    let name: PrayerName
    let date: Date
}

struct PrayerDaySchedule: Equatable {
    let date: Date
    let latitude: Double
    let longitude: Double
    let timezone: String?
    let timings: [PrayerTiming]
    
    func nextPrayer(after now: Date = Date()) -> PrayerTiming? {
        timings.first { $0.date > now }
    }
}

/// Aladhan calculation methods (API `method` query param).
enum PrayerCalculationMethod: Int, CaseIterable, Identifiable, Codable {
    case karachi = 1
    case isna = 2
    case muslimWorldLeague = 3
    case ummAlQura = 4
    case egyptian = 5
    case tehran = 7
    case gulf = 8
    case kuwait = 9
    case qatar = 10
    case singapore = 11
    case france = 12
    case turkey = 13
    case russia = 14
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .karachi: return "Karachi (UIS)"
        case .isna: return "ISNA (North America)"
        case .muslimWorldLeague: return "Muslim World League"
        case .ummAlQura: return "Umm Al-Qura (Makkah)"
        case .egyptian: return "Egyptian Authority"
        case .tehran: return "Tehran"
        case .gulf: return "Gulf Region"
        case .kuwait: return "Kuwait"
        case .qatar: return "Qatar"
        case .singapore: return "Singapore"
        case .france: return "France"
        case .turkey: return "Turkey"
        case .russia: return "Russia"
        }
    }
}

enum AsrJuristicSchool: Int, CaseIterable, Identifiable, Codable {
    case standard = 0  // Shafi, Maliki, Hanbali
    case hanafi = 1
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .standard: return "Standard (Shafi)"
        case .hanafi: return "Hanafi"
        }
    }
}
