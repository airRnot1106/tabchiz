import MapKit
import UIKit

final class PlaceAnnotation: NSObject, MKAnnotation {
    let pin: MapContent.Pin
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(_ pin: MapContent.Pin) {
        self.pin = pin
        coordinate = pin.place.coordinate.clCoordinate
        title = pin.place.name
        if case .nearest(let distance) = pin.role {
            subtitle = DistanceText.straightLine(distance)
        } else {
            subtitle = nil
        }
    }
}

/// A system balloon marker in the tab's color with the tab's symbol. The viewed place and the nearest places of
/// the other tabs always show their names, and a nearest place also shows its straight-line distance. The tab's
/// other places stay in the background while a place is viewed.
final class PlaceMarkerView: MKMarkerAnnotationView {
    static let reuseID = "place"

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let place = annotation as? PlaceAnnotation else { return }
        let pin = place.pin
        markerTintColor = pin.color.uiColor
        glyphImage = UIImage(systemName: pin.symbolName)
        // The balloon's round head, so markers cluster only where the heads overlap.
        collisionMode = .circle
        canShowCallout = false
        switch pin.role {
        case .normal:
            alpha = 1
            displayPriority = .required
            zPriority = .defaultUnselected
            titleVisibility = .adaptive
            subtitleVisibility = .hidden
        case .selected, .nearest:
            alpha = 1
            displayPriority = .required
            zPriority = .max
            selectedZPriority = .max
            titleVisibility = .visible
            subtitleVisibility = .visible
        case .dimmed:
            alpha = 0.35
            displayPriority = .defaultLow
            zPriority = .min
            titleVisibility = .hidden
            subtitleVisibility = .hidden
        }
        isAccessibilityElement = true
        accessibilityLabel = [pin.tabName, pin.place.name, place.subtitle].compactMap(\.self).joined(separator: " ")
        accessibilityIdentifier = "pin.\(pin.place.id.rawValue)"
        accessibilityTraits = .button
    }
}

/// Places of the tab on screen that would overlap, as one marker in the tab's color with their count.
final class PlaceClusterView: MKMarkerAnnotationView {
    static let reuseID = "cluster"

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let pins = cluster.memberAnnotations.compactMap { ($0 as? PlaceAnnotation)?.pin }
        let isDimmed = pins.allSatisfy { $0.role == .dimmed }
        markerTintColor = pins.first?.color.uiColor
        glyphText = "\(pins.count)"
        alpha = isDimmed ? 0.35 : 1
        displayPriority = isDimmed ? .defaultLow : .required
        zPriority = isDimmed ? .min : .defaultUnselected
        titleVisibility = .hidden
        subtitleVisibility = .hidden
        canShowCallout = false
        isAccessibilityElement = true
        accessibilityLabel = "\(pins.first?.tabName ?? "") \(pins.count)件"
        accessibilityIdentifier = "cluster.\(pins.first?.tabName ?? "")"
        accessibilityTraits = .button
    }
}
