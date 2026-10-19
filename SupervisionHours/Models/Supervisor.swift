import Foundation
import SwiftData

@Model
final class Supervisor {
    var id: UUID = UUID()
    var name: String = ""
    var credentials: String = ""
    var licenseNumber: String = ""
    var email: String = ""
    var phone: String = ""
    var notes: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(name: String, credentials: String = "", licenseNumber: String = "") {
        self.id = UUID()
        self.name = name
        self.credentials = credentials
        self.licenseNumber = licenseNumber
        self.createdAt = .now
    }

    /// "Elena Ruiz, LPC-S"
    var title: String { credentials.isEmpty ? name : "\(name), \(credentials)" }
}
