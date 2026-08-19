import Foundation
import CoreLocation
import Combine

// GeofenceService checks whether the current device location
// is within any configured geofence zones.
// All location checks are local — no data leaves the device.
@MainActor
final class GeofenceService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = GeofenceService()

    @Published var currentLocation: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isInsideZones: Set<UUID> = []  // geofence IDs currently active

    private let locationManager = CLLocationManager()

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50  // update only when moved 50m
    }

    // MARK: - Request Permission & Start

    func requestPermission() {
        #if os(macOS)
        locationManager.requestAlwaysAuthorization()
        #else
        locationManager.requestWhenInUseAuthorization()
        #endif
    }

    func startMonitoring() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        locationManager.startUpdatingLocation()
    }

    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Check if inside a geofence

    func isInside(_ geofence: Geofence) -> Bool {
        guard let location = currentLocation else { return false }
        let center = CLLocation(latitude: geofence.latitude, longitude: geofence.longitude)
        return location.distance(from: center) <= geofence.radiusMeters
    }

    // MARK: - Update active zones for all folders

    func updateActiveZones(folders: [VaultFolder]) {
        isInsideZones = Set(
            folders.compactMap { folder -> UUID? in
                guard let geofence = folder.geofence else { return nil }
                return isInside(geofence) ? geofence.id : nil
            }
        )
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.updateActiveZones(folders: VaultManager.shared.vault.folders)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            #if os(macOS)
            let isAuthorized = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized
            #else
            let isAuthorized = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
            #endif
            
            if isAuthorized {
                self.startMonitoring()
            }
        }
    }

    // MARK: - Capture current location as geofence center

    func captureCurrentLocation(name: String, radius: Double) async -> Geofence? {
        guard let location = currentLocation else { return nil }
        return Geofence(
            id: UUID(),
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusMeters: radius
        )
    }
}
