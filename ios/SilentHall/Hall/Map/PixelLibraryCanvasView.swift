import SwiftUI

/// The navigable pixel hall: a baked floor bitmap, animated desk nodes on top, and overhead badges.
/// Pan with inertia, pinch to zoom around the fingers.
struct PixelLibraryCanvasView: View {
    let layout: LibraryLayout
    let desks: [String: DeskRecord]
    let myUserId: String?
    let clock: ServerClock
    let camera: MapCamera
    @Binding var selectedDeskId: String?
    let onEmptyDeskTap: (LayoutDesk) -> Void

    @State private var dragOrigin: CGSize?
    @State private var pinchOrigin: (zoom: CGFloat, offset: CGSize)?

    /// Badges stay readable at screen size, so they are hidden when zoomed far out (except your own).
    private var showsAllBadges: Bool { camera.tileSize >= 24 }

    var body: some View {
        let tile = camera.tileSize
        let worldSize = CGSize(width: CGFloat(layout.width) * tile, height: CGFloat(layout.height) * tile)

        ZStack(alignment: .topLeading) {
            Image(decorative: SpriteCache.shared.hall(layout), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: worldSize.width, height: worldSize.height)
                .accessibilityHidden(true)

            ForEach(layout.desks) { desk in
                PixelDeskNodeView(desk: desk, occupant: desks[desk.deskId])
                    .frame(width: tile * 2, height: tile * 2)
                    .contentShape(.rect)
                    .onTapGesture { tap(desk) }
                    .position(x: (CGFloat(desk.tileX) + 1) * tile, y: (CGFloat(desk.tileY) + 1) * tile)
            }

            ForEach(desks.values.filter { showsAllBadges || $0.userId == myUserId || $0.deskId == selectedDeskId }) { desk in
                DeskBadgeView(desk: desk, isMine: desk.userId == myUserId, isExpanded: desk.deskId == selectedDeskId, clock: clock)
                    .position(x: (CGFloat(desk.tileX) + 1) * tile, y: CGFloat(desk.tileY) * tile + tile * 0.1)
            }
        }
        .offset(camera.offset)
        // `minWidth`/`minHeight: 0` make the viewport take the screen size instead of growing to the world size.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(cgColor: HallPalette.void.cgColor))
        .clipped()
        .contentShape(.rect)
        .gesture(panGesture.simultaneously(with: pinchGesture))
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            camera.configure(viewport: size, worldTiles: CGSize(width: layout.width, height: layout.height))
        }
        .animation(.spring(duration: 0.35, bounce: 0.3), value: selectedDeskId)
    }

    private func tap(_ desk: LayoutDesk) {
        if desks[desk.deskId] != nil {
            selectedDeskId = selectedDeskId == desk.deskId ? nil : desk.deskId
        } else {
            selectedDeskId = nil
            onEmptyDeskTap(desk)
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard pinchOrigin == nil else { return }
                let origin = dragOrigin ?? camera.offset
                dragOrigin = origin
                camera.pan(from: origin, by: value.translation)
            }
            .onEnded { value in
                guard let origin = dragOrigin else { return }
                dragOrigin = nil
                withAnimation(.smooth(duration: 0.7)) {
                    camera.pan(from: origin, by: value.predictedEndTranslation)
                }
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let origin = pinchOrigin ?? (camera.zoom, camera.offset)
                pinchOrigin = origin
                dragOrigin = nil
                camera.zoom(from: origin, by: value.magnification, anchor: value.startLocation)
            }
            .onEnded { _ in pinchOrigin = nil }
    }
}

private extension PixelColor {
    var cgColor: CGColor {
        CGColor(
            srgbRed: CGFloat(rgba >> 24) / 255,
            green: CGFloat((rgba >> 16) & 0xFF) / 255,
            blue: CGFloat((rgba >> 8) & 0xFF) / 255,
            alpha: CGFloat(rgba & 0xFF) / 255
        )
    }
}
