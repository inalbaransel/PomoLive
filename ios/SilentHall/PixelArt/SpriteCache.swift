import CoreGraphics

/// Rendering sprites is cheap, but redrawing 30 animated desks every frame is not; cache every variant once.
@MainActor
final class SpriteCache {
    static let shared = SpriteCache()

    private var desks: [DeskSprite.Key: CGImage] = [:]
    private var avatars: [AvatarSprite: CGImage] = [:]
    private var halls: [LibraryLayout: CGImage] = [:]

    func desk(_ key: DeskSprite.Key) -> CGImage {
        if let cached = desks[key] { return cached }
        let image = DeskSprite.render(key)
        desks[key] = image
        return image
    }

    func avatar(_ avatar: AvatarSprite) -> CGImage {
        if let cached = avatars[avatar] { return cached }
        let image = avatar.image(.idle)
        avatars[avatar] = image
        return image
    }

    func hall(_ layout: LibraryLayout) -> CGImage {
        if let cached = halls[layout] { return cached }
        let image = HallRenderer.render(layout)
        halls[layout] = image
        return image
    }
}
