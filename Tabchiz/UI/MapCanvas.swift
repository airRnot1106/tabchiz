import MapKit
import SwiftUI

/// The one map view behind every tab and the overview. When the scene changes it swaps the annotations and moves
/// to that scene's own camera, so each tab reads as a map of its own. MKMapView instead of SwiftUI Map, because
/// SwiftUI Map cannot cluster annotations.
struct MapCanvas: UIViewRepresentable {
    let content: MapContent
    /// The camera of the scene on screen, shown when the scene changes. Nil leaves the map where it is.
    let camera: CameraRegion?
    let command: CameraCommand?
    let showsUserLocation: Bool
    /// Space covered by the sheet at its lowest resting height and by the status bar. The map's own controls, the
    /// Apple logo and the legal link stay inside it, so they do not move with the sheet. The camera region is the
    /// map area inside it, which is the same at every sheet height.
    let controlInsets: UIEdgeInsets
    /// Space covered by the sheet at its current height. The camera frames places inside it.
    let obscuredInsets: UIEdgeInsets
    /// A place of the tab on screen was tapped.
    let onOpen: (PlaceID, TabID) -> Void
    /// A place that belongs to another tab was tapped, or any place in the overview.
    let onJump: (PlaceID, TabID) -> Void
    /// A cluster of one tab's places was tapped in the overview.
    let onJumpToCluster: ([Coordinate], TabID) -> Void
    let onCameraChange: (CameraRegion, MapScene) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        // The muted style keeps the tab colors in front of the map's own colors.
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.showsUserLocation = showsUserLocation
        mapView.showsUserTrackingButton = showsUserLocation
        mapView.showsScale = true
        // A camera region has no heading.
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        // The insets are measured from the screen edges and already include the safe area.
        mapView.insetsLayoutMarginsFromSafeArea = false
        mapView.layoutMargins = controlInsets
        mapView.accessibilityIdentifier = "map"
        mapView.register(PlaceMarkerView.self, forAnnotationViewWithReuseIdentifier: PlaceMarkerView.reuseID)
        mapView.register(PlaceClusterView.self, forAnnotationViewWithReuseIdentifier: PlaceClusterView.reuseID)
        mapView.register(OverviewDotView.self, forAnnotationViewWithReuseIdentifier: OverviewDotView.reuseID)
        mapView.register(OverviewClusterView.self, forAnnotationViewWithReuseIdentifier: OverviewClusterView.reuseID)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if mapView.layoutMargins != controlInsets {
            mapView.layoutMargins = controlInsets
        }
        if coordinator.scene != content.scene {
            coordinator.scene = content.scene
            if let camera {
                mapView.setRegion(camera.mkRegion, animated: false)
            }
        }
        if coordinator.renderedContent != content {
            coordinator.renderedContent = content
            coordinator.render(content, on: mapView)
        }
        if let command, coordinator.appliedCommandID != command.id {
            coordinator.appliedCommandID = command.id
            coordinator.apply(command.target, on: mapView)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private static let casingTitle = "casing"
        private static let clusteringID = "place"

        var parent: MapCanvas
        var scene: MapScene?
        var renderedContent: MapContent?
        var appliedCommandID: Int?

        init(parent: MapCanvas) {
            self.parent = parent
        }

        func render(_ content: MapContent, on mapView: MKMapView) {
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            mapView.removeOverlays(mapView.overlays)
            for line in content.lines {
                let ends = [line.origin.clCoordinate, line.target.clCoordinate]
                // Each polyline carries its style in the title, which the map never displays for overlays: a solid
                // white casing first, then the dashed line in the tab color on top of it.
                let casing = MKPolyline(coordinates: ends, count: ends.count)
                casing.title = Self.casingTitle
                let dashed = MKPolyline(coordinates: ends, count: ends.count)
                dashed.title = line.color.rawValue
                mapView.addOverlays([casing, dashed], level: .aboveRoads)
            }
            let annotations = content.pins.map(PlaceAnnotation.init)
            mapView.addAnnotations(annotations)
            // MapKit's selected marker is the enlarged one.
            if let selected = annotations.first(where: { $0.pin.role == .selected }) {
                mapView.selectAnnotation(selected, animated: false)
            }
        }

        func apply(_ target: CameraCommand.Target, on mapView: MKMapView) {
            switch target {
            case .region(let region):
                mapView.setRegion(region.mkRegion, animated: true)
            case .fit(let coordinates):
                // Room for the marker balloons above the coordinates and their names and distances below.
                frame(coordinates, room: UIEdgeInsets(top: 60, left: 60, bottom: 70, right: 60), on: mapView)
            }
        }

        /// Moves the camera so the coordinates sit in the part of the map that no control covers.
        private func frame(_ coordinates: [Coordinate], room: UIEdgeInsets, on mapView: MKMapView) {
            guard let first = coordinates.first else { return }
            var rect = coordinates.reduce(MKMapRect.null) { rect, coordinate in
                let point = MKMapPoint(coordinate.clCoordinate)
                return rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }
            // A pair a few meters apart still gets about 120 m of context around it.
            let minimumSide = MKMapPointsPerMeterAtLatitude(first.latitude) * 120
            rect = rect.insetBy(
                dx: -max(minimumSide - rect.width, 0) / 2,
                dy: -max(minimumSide - rect.height, 0) / 2
            )
            // MapKit adds edge padding to the layout margins, so only the part of the obscured insets beyond the
            // margins is passed.
            let obscured = parent.obscuredInsets
            let margins = parent.controlInsets
            let padding = UIEdgeInsets(
                top: max(obscured.top - margins.top, 0) + room.top,
                left: max(obscured.left - margins.left, 0) + room.left,
                bottom: max(obscured.bottom - margins.bottom, 0) + room.bottom,
                right: max(obscured.right - margins.right, 0) + room.right
            )
            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case let place as PlaceAnnotation:
                let isOverview = place.pin.role == .overview
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: isOverview ? OverviewDotView.reuseID : PlaceMarkerView.reuseID,
                    for: annotation
                )
                // The viewed place and the nearest places stay out of clusters, and a place in the overview
                // clusters only with its own tab. MapKit groups views by this identifier before prepareForDisplay
                // runs, so it is set here.
                switch place.pin.role {
                case .normal, .dimmed: view.clusteringIdentifier = Self.clusteringID
                case .selected, .nearest: view.clusteringIdentifier = nil
                case .overview: view.clusteringIdentifier = place.pin.tabID.rawValue.uuidString
                }
                return view
            case let cluster as MKClusterAnnotation:
                let isOverview = (cluster.memberAnnotations.first as? PlaceAnnotation)?.pin.role == .overview
                return mapView.dequeueReusableAnnotationView(
                    withIdentifier: isOverview ? OverviewClusterView.reuseID : PlaceClusterView.reuseID,
                    for: annotation
                )
            default:
                return nil
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            if let color = polyline.title.flatMap(TabColor.init(rawValue:)) {
                renderer.strokeColor = color.uiColor
                renderer.lineWidth = 4
                renderer.lineDashPattern = [8, 6]
            } else {
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.9)
                renderer.lineWidth = 8
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            switch annotation {
            case let place as PlaceAnnotation:
                let pin = place.pin
                switch pin.role {
                case .selected:
                    break
                case .normal, .dimmed:
                    mapView.deselectAnnotation(annotation, animated: false)
                    parent.onOpen(pin.place.id, pin.tabID)
                case .nearest, .overview:
                    mapView.deselectAnnotation(annotation, animated: false)
                    parent.onJump(pin.place.id, pin.tabID)
                }
            case let cluster as MKClusterAnnotation:
                mapView.deselectAnnotation(annotation, animated: false)
                if let pin = (cluster.memberAnnotations.first as? PlaceAnnotation)?.pin, pin.role == .overview {
                    parent.onJumpToCluster(cluster.memberAnnotations.map { Coordinate($0.coordinate) }, pin.tabID)
                    return
                }
                // Zooms in until the cluster splits, like Maps. Places too close to split stay one marker and are
                // picked from the results list.
                frame(
                    cluster.memberAnnotations.map { Coordinate($0.coordinate) },
                    room: UIEdgeInsets(top: 50, left: 40, bottom: 30, right: 40),
                    on: mapView
                )
            default:
                mapView.deselectAnnotation(annotation, animated: false)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard let scene, !mapView.bounds.isEmpty else { return }
            let camera = CameraRegion(mapView.region)
            // Reported after the current SwiftUI update, which may be the one that moved the camera.
            Task { @MainActor in self.parent.onCameraChange(camera, scene) }
        }
    }
}
