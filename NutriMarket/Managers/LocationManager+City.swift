import CoreLocation

class CityResolver {
    static func resolve(location: CLLocation) async -> (city: String, region: String) {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            let city = placemark?.locality ?? placemark?.subAdministrativeArea ?? "Desconhecido"
            let region = placemark?.administrativeArea ?? ""
            return (city, region)
        } catch {
            return ("Desconhecido", "")
        }
    }
}
