import CoreLocation
import Foundation
import UserNotifications

/// Locates the Mac, fetches prayer times from Aladhan, and schedules local notifications.
@Observable
final class PrayerService: NSObject {
    // MARK: - Settings (persisted)
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                Task { await start() }
            } else {
                clearSchedule()
                PrayerNotificationScheduler.cancelAll()
            }
        }
    }
    
    var method: PrayerCalculationMethod {
        didSet {
            UserDefaults.standard.set(method.rawValue, forKey: Keys.method)
            Task { await refreshIfEnabled() }
        }
    }
    
    var school: AsrJuristicSchool {
        didSet {
            UserDefaults.standard.set(school.rawValue, forKey: Keys.school)
            Task { await refreshIfEnabled() }
        }
    }
    
    /// Notify this many minutes before each prayer (0 = at the start time).
    var notifyMinutesBefore: Int {
        didSet {
            UserDefaults.standard.set(notifyMinutesBefore, forKey: Keys.notifyBefore)
            rescheduleNotifications()
        }
    }
    
    // MARK: - State
    var schedule: PrayerDaySchedule?
    var locationLabel: String = "Locating…"
    var statusMessage: String?
    var isLoading = false
    var authorizationDenied = false
    
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var lastCoordinate: CLLocationCoordinate2D?
    
    private enum Keys {
        static let enabled = "prayer.enabled"
        static let method = "prayer.method"
        static let school = "prayer.school"
        static let notifyBefore = "prayer.notifyBefore"
        static let lastLat = "prayer.lastLat"
        static let lastLon = "prayer.lastLon"
    }
    
    override init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Keys.enabled)
        let methodRaw = defaults.object(forKey: Keys.method) as? Int
        method = PrayerCalculationMethod(rawValue: methodRaw ?? PrayerCalculationMethod.karachi.rawValue) ?? .karachi
        let schoolRaw = defaults.object(forKey: Keys.school) as? Int
        school = AsrJuristicSchool(rawValue: schoolRaw ?? 0) ?? .standard
        notifyMinutesBefore = defaults.object(forKey: Keys.notifyBefore) as? Int ?? 5
        
        if defaults.object(forKey: Keys.lastLat) != nil {
            lastCoordinate = CLLocationCoordinate2D(
                latitude: defaults.double(forKey: Keys.lastLat),
                longitude: defaults.double(forKey: Keys.lastLon)
            )
        }
        
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    var nextPrayer: PrayerTiming? {
        schedule?.nextPrayer()
    }
    
    func bootstrap() {
        guard isEnabled else { return }
        Task { await start() }
    }
    
    func refresh() async {
        guard isEnabled else { return }
        await start()
    }
    
    // MARK: - Pipeline
    
    private func start() async {
        isLoading = true
        statusMessage = nil
        authorizationDenied = false
        
        do {
            try await PrayerNotificationScheduler.requestAuthorization()
            let location = try await requestLocation()
            lastCoordinate = location.coordinate
            UserDefaults.standard.set(location.coordinate.latitude, forKey: Keys.lastLat)
            UserDefaults.standard.set(location.coordinate.longitude, forKey: Keys.lastLon)
            
            await reverseGeocode(location)
            let day = try await AladhanClient.fetchSchedule(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                method: method,
                school: school
            )
            schedule = day
            rescheduleNotifications()
            statusMessage = nil
        } catch {
            if let cached = lastCoordinate {
                do {
                    locationLabel = String(format: "%.2f°, %.2f°", cached.latitude, cached.longitude)
                    let day = try await AladhanClient.fetchSchedule(
                        latitude: cached.latitude,
                        longitude: cached.longitude,
                        method: method,
                        school: school
                    )
                    schedule = day
                    rescheduleNotifications()
                    statusMessage = "Using last known location"
                } catch {
                    statusMessage = error.localizedDescription
                }
            } else {
                statusMessage = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    private func refreshIfEnabled() async {
        guard isEnabled else { return }
        await start()
    }
    
    private func clearSchedule() {
        schedule = nil
        locationLabel = "Off"
        statusMessage = nil
    }
    
    private func rescheduleNotifications() {
        guard isEnabled, let schedule else {
            PrayerNotificationScheduler.cancelAll()
            return
        }
        PrayerNotificationScheduler.schedule(schedule.timings, minutesBefore: notifyMinutesBefore)
    }
    
    private func requestLocation() async throws -> CLLocation {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            authorizationDenied = true
            throw PrayerError.locationDenied
        default:
            break
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.locationManager.requestLocation()
        }
    }
    
    private func reverseGeocode(_ location: CLLocation) async {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            let city = placemark.locality ?? placemark.subAdministrativeArea
            let region = placemark.administrativeArea
            let country = placemark.country
            let parts = [city, region, country].compactMap { $0 }.filter { !$0.isEmpty }
            locationLabel = parts.isEmpty
                ? String(format: "%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude)
                : parts.joined(separator: ", ")
        } else {
            locationLabel = String(format: "%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension PrayerService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.locationContinuation?.resume(returning: location)
            self?.locationContinuation = nil
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.locationContinuation?.resume(throwing: error)
            self?.locationContinuation = nil
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = manager.authorizationStatus
            if status == .denied || status == .restricted {
                self.authorizationDenied = true
            }
            if self.isEnabled, status == .authorizedAlways || status == .authorized {
                await self.start()
            }
        }
    }
}

// MARK: - Errors
enum PrayerError: LocalizedError {
    case locationDenied
    case badResponse
    case missingTimings
    
    var errorDescription: String? {
        switch self {
        case .locationDenied:
            return "Location access denied. Enable it in System Settings → Privacy & Security → Location Services."
        case .badResponse:
            return "Could not load prayer times."
        case .missingTimings:
            return "Prayer times missing from response."
        }
    }
}

// MARK: - Aladhan client
enum AladhanClient {
    static func fetchSchedule(
        latitude: Double,
        longitude: Double,
        method: PrayerCalculationMethod,
        school: AsrJuristicSchool,
        date: Date = Date()
    ) async throws -> PrayerDaySchedule {
        let dateString = Self.dateFormatter.string(from: date)
        var components = URLComponents(string: "https://api.aladhan.com/v1/timings/\(dateString)")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "method", value: String(method.rawValue)),
            URLQueryItem(name: "school", value: String(school.rawValue)),
        ]
        
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PrayerError.badResponse
        }
        
        let decoded = try JSONDecoder().decode(AladhanResponse.self, from: data)
        guard decoded.code == 200 else { throw PrayerError.badResponse }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        var timings: [PrayerTiming] = []
        
        for name in PrayerName.allCases {
            guard let raw = decoded.data.timings[name.rawValue] else { continue }
            let cleaned = raw.split(separator: " ").first.map(String.init) ?? raw
            let parts = cleaned.split(separator: ":")
            guard parts.count >= 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]),
                  let prayerDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
            else { continue }
            timings.append(PrayerTiming(name: name, date: prayerDate))
        }
        
        guard !timings.isEmpty else { throw PrayerError.missingTimings }
        timings.sort { $0.date < $1.date }
        
        return PrayerDaySchedule(
            date: dayStart,
            latitude: latitude,
            longitude: longitude,
            timezone: decoded.data.meta?.timezone,
            timings: timings
        )
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd-MM-yyyy"
        return f
    }()
}

