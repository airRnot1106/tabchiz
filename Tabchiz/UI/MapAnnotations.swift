import MapKit
import UIKit

final class SpotAnnotation: NSObject, MKAnnotation {
    let marker: MapContent.Marker
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(_ marker: MapContent.Marker) {
        self.marker = marker
        coordinate = marker.spot.coordinate.clCoordinate
        title = marker.spot.name
        if case .nearest(let distance) = marker.role {
            subtitle = DistanceText.straightLine(distance)
        } else {
            subtitle = nil
        }
    }
}

extension MKClusterAnnotation {
    /// The markers of the places the cluster stands for.
    var markers: [MapContent.Marker] {
        memberAnnotations.compactMap { ($0 as? SpotAnnotation)?.marker }
    }
}

/// A pin: a system balloon marker in the tab's color with a pin glyph, larger than a search result's marker. It
/// always shows, in front of the search results, and never joins a cluster. Its name sits on a plate of its own
/// under the balloon, because the names MapKit draws end up behind the overview's dots and bubbles. The nearest
/// pin of another tab also shows its distance there.
final class PinMarkerView: MKMarkerAnnotationView {
    static let reuseID = "pin"
    /// How much larger than a search result's marker a pin is while it is not selected. MapKit enlarges the
    /// selected marker by itself.
    private static let scale: CGFloat = 1.35
    private static let plateWidth: CGFloat = 150

    private let plate = UIView()
    private let name = UILabel()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        addPlate()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addPlate()
    }

    private func addPlate() {
        plate.backgroundColor = .systemBackground.withAlphaComponent(0.88)
        plate.layer.cornerRadius = 6
        plate.isUserInteractionEnabled = false
        name.numberOfLines = 2
        name.textAlignment = .center
        name.lineBreakMode = .byTruncatingTail
        name.adjustsFontForContentSizeCategory = true
        plate.addSubview(name)
        addSubview(plate)
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let spot = annotation as? SpotAnnotation else { return }
        let marker = spot.marker
        markerTintColor = marker.color.uiColor
        glyphImage = UIImage(systemName: "mappin")
        collisionMode = .circle
        canShowCallout = false
        alpha = 1
        displayPriority = .required
        zPriority = .max
        selectedZPriority = .max
        titleVisibility = .hidden
        subtitleVisibility = .hidden
        name.attributedText = Self.plateText(name: marker.spot.name, distance: spot.subtitle)
        layOutPlate()
        isAccessibilityElement = true
        accessibilityLabel = [marker.tabName, "ピン", marker.spot.name, spot.subtitle]
            .compactMap(\.self)
            .joined(separator: " ")
        accessibilityIdentifier = "mapPin.\(marker.tabIndex).\(marker.spot.name)"
        accessibilityTraits = .button
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        layOutPlate()
    }

    private static func plateText(name: String, distance: String?) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: name,
            attributes: [.font: font(.caption1), .foregroundColor: UIColor.label]
        )
        if let distance {
            text.append(
                NSAttributedString(
                    string: "\n\(distance)",
                    attributes: [.font: font(.caption2), .foregroundColor: UIColor.secondaryLabel]
                )
            )
        }
        return text
    }

    /// The text style in semibold, no larger than the first accessibility size so the plate stays a map label.
    private static func font(_ style: UIFont.TextStyle) -> UIFont {
        let limit = UITraitCollection(preferredContentSizeCategory: .accessibilityMedium)
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        let size = min(descriptor.pointSize, UIFont.preferredFont(forTextStyle: style, compatibleWith: limit).pointSize)
        return .systemFont(ofSize: size, weight: .semibold)
    }

    /// Scales the balloon up from its tip, which stays on the coordinate, and puts the plate under the tip at
    /// its own size.
    private func layOutPlate() {
        let scale = isSelected ? 1 : Self.scale
        transform = CGAffineTransform(translationX: 0, y: -bounds.height * (scale - 1) / 2)
            .scaledBy(x: scale, y: scale)
        let fitted = name.sizeThatFits(CGSize(width: Self.plateWidth, height: .greatestFiniteMagnitude))
        let size = CGSize(width: min(fitted.width, Self.plateWidth), height: fitted.height)
        plate.bounds = CGRect(x: 0, y: 0, width: size.width + 10, height: size.height + 4)
        name.frame = plate.bounds.insetBy(dx: 5, dy: 2)
        plate.transform = CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)
        plate.center = CGPoint(x: bounds.midX, y: bounds.maxY + (plate.bounds.height / 2 + 4) / scale)
    }
}

