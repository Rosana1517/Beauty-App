import Foundation
import UserNotifications

protocol NotificationScheduling {
    func requestAuthorizationIfNeeded() async throws -> Bool
    func scheduleDailyReminder(timeString: String, nickname: String) async throws
    /// 各習慣的獨立提醒（習慣名 -> "HH:mm"）；未在 map 內或時間無效者取消該提醒
    func scheduleHabitReminders(_ reminders: [String: String], nickname: String) async throws
}

struct NoopNotificationScheduler: NotificationScheduling {
    func requestAuthorizationIfNeeded() async throws -> Bool { false }
    func scheduleDailyReminder(timeString: String, nickname: String) async throws {}
    func scheduleHabitReminders(_ reminders: [String: String], nickname: String) async throws {}
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

    func scheduleHabitReminders(_ reminders: [String: String], nickname: String) async throws {
        // 先清掉所有習慣提醒再依現有設定重排，避免改時間後留下舊排程
        let allIdentifiers = HabitReminderKind.allCases.map { habitIdentifier(for: $0.rawValue) }
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

        for kind in HabitReminderKind.allCases {
            guard let timeString = reminders[kind.rawValue],
                  let dateComponents = parseTimeString(timeString) else { continue }

            let content = UNMutableNotificationContent()
            content.title = nickname.isEmpty ? kind.rawValue : "\(nickname)，\(kind.rawValue)時間到"
            content.body = kind.notificationBody
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: habitIdentifier(for: kind.rawValue),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    private func habitIdentifier(for habit: String) -> String {
        "beautiful-diary.habit-reminder.\(habit)"
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
