import Foundation
import UserNotifications

protocol NotificationScheduling {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func scheduleDailyReminder(timeString: String, nickname: String) async throws
}

struct NoopNotificationScheduler: NotificationScheduling {
    func requestAuthorizationIfNeeded() async throws -> Bool { false }
    func scheduleDailyReminder(timeString: String, nickname: String) async throws {}
}

struct UserNotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private let reminderIdentifier = "beautiful-diary.daily-reminder"

    func requestAuthorizationIfNeeded() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return false
        }
    }

    func scheduleDailyReminder(timeString: String, nickname: String) async throws {
        guard let dateComponents = parseTimeString(timeString) else { return }

        let content = UNMutableNotificationContent()
        content.title = nickname.isEmpty ? "Beauty Diary Reminder" : "\(nickname)，記得打卡"
        content.body = "打開美麗日記，更新今天的保養、體態或成長紀錄。"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        try await center.add(request)
    }

    private func parseTimeString(_ value: String) -> DateComponents? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = trimmed.split(separator: ":")
        guard pieces.count == 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = .current
        components.hour = hour
        components.minute = minute
        return components
    }
}
