//
//  User.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//


import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String?
    let emailConfirmedAt: Date?
    let lastSignInAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailConfirmedAt = "email_confirmed_at"
        case lastSignInAt = "last_sign_in_at"
    }
}