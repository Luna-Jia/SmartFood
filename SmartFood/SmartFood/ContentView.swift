//
//  ContentView.swift
//  SmartFood
//
//  Created by Luna Jia on 7/12/24.
//

import SwiftUI
import CoreData
import AVFoundation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isShowingScanner = false
    @State private var scannedFood: Food?
    @State private var isPresentingEditView = false
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FoodEntity.name, ascending: true)],
        animation: .default)
    private var savedFoods: FetchedResults<FoodEntity>

    var body: some View {
        NavigationView {
            List {
                Button("Scan Barcode") {
                    isShowingScanner = true
                }
                
                if let food = scannedFood {
                    Section(header: Text("Scanned Food")) {
                        FoodRow(food: food)
                        Button("Edit and Save to Pantry") {
                            isPresentingEditView = true
                        }
                    }
                }
                
                Section(header: Text("Saved Foods")) {
                    ForEach(savedFoods) { foodEntity in
                        FoodRow(food: foodEntityToFood(foodEntity))
                    }
                    .onDelete(perform: deleteFoods)
                }
            }
            .navigationTitle("Smart Food")
            .sheet(isPresented: $isShowingScanner) {
                BarcodeScannerView(scannedCode: Binding(
                    get: { self.scannedFood?.barcode },
                    set: { if let code = $0 { self.fetchNutritionInfo(for: code) } }
                ))
            }
            .sheet(isPresented: $isPresentingEditView) {
                if let food = scannedFood {
                    EditFoodView(food: food) { editedFood in
                        saveFood(editedFood)
                        isPresentingEditView = false
                    }
                }
            }
        }
    }
    
    private func fetchNutritionInfo(for barcode: String) {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let product = json["product"] as? [String: Any],
                   let productName = product["product_name"] as? String,
                   let nutrients = product["nutriments"] as? [String: Any] {
                    
                    let servingSize = product["serving_size"] as? String ?? "N/A"
                    let servingSizeGrams = (product["serving_quantity"] as? Double) ?? 100.0
                    
                    func getNutrientInfo(_ key: String, unit: String) -> NutrientInfo {
                        let amount = (nutrients["\(key)_100g"] as? Double ?? 0) * (servingSizeGrams / 100.0)
                        let percentDailyValue = nutrients["\(key)_value"] as? Double
                        return NutrientInfo(amount: amount, unit: unit, percentDailyValue: percentDailyValue)
                    }
                    
                    let nutritionFacts = NutritionFacts(
                        calories: (nutrients["energy-kcal_100g"] as? Double ?? 0) * (servingSizeGrams / 100.0),
                        totalFat: getNutrientInfo("fat", unit: "g"),
                        saturatedFat: getNutrientInfo("saturated-fat", unit: "g"),
                        transFat: getNutrientInfo("trans-fat", unit: "g"),
                        cholesterol: getNutrientInfo("cholesterol", unit: "mg"),
                        sodium: getNutrientInfo("sodium", unit: "mg"),
                        totalCarbohydrate: getNutrientInfo("carbohydrates", unit: "g"),
                        dietaryFiber: getNutrientInfo("fiber", unit: "g"),
                        totalSugars: getNutrientInfo("sugars", unit: "g"),
                        addedSugars: getNutrientInfo("added-sugars", unit: "g"),
                        protein: getNutrientInfo("proteins", unit: "g"),
                        vitaminD: getNutrientInfo("vitamin-d", unit: "µg"),
                        calcium: getNutrientInfo("calcium", unit: "mg"),
                        iron: getNutrientInfo("iron", unit: "mg"),
                        potassium: getNutrientInfo("potassium", unit: "mg")
                    )
                    
                    DispatchQueue.main.async {
                        self.scannedFood = Food(
                            id: UUID(),
                            barcode: barcode,
                            name: productName,
                            servingSize: servingSize,
                            servingSizeGrams: servingSizeGrams,
                            nutritionFacts: nutritionFacts
                        )
                    }
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func saveFood(_ food: Food) {
        let newFood = FoodEntity(context: viewContext)
        newFood.id = food.id
        newFood.barcode = food.barcode
        newFood.name = food.name
        newFood.servingSize = food.servingSize
        newFood.servingSizeGrams = food.servingSizeGrams
        newFood.nutritionFacts = try? JSONEncoder().encode(food.nutritionFacts)
        
        do {
            try viewContext.save()
            scannedFood = nil // Clear the scanned food after saving
        } catch {
            print("Error saving food: \(error)")
        }
    }
    
    private func deleteFoods(offsets: IndexSet) {
        withAnimation {
            offsets.map { savedFoods[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting food: \(error)")
            }
        }
    }
    
    private func foodEntityToFood(_ entity: FoodEntity) -> Food {
        let nutritionFacts: NutritionFacts
        if let nutritionFactsData = entity.nutritionFacts,
           let decodedNutritionFacts = try? JSONDecoder().decode(NutritionFacts.self, from: nutritionFactsData) {
            nutritionFacts = decodedNutritionFacts
        } else {
            nutritionFacts = .empty
        }
        
        return Food(
            id: entity.id ?? UUID(),
            barcode: entity.barcode ?? "",
            name: entity.name ?? "",
            servingSize: entity.servingSize ?? "",
            servingSizeGrams: entity.servingSizeGrams,
            nutritionFacts: nutritionFacts
        )
    }
}

struct FoodRow: View {
    let food: Food
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(food.name).font(.headline)
            Text("Serving: \(food.servingSize)")
            Text("Calories: \(food.nutritionFacts.calories, specifier: "%.0f") kcal")
            Text("Total Fat: \(food.nutritionFacts.totalFat.amount, specifier: "%.1f")g (\(food.nutritionFacts.totalFat.percentDailyValue ?? 0, specifier: "%.0f")% DV)")
            Text("Total Carbs: \(food.nutritionFacts.totalCarbohydrate.amount, specifier: "%.1f")g (\(food.nutritionFacts.totalCarbohydrate.percentDailyValue ?? 0, specifier: "%.0f")% DV)")
            Text("Protein: \(food.nutritionFacts.protein.amount, specifier: "%.1f")g")
        }
    }
}