private struct AladhanResponse: Decodable {
    let code: Int
    let data: AladhanData
}

private struct AladhanData: Decodable {
    let timings: [String: String]
    let meta: AladhanMeta?
}

private struct AladhanMeta: Decodable {
    let timezone: String?
}

// MARK: - Notifications
enum PrayerNotificationScheduler {
    private static let prefix = "prayer."
    
    static func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .denied:
            return // still allow times UI; notifications just won't fire
        case .notDetermined:
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return
        }
    }
    
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
    
    static func schedule(_ timings: [PrayerTiming], minutesBefore: Int) {
        cancelAll()
        let center = UNUserNotificationCenter.current()
        let now = Date()
        
        for timing in timings {
            let fireDate = timing.date.addingTimeInterval(TimeInterval(-minutesBefore * 60))
            guard fireDate > now else { continue }
            
            let content = UNMutableNotificationContent()
            if minutesBefore > 0 {
                content.title = "\(timing.name.rawValue) in \(minutesBefore) min"
                content.body = "\(timing.name.rawValue) starts at \(Self.timeFormatter.string(from: timing.date))"
            } else {
                content.title = "\(timing.name.rawValue) time"
                content.body = "It's time for \(timing.name.rawValue) prayer"
            }
            content.sound = .default
            
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(prefix)\(timing.name.rawValue)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
