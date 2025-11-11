// ReMind/Payment/PaywallConfig.swift
import Foundation

/// Central place for your RevenueCat & product identifiers.
enum PaywallConfig {
    /// RevenueCat Public SDK Key (Project → API Keys → Public)
    static let rcPublicSDKKey   = "appl_vnzSILoPFwksIabfHvzrSpKObNh"

    /// RevenueCat dashboard identifiers
    static let entitlementId    = "pro"
    static let offeringId       = "default"
    static let packageId        = "monthly"

    /// App Store Connect product id (must match ASC & RC exactly)
    static let productId        = "remind.monthly.099.us"
}
