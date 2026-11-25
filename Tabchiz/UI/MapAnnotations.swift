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
        case .dimmed, .overview:
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

/// A place in the overview: a small dot in its tab's color.
final class OverviewDotView: MKAnnotationView {
    static let reuseID = "overviewDot"
    /// Larger than the dot, so the dot is easier to tap.
    private static let side: CGFloat = 26
    private static let dotSide: CGFloat = 16

    private let dot = UIView()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        addDot()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addDot()
    }

    private func addDot() {
        bounds = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        let inset = (Self.side - Self.dotSide) / 2
        dot.frame = bounds.insetBy(dx: inset, dy: inset)
        dot.layer.cornerRadius = Self.dotSide / 2
        dot.layer.borderColor = UIColor.white.cgColor
        dot.layer.borderWidth = 2
        dot.isUserInteractionEnabled = false
        addSubview(dot)
        collisionMode = .circle
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let pin = (annotation as? PlaceAnnotation)?.pin else { return }
        dot.backgroundColor = pin.color.uiColor
        displayPriority = .required
        canShowCallout = false
        isAccessibilityElement = true
        accessibilityLabel = "\(pin.tabName) \(pin.place.name)"
        accessibilityIdentifier = "overviewPin.\(pin.tabIndex).\(pin.place.id.rawValue)"
        accessibilityTraits = .button
    }
}

/// Places of one tab that would overlap in the overview: a bubble in the tab's color with their count. A cluster
/// never mixes tabs.
final class OverviewClusterView: MKAnnotationView {
    static let reuseID = "overviewCluster"
    /// Bubbles of different tabs at the same spot are fanned apart by this distance, so each count stays readable.
    private static let fanRadius: CGFloat = 11

    private let bubble = UIView()
    private let count = UILabel()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        addBubble()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addBubble()
    }

    private func addBubble() {
        bubble.layer.borderColor = UIColor.white.cgColor
        bubble.layer.borderWidth = 2
        bubble.isUserInteractionEnabled = false
        count.font = .systemFont(ofSize: 15, weight: .bold)
        count.textColor = .white
        count.textAlignment = .center
        bubble.addSubview(count)
        addSubview(bubble)
        collisionMode = .circle
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let pins = cluster.memberAnnotations.compactMap { ($0 as? PlaceAnnotation)?.pin }
        guard let first = pins.first else { return }
        let side: CGFloat = pins.count >= 10 ? 38 : 32
        bounds = CGRect(x: 0, y: 0, width: side, height: side)
        bubble.frame = bounds
        bubble.layer.cornerRadius = side / 2
        bubble.backgroundColor = first.color.uiColor
        count.frame = bubble.bounds
        count.text = "\(pins.count)"
        let angle = 2 * CGFloat.pi * CGFloat(first.tabIndex) / CGFloat(TabColor.allCases.count)
        centerOffset = CGPoint(x: Self.fanRadius * sin(angle), y: -Self.fanRadius * cos(angle))
        displayPriority = .required
        canShowCallout = false
        isAccessibilityElement = true
        accessibilityLabel = "\(first.tabName) \(pins.count)件"
        accessibilityIdentifier = "overviewCluster.\(first.tabIndex)"
        accessibilityTraits = .button
    }
}
