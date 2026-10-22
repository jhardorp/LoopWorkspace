// Appended only to the pinned upstream Simulator test file by prepare_checks.py.
// Uses that file's temporary-store helpers; no application code is changed.
extension PersistenceControllerMigrationTests {
    func testProductionV4SettingsAndHistorySurviveUpgrade() throws {
        try assertProductionMigration(childModel: false)
    }

    func testProductionV4NonDefaultInsulinModelSurvivesUpgrade() throws {
        try assertProductionMigration(childModel: true)
    }

    private func assertProductionMigration(childModel: Bool) throws {
        let originalData = Data(base64Encoded: "LEGACY_SETTINGS_BASE64")!
        var legacy = try XCTUnwrap(PropertyListSerialization.propertyList(from: originalData, format: nil) as? [String: Any])
        if childModel {
            var model = try XCTUnwrap(legacy["defaultRapidActingModel"] as? [String: Any])
            model["modelType"] = "rapidChild"
            legacy["defaultRapidActingModel"] = model
        }
        let data = try PropertyListSerialization.data(fromPropertyList: legacy, format: .binary, options: 0)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try createStore(modelNamed: "Modelv4") { context in
            self.insert("SettingsObject", into: context, values: [
                "data": data, "date": date, "modificationCounter": 42
            ])
            self.insert("CachedCarbObject", into: context, values: [
                "grams": 42.5, "absorptionTime": 5400.0, "foodType": "Two large slices of bread",
                "startDate": date, "syncIdentifier": "legacy-meal", "syncVersion": 3,
                "createdByCurrentApp": true
            ])
            self.insert("CachedGlucoseObject", into: context, values: [
                "value": 154.0, "unitString": "mg/dL", "startDate": date,
                "syncIdentifier": "legacy-glucose", "syncVersion": 2
            ])
        }
        // Open twice: the second launch must neither rerun destructively nor duplicate entries.
        for _ in 0..<2 {
            let cache = try openCacheStore()
            defer { closePreservingMigratedStore(cache) }
            let settings = try XCTUnwrap(SettingsStore(store: cache, expireAfter: .hours(24)).latestSettings)
            let encoded = try PropertyListEncoder().encode(settings)
            let restored = try XCTUnwrap(PropertyListSerialization.propertyList(from: encoded, format: nil) as? [String: Any])
            for key in ["date", "controllerTimeZone", "dosingEnabled", "automaticDosingStrategy",
                        "basalRateSchedule", "carbRatioSchedule", "insulinSensitivitySchedule",
                        "maximumBasalRatePerHour", "maximumBolus", "suspendThreshold", "preMealTargetRange",
                        "insulinType", "defaultRapidActingModel", "bloodGlucoseUnit", "syncIdentifier",
                        "pumpDevice", "cgmDevice", "controllerDevice", "notificationSettings"] {
                XCTAssertEqual(restored[key] as? NSObject, legacy[key] as? NSObject, "Changed legacy field: \(key)")
            }
            let oldTargets = try XCTUnwrap(legacy["glucoseTargetRangeSchedule"] as? [String: Any])
            let newTargets = try XCTUnwrap(restored["glucoseTargetRangeSchedule"] as? [String: Any])
            XCTAssertEqual(newTargets["rangeSchedule"] as? NSDictionary, oldTargets["rangeSchedule"] as? NSDictionary)
            XCTAssertEqual(settings.overridePresets.count, 1)
            XCTAssertEqual(settings.overridePresets.first?.name, "Apple")
            XCTAssertEqual(settings.overridePresets.first?.symbol?.textualRepresentation, "🍎")
            XCTAssertEqual(settings.overridePresets.first?.settings.insulinNeedsScaleFactor, 2)
            try cache.managedObjectContext.performAndWait {
                let carbs = try cache.managedObjectContext.fetch(CachedCarbObject.fetchRequest())
                XCTAssertEqual(carbs.count, 1)
                let meal = try XCTUnwrap(carbs.first)
                XCTAssertEqual(meal.grams, 42.5)
                XCTAssertEqual(meal.absorptionTime, 5400)
                XCTAssertEqual(meal.foodType, "Two large slices of bread")
                XCTAssertEqual(meal.startDate, date)
                XCTAssertEqual(meal.syncIdentifier, "legacy-meal")
                XCTAssertEqual(meal.syncVersion, 3)
                let glucose = try cache.managedObjectContext.fetch(CachedGlucoseObject.fetchRequest())
                XCTAssertEqual(glucose.count, 1)
                XCTAssertEqual(glucose.first?.value, 154)
                XCTAssertEqual(glucose.first?.syncIdentifier, "legacy-glucose")
                XCTAssertEqual(try cache.managedObjectContext.count(for: SettingsObject.fetchRequest()), 1)
            }
        }
    }

    private func closePreservingMigratedStore(_ cache: PersistenceController) {
        // The upstream test tearDown() also destroys the SQLite file. A launch
        // regression must detach its coordinator while preserving that file.
        XCTAssertNoThrow(try cache.managedObjectContext.performAndWait {
            let coordinator = try XCTUnwrap(cache.managedObjectContext.persistentStoreCoordinator)
            cache.managedObjectContext.reset()
            for store in coordinator.persistentStores {
                try coordinator.remove(store)
            }
        })
    }
}
