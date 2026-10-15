import Foundation
import CoreLocation
import MapKit
import Observation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.location = locations.last
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }

    /// Search for places matching a textual query around a given center
    static func searchPlaces(query: String, near location: CLLocation? = nil) async -> [MKMapItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let location {
            request.region = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            return []
        }
    }

    /// Reverse geocode a location into a friendly place or neighborhood name
    static func reverseGeocode(location: CLLocation) async -> String? {
        if let request = MKReverseGeocodingRequest(location: location) {
            if let mapItems = try? await request.mapItems, let first = mapItems.first {
                return first.name
            }
        }
        return nil
    }
}