struct EditFoodView: View {
    @State private var editedFood: Food
    let onSave: (Food) -> Void
    
    init(food: Food, onSave: @escaping (Food) -> Void) {
        _editedFood = State(initialValue: food)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General Info")) {
                    TextField("Name", text: $editedFood.name)
                    TextField("Serving Size", text: $editedFood.servingSize)
                    TextField("Serving Size (g)", value: $editedFood.servingSizeGrams, formatter: NumberFormatter())
                }
                
                Section(header: Text("Nutrition Facts")) {
                    NutrientRow(name: "Calories", value: $editedFood.nutritionFacts.calories, unit: "kcal")
                    NutrientInfoRow(name: "Total Fat", nutrientInfo: $editedFood.nutritionFacts.totalFat)
                    NutrientInfoRow(name: "Saturated Fat", nutrientInfo: $editedFood.nutritionFacts.saturatedFat)
                    NutrientInfoRow(name: "Trans Fat", nutrientInfo: $editedFood.nutritionFacts.transFat)
                    NutrientInfoRow(name: "Cholesterol", nutrientInfo: $editedFood.nutritionFacts.cholesterol)
                    NutrientInfoRow(name: "Sodium", nutrientInfo: $editedFood.nutritionFacts.sodium)
                    NutrientInfoRow(name: "Total Carbohydrate", nutrientInfo: $editedFood.nutritionFacts.totalCarbohydrate)
                    NutrientInfoRow(name: "Dietary Fiber", nutrientInfo: $editedFood.nutritionFacts.dietaryFiber)
                    NutrientInfoRow(name: "Total Sugars", nutrientInfo: $editedFood.nutritionFacts.totalSugars)
                    NutrientInfoRow(name: "Added Sugars", nutrientInfo: $editedFood.nutritionFacts.addedSugars)
                    NutrientInfoRow(name: "Protein", nutrientInfo: $editedFood.nutritionFacts.protein)
                    NutrientInfoRow(name: "Vitamin D", nutrientInfo: $editedFood.nutritionFacts.vitaminD)
                    NutrientInfoRow(name: "Calcium", nutrientInfo: $editedFood.nutritionFacts.calcium)
                    NutrientInfoRow(name: "Iron", nutrientInfo: $editedFood.nutritionFacts.iron)
                    NutrientInfoRow(name: "Potassium", nutrientInfo: $editedFood.nutritionFacts.potassium)
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarItems(trailing: Button("Save") {
                onSave(editedFood)
            })
        }
    }
}

struct NutrientRow: View {
    let name: String
    @Binding var value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            TextField("", value: $value, formatter: NumberFormatter())
                .multilineTextAlignment(.trailing)
            Text(unit)
        }
    }
}

struct NutrientInfoRow: View {
    let name: String
    @Binding var nutrientInfo: NutrientInfo
    
    var body: some View {
        VStack {
            HStack {
                Text(name)
                Spacer()
                TextField("", value: $nutrientInfo.amount, formatter: NumberFormatter())
                    .multilineTextAlignment(.trailing)
                Text(nutrientInfo.unit)
            }
            if nutrientInfo.percentDailyValue != nil {
                HStack {
                    Text("% Daily Value")
                    Spacer()
                    TextField("", value: $nutrientInfo.percentDailyValue, formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                    Text("%")
                }
            }
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return viewController
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .qr]
        } else {
            return viewController
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)

        captureSession.startRunning()

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: BarcodeScannerView

        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject else { return }

            if metadataObject.type == .ean8 || metadataObject.type == .ean13 || metadataObject.type == .qr {
                parent.scannedCode = metadataObject.stringValue
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
