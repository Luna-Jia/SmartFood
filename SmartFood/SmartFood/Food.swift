//
//  Food.swift
//  SmartFood
//
//  Created by Luna Jia on 7/12/24.
//

import Foundation

struct Food: Identifiable, Codable {
    var id: UUID
    var barcode: String
    var name: String
    var servingSize: String
    var servingSizeGrams: Double
    var nutritionFacts: NutritionFacts
}

struct NutritionFacts: Codable {
    var calories: Double
    var totalFat: NutrientInfo
    var saturatedFat: NutrientInfo
    var transFat: NutrientInfo
    var cholesterol: NutrientInfo
    var sodium: NutrientInfo
    var totalCarbohydrate: NutrientInfo
    var dietaryFiber: NutrientInfo
    var totalSugars: NutrientInfo
    var addedSugars: NutrientInfo
    var protein: NutrientInfo
    var vitaminD: NutrientInfo
    var calcium: NutrientInfo
    var iron: NutrientInfo
    var potassium: NutrientInfo
}

struct NutrientInfo: Codable {
    var amount: Double
    var unit: String
    var percentDailyValue: Double?
}

extension NutritionFacts {
    static var empty: NutritionFacts {
        NutritionFacts(
            calories: 0,
            totalFat: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            saturatedFat: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            transFat: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            cholesterol: NutrientInfo(amount: 0, unit: "mg", percentDailyValue: nil),
            sodium: NutrientInfo(amount: 0, unit: "mg", percentDailyValue: nil),
            totalCarbohydrate: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            dietaryFiber: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            totalSugars: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            addedSugars: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            protein: NutrientInfo(amount: 0, unit: "g", percentDailyValue: nil),
            vitaminD: NutrientInfo(amount: 0, unit: "µg", percentDailyValue: nil),
            calcium: NutrientInfo(amount: 0, unit: "mg", percentDailyValue: nil),
            iron: NutrientInfo(amount: 0, unit: "mg", percentDailyValue: nil),
            potassium: NutrientInfo(amount: 0, unit: "mg", percentDailyValue: nil)
        )
    }
}
