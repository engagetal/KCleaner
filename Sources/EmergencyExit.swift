import Foundation

/// Watches for the emergency exit: esc and delete held together for three seconds.
///
/// Why this combination can't happen by accident:
/// - esc sits at the top-left and delete at the top-right, so it takes two hands;
/// - both must stay down for a full three seconds;
/// - pressing any other key during those three seconds cancels it, and wiping
///   the keyboard presses other keys constantly.
final class EmergencyExit {
    static let comboKeys: Set<Int> = [53, 51] // esc, delete
    static let holdTime: TimeInterval = 3

    /// Called with the moment the hold began, or nil when it's cancelled or finished.
    var onHoldChanged: ((Date?) -> Void)?
    /// Called once the combination has been held long enough.
    var onTrigger: (() -> Void)?

    private var down: Set<Int> = []
    private var timer: Timer?

    func keyDown(_ code: Int) {
        down.insert(code)
        if Self.comboKeys.contains(code) {
            update()
        } else {
            cancel()
        }
    }

    func keyUp(_ code: Int) {
        down.remove(code)
        update()
    }

    /// A modifier (shift, command, fn...) changed. Treat it like any other stray key.
    func otherKeyPressed() {
        cancel()
    }

    func reset() {
        down.removeAll()
        cancel()
    }

    private func update() {
        if Self.comboKeys.isSubset(of: down) {
            if timer == nil { begin() }
        } else {
            cancel()
        }
    }

    private func begin() {
        let timer = Timer(timeInterval: Self.holdTime, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.timer = nil
            self.down.removeAll()
            self.onHoldChanged?(nil)
            self.onTrigger?()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        onHoldChanged?(Date())
    }

    private func cancel() {
        guard let timer else { return }
        timer.invalidate()
        self.timer = nil
        onHoldChanged?(nil)
    }
}