/// A system balloon marker in the tab's color with the tab's symbol. The viewed place and the nearest places of
/// the other tabs always show their names, and a nearest place also shows its straight-line distance. The tab's
/// other places stay in the background while a place is viewed.
final class PlaceMarkerView: MKMarkerAnnotationView {
    static let reuseID = "place"

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let spot = annotation as? SpotAnnotation, case .place(let place) = spot.marker.spot else { return }
        let marker = spot.marker
        markerTintColor = marker.color.uiColor
        glyphImage = UIImage(systemName: marker.symbolName)
        // The balloon's round head, so markers cluster only where the heads overlap.
        collisionMode = .circle
        canShowCallout = false
        switch marker.role {
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
        accessibilityLabel = [marker.tabName, place.name, spot.subtitle].compactMap(\.self).joined(separator: " ")
        accessibilityIdentifier = "pin.\(place.id.rawValue)"
        accessibilityTraits = .button
    }
}

/// Places of the tab on screen that would overlap, as one marker in the tab's color with their count.
final class PlaceClusterView: MKMarkerAnnotationView {
    static let reuseID = "cluster"

    override func prepareForDisplay() {
        super.prepareForDisplay()
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let markers = cluster.markers
        let isDimmed = markers.allSatisfy { $0.role == .dimmed }
        markerTintColor = markers.first?.color.uiColor
        glyphText = "\(markers.count)"
        alpha = isDimmed ? 0.35 : 1
        displayPriority = isDimmed ? .defaultLow : .required
        zPriority = isDimmed ? .min : .defaultUnselected
        titleVisibility = .hidden
        subtitleVisibility = .hidden
        canShowCallout = false
        isAccessibilityElement = true
        accessibilityLabel = "\(markers.first?.tabName ?? "") \(markers.count)件"
        accessibilityIdentifier = "cluster.\(markers.first?.tabName ?? "")"
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
        guard let marker = (annotation as? SpotAnnotation)?.marker, case .place(let place) = marker.spot
        else { return }
        dot.backgroundColor = marker.color.uiColor
        displayPriority = .required
        canShowCallout = false
        isAccessibilityElement = true
        accessibilityLabel = "\(marker.tabName) \(place.name)"
        accessibilityIdentifier = "overviewPin.\(marker.tabIndex).\(place.id.rawValue)"
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
        let markers = cluster.markers
        guard let first = markers.first else { return }
        let side: CGFloat = markers.count >= 10 ? 38 : 32
        bounds = CGRect(x: 0, y: 0, width: side, height: side)
        bubble.frame = bounds
        bubble.layer.cornerRadius = side / 2
        bubble.backgroundColor = first.color.uiColor
        count.frame = bubble.bounds
        count.text = "\(markers.count)"
        let angle = 2 * CGFloat.pi * CGFloat(first.tabIndex) / CGFloat(TabColor.allCases.count)
        centerOffset = CGPoint(x: Self.fanRadius * sin(angle), y: -Self.fanRadius * cos(angle))
        displayPriority = .required
        canShowCallout = false
        isAccessibilityElement = true
        accessibilityLabel = "\(first.tabName) \(markers.count)件"
        accessibilityIdentifier = "overviewCluster.\(first.tabIndex)"
        accessibilityTraits = .button
    }
}
