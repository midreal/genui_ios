import UIKit
import Combine
import MapKit

/// A map component for showing a single location marker.
///
/// Parameters:
/// - `latitude`: Number reference.
/// - `longitude`: Number reference.
/// - `zoom`: Optional number reference (default 14).
/// - `tileUrlTemplate`: Optional (not used on iOS, uses Apple Maps).
enum MapComponent {

    private static let aspectRatio: CGFloat = 1.8
    private static let cornerRadius: CGFloat = 16
    private static let borderColor = MacaronColors.cardBorder
    private static let cardColor = MacaronColors.cardBackground
    private static let markerColor = MacaronColors.selectionActive
    private static let defaultZoom: Double = 14

    static func register() -> CatalogItem {
        CatalogItem(name: "Map") { context in
            let wrapper = BindableView()

            let frameView = UIView()
            frameView.backgroundColor = cardColor
            frameView.layer.cornerRadius = cornerRadius
            frameView.layer.borderWidth = 1
            frameView.layer.borderColor = borderColor.cgColor
            frameView.clipsToBounds = true

            wrapper.embed(frameView)
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            frameView.translatesAutoresizingMaskIntoConstraints = false
            frameView.widthAnchor.constraint(equalTo: frameView.heightAnchor, multiplier: aspectRatio).isActive = true

            let mapView = MKMapView()
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = true
            mapView.isPitchEnabled = false
            mapView.isRotateEnabled = false
            mapView.translatesAutoresizingMaskIntoConstraints = false
            frameView.addSubview(mapView)
            NSLayoutConstraint.activate([
                mapView.topAnchor.constraint(equalTo: frameView.topAnchor),
                mapView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
                mapView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
                mapView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),
            ])

            let placeholderLabel = UILabel()
            placeholderLabel.text = "Coordinates unavailable"
            placeholderLabel.font = .systemFont(ofSize: 14, weight: .semibold)
            placeholderLabel.textColor = MacaronColors.secondary
            placeholderLabel.textAlignment = .center
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            placeholderLabel.isHidden = true
            frameView.addSubview(placeholderLabel)
            NSLayoutConstraint.activate([
                placeholderLabel.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
                placeholderLabel.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),
            ])

            let latPub = BoundValueHelpers.resolveNumber(context.data["latitude"], context: context.dataContext)
            let lngPub = BoundValueHelpers.resolveNumber(context.data["longitude"], context: context.dataContext)
            let zoomPub = BoundValueHelpers.resolveNumber(context.data["zoom"], context: context.dataContext)

            let annotation = MKPointAnnotation()

            let cancellable = latPub.combineLatest(lngPub, zoomPub)
                .receive(on: DispatchQueue.main)
                .sink { [weak mapView, weak placeholderLabel] rawLat, rawLng, rawZoom in
                    guard let mapView = mapView, let placeholder = placeholderLabel else { return }

                    guard let lat = rawLat, let lng = rawLng,
                          lat.isFinite, lng.isFinite else {
                        mapView.isHidden = true
                        placeholder.isHidden = false
                        return
                    }

                    mapView.isHidden = false
                    placeholder.isHidden = true

                    let normalizedLat = min(max(lat, -90), 90)
                    var normalizedLng = lng.truncatingRemainder(dividingBy: 360)
                    if normalizedLng > 180 { normalizedLng -= 360 }
                    else if normalizedLng < -180 { normalizedLng += 360 }

                    let coord = CLLocationCoordinate2D(latitude: normalizedLat, longitude: normalizedLng)
                    annotation.coordinate = coord

                    mapView.removeAnnotations(mapView.annotations)
                    mapView.addAnnotation(annotation)

                    let zoom = min(max(rawZoom ?? defaultZoom, 1), 19)
                    let span = zoomToSpan(zoom)
                    let region = MKCoordinateRegion(center: coord, span: span)
                    mapView.setRegion(region, animated: false)
                }
            wrapper.storeCancellable(cancellable)
            return wrapper
        }
    }

    private static func zoomToSpan(_ zoom: Double) -> MKCoordinateSpan {
        let degrees = 360.0 / pow(2.0, zoom)
        return MKCoordinateSpan(latitudeDelta: degrees, longitudeDelta: degrees)
    }
}
