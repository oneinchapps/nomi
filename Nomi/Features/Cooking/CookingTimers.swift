import Foundation
import Observation
import UIKit
import UserNotifications

/// Timer im Kochmodus, einer pro Schritt. Läuft über einen Endzeitpunkt statt Herunterzählen –
/// so stimmt die Restzeit auch nach dem Wechsel in eine andere App.
/// Geklingelt wird über AlarmKit (auch stumm und im Hintergrund). Ohne Erlaubnis gibt es eine
/// Mitteilung für den Hintergrund und in der offenen App einen eigenen Ton, der die Stummschaltung übergeht.
@Observable
final class CookingTimers {
    struct Timer: Identifiable, Equatable {
        let id: Int // Schritt-Index
        let label: String
        let duration: TimeInterval
        var endDate: Date?
        var pausedRemaining: TimeInterval?
        var isFinished = false

        var isRunning: Bool { endDate != nil }

        func remaining(at now: Date) -> TimeInterval {
            if isFinished { return 0 }
            if let endDate { return max(0, endDate.timeIntervalSince(now)) }
            return pausedRemaining ?? duration
        }
    }

    let recipeTitle: String
    private(set) var timers: [Int: Timer] = [:]
    /// Gerade abgelaufener Timer, für den Hinweis oben.
    private(set) var justFinished: Timer?
    /// System-Timer (AlarmKit) pro Schritt; fehlt einer, klingelt die App selbst
    @ObservationIgnored private var alarmIds: [Int: UUID] = [:]
    @ObservationIgnored private lazy var chime = TimerChime()

    init(recipeTitle: String) {
        self.recipeTitle = recipeTitle
    }

    /// Laufende, pausierte und abgelaufene Timer, nach Schritt sortiert.
    var active: [Timer] {
        timers.values.filter { $0.isRunning || $0.pausedRemaining != nil || $0.isFinished }.sorted { $0.id < $1.id }
    }

    func timer(for step: Int) -> Timer? { timers[step] }

    func start(step: Int, label: String, duration: TimeInterval) {
        var timer = timers[step] ?? Timer(id: step, label: label, duration: duration)
        let remaining = timer.pausedRemaining ?? duration
        timer.endDate = .now.addingTimeInterval(remaining)
        timer.pausedRemaining = nil
        timer.isFinished = false
        timers[step] = timer
        let alarmId = UUID()
        cancelAlarm(step)
        alarmIds[step] = alarmId
        Task {
            let scheduled = await CookingAlarm.schedule(id: alarmId, title: "\(recipeTitle): \(timer.label) ist fertig", in: remaining)
            // Inzwischen pausiert oder zurückgesetzt? Dann den gerade geplanten wieder weg
            guard alarmIds[step] == alarmId, timers[step]?.isRunning == true else {
                if scheduled { CookingAlarm.cancel(alarmId) }
                return
            }
            if !scheduled {
                alarmIds[step] = nil
                await scheduleNotification(for: timer, in: remaining)
            }
        }
    }

    func pause(step: Int) {
        guard var timer = timers[step], timer.isRunning else { return }
        timer.pausedRemaining = timer.remaining(at: .now)
        timer.endDate = nil
        timers[step] = timer
        cancelNotification(step)
        cancelAlarm(step)
    }

    func reset(step: Int) {
        timers[step] = nil
        if justFinished?.id == step { justFinished = nil }
        cancelNotification(step)
        cancelAlarm(step)
    }

    /// „OK“ in der App: Hinweis weg und ein noch klingelnder System-Timer verstummt
    func dismissFinished() {
        if let id = justFinished?.id {
            timers[id] = nil
            if let alarm = alarmIds.removeValue(forKey: id) { CookingAlarm.stop(alarm) }
        }
        justFinished = nil
    }

    /// Einmal pro Sekunde aus der Ansicht aufgerufen: abgelaufene Timer melden.
    func tick(now: Date = .now) {
        for (step, timer) in timers where timer.isRunning && timer.remaining(at: now) <= 0 {
            var done = timer
            done.endDate = nil
            done.isFinished = true
            timers[step] = done
            justFinished = done
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            // Läuft ein System-Timer, klingelt der schon; sonst eigener Ton, der auch stumm hörbar ist
            if alarmIds[step] == nil { chime.play() }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: timers.keys.map(notificationId))
        for id in alarmIds.values { CookingAlarm.cancel(id) }
        alarmIds = [:]
        timers = [:]
        justFinished = nil
    }

    // MARK: - Mitteilungen

    private func notificationId(_ step: Int) -> String { "cooking-timer-\(step)" }

    private func scheduleNotification(for timer: Timer, in seconds: TimeInterval) async {
        #if DEBUG
        // UI-Tests: keine Rückfrage nach Mitteilungen, die den Ablauf blockiert
        if ProcessInfo.processInfo.environment["NOMI_DISABLE_NOTIFICATIONS"] == "1" { return }
        #endif
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true, seconds >= 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Timer abgelaufen"
        content.body = "\(recipeTitle) – \(timer.label)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: notificationId(timer.id),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await center.add(request)
    }

    private func cancelAlarm(_ step: Int) {
        if let id = alarmIds.removeValue(forKey: step) { CookingAlarm.cancel(id) }
    }

    private func cancelNotification(_ step: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId(step)])
    }
}
