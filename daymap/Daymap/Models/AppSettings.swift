import Foundation

enum AppearancePreference: String, CaseIterable, Codable {
    case dark
    case light
}

struct AppSettings: Codable, Equatable {
    var appearance: AppearancePreference
    /// Minutes from midnight for workday start (default 9:00 = 540)
    var workdayStartMinutes: Int
    /// Minutes from midnight for workday end (default 18:00 = 1080)
    var workdayEndMinutes: Int

    static let `default` = AppSettings(
        appearance: .dark,
        workdayStartMinutes: 9 * 60,
        workdayEndMinutes: 18 * 60
    )
}
