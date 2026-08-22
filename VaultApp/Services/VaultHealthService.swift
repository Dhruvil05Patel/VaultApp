import Foundation

// VaultHealthService analyses the vault and produces a health report.
// Pure computation — no network, no disk I/O.
enum VaultHealthService {

    // MARK: - Report

    struct HealthReport {
        let score: Int                          // 0–100
        let grade: Grade
        let weakPasswords: [VaultItem]          // strength == .weak or .fair
        let reusedPasswords: [ReusedGroup]
        let oldPasswords: [VaultItem]           // not changed in > 180 days
        let missingTOTP: [VaultItem]            // login items with no 2FA
        let breachedItems: [VaultItem]          // breach status == .breached
        let totalItems: Int

        struct ReusedGroup {
            let password: String                // masked in UI
            let items: [VaultItem]
        }

        enum Grade: String {
            case aPlus = "A+"
            case a     = "A"
            case b     = "B"
            case c     = "C"
            case d     = "D"
            case f     = "F"

            var color: String {
                switch self {
                case .aPlus, .a: return "green"
                case .b:         return "blue"
                case .c:         return "yellow"
                case .d:         return "orange"
                case .f:         return "red"
                }
            }
        }
    }

    // MARK: - Analyse

    static func analyse(vault: Vault) -> HealthReport {
        let loginItems = vault.items.filter { $0.category == .login }
        let total = loginItems.count

        guard total > 0 else {
            return HealthReport(score: 100, grade: .aPlus, weakPasswords: [],
                                reusedPasswords: [], oldPasswords: [], missingTOTP: [],
                                breachedItems: [], totalItems: 0)
        }

        // 1. Weak passwords
        let weak = loginItems.filter {
            let s = PasswordGenerator.strength(of: $0.password)
            return s == .weak || s == .fair
        }

        // 2. Reused passwords (group by password value)
        let groups = Dictionary(grouping: loginItems, by: { $0.password })
        let reused = groups
            .filter { $0.value.count > 1 && !$0.key.isEmpty }
            .map { HealthReport.ReusedGroup(password: $0.key, items: $0.value) }
            .sorted { $0.items.count > $1.items.count }

        // 3. Old passwords (>180 days since last change or creation)
        let cutoff = Date().addingTimeInterval(-180 * 86400)
        let old = loginItems.filter {
            ($0.lastPasswordChangedAt ?? $0.createdAt) < cutoff
        }

        // 4. Missing 2FA
        let noTOTP = loginItems.filter { !$0.hasTOTP }

        // 5. Breached
        let breached = loginItems.filter { $0.breachStatus == .breached }

        // 6. Score calculation
        let weakPenalty    = min(30, weak.count * 5)
        let reusedPenalty  = min(20, reused.flatMap { $0.items }.count * 3)
        let oldPenalty     = min(15, old.count * 2)
        let totpPenalty    = min(15, noTOTP.count * 1)
        let breachPenalty  = min(30, breached.count * 10)
        let totalPenalty   = weakPenalty + reusedPenalty + oldPenalty + totpPenalty + breachPenalty
        let score          = max(0, 100 - totalPenalty)

        let grade: HealthReport.Grade
        switch score {
        case 95...100: grade = .aPlus
        case 85...94:  grade = .a
        case 70...84:  grade = .b
        case 55...69:  grade = .c
        case 40...54:  grade = .d
        default:       grade = .f
        }

        return HealthReport(
            score: score, grade: grade,
            weakPasswords: weak,
            reusedPasswords: reused,
            oldPasswords: old,
            missingTOTP: noTOTP,
            breachedItems: breached,
            totalItems: total
        )
    }
}
