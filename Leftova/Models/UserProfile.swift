//
//  UserProfile.swift
//  Leftova
//
//  Created by Zach Rich on 8/7/25.
//


// File: Models/SubscriptionModels.swift
// Proper Codable models for Supabase operations

import Foundation

// MARK: - User Profile Model
struct UserProfile: Codable {
    let id: String
    let email: String
    let subscriptionTier: String
    let subscriptionStatus: String
    let trialEndsAt: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case subscriptionTier = "subscription_tier"
        case subscriptionStatus = "subscription_status"
        case trialEndsAt = "trial_ends_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - User Profile Update
struct UserProfileUpdate: Codable {
    let subscriptionTier: String
    let subscriptionStatus: String
    
    enum CodingKeys: String, CodingKey {
        case subscriptionTier = "subscription_tier"
        case subscriptionStatus = "subscription_status"
    }
}

// MARK: - User Subscription Model
struct UserSubscription: Codable {
    let id: String?
    let userId: String
    let appleTransactionId: String
    let productId: String
    let status: String
    let currentPeriodStart: String
    let currentPeriodEnd: String
    let canceledAt: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case appleTransactionId = "apple_transaction_id"
        case productId = "product_id"
        case status
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case canceledAt = "canceled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Subscription Update Model
struct SubscriptionUpdate: Codable {
    let status: String
    let canceledAt: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case canceledAt = "canceled_at"
    }
}

// MARK: - Create Profile Model (for initial creation)
struct CreateUserProfile: Codable {
    let id: String
    let email: String
    let subscriptionTier: String = "free"
    let subscriptionStatus: String = "inactive"
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case subscriptionTier = "subscription_tier"
        case subscriptionStatus = "subscription_status"
    }
}