import Foundation
import CoreGraphics

/// The message surface is measured in screen points, independently of the sprite scale.
struct PetLayout {
    /// Reference pose in atlas coordinates (top-left origin).
    static let visibleSpriteBounds = CGRect(x: 54, y: 60, width: 118, height: 134)
    /// Placement also keeps the phone and clock, including their faint edges, on screen.
    /// This does not change the body's interaction bounds or its foot anchor.
    static let placementSpriteBounds = CGRect(x: 40, y: 39, width: 146, height: 156)
    static let petMargin: CGFloat = 4
    static let headerHeight: CGFloat = 40
    static let headerPerch: CGFloat = 20
    static func sprite(foot: CGPoint, scale: CGFloat) -> CGRect {
        CGRect(x: foot.x-visibleSpriteBounds.midX*scale, y: foot.y-14*scale,
               width: 192*scale, height: 208*scale)
    }
    static func resizedSprite(_ cell: CGRect, scale: CGFloat) -> CGRect {
        let visible = visibleSprite(in: cell)
        return sprite(foot: CGPoint(x:visible.midX,y:visible.minY),scale:scale)
    }
    static func visibleSprite(in cell: CGRect) -> CGRect {
        spriteBounds(visibleSpriteBounds, in: cell)
    }
    static func placementSprite(in cell: CGRect) -> CGRect {
        spriteBounds(placementSpriteBounds, in: cell)
    }
    private static func spriteBounds(_ bounds: CGRect, in cell: CGRect) -> CGRect {
        return CGRect(x: cell.minX + bounds.minX * cell.width / 192,
                      y: cell.minY + (208 - bounds.maxY) * cell.height / 208,
                      width: bounds.width * cell.width / 192, height: bounds.height * cell.height / 208)
    }
    static func constrainedSprite(_ sprite: CGRect, screen: CGRect, screenFrame: CGRect? = nil) -> CGRect {
        let safe = screen.insetBy(dx: petMargin, dy: petMargin)
        let visible = placementSprite(in: sprite)
        return sprite.offsetBy(
            dx: min(max(visible.minX, safe.minX), max(safe.minX, safe.maxX-visible.width))-visible.minX,
            dy: min(max(visible.minY, safe.minY), max(safe.minY, (screenFrame ?? screen).maxY-visible.height))-visible.minY)
    }
    static let bubbleSize = CGSize(width: 231, height: 56)
    static let expandedSize = CGSize(width: 360, height: 500)
    static let minimumChatSize = CGSize(width: 360, height: 180)
    static let cornerRadius: CGFloat = 20
    static let resizeWidth: CGFloat = 6
    static func preferredSize(width: Double?, height: Double?) -> CGSize {
        guard let width, let height, width.isFinite, height.isFinite,
              (360...16384).contains(width), (Double(minimumChatSize.height)...16384).contains(height) else { return expandedSize }
        return CGSize(width: width, height: height)
    }
    struct ResizeEdge: OptionSet {
        let rawValue: Int
        static let left = ResizeEdge(rawValue: 1), right = ResizeEdge(rawValue: 2), far = ResizeEdge(rawValue: 4), near = ResizeEdge(rawValue: 8)
    }
    /// Disjoint strips shared by cursor registration and hit testing. The curved part is rounded outward
    /// to one-point rows, so its visible edge is always reachable with the same diagonal cursor.
    static func resizeRegions(bubble r: CGRect, below: Bool) -> [(rect: CGRect, edge: ResizeEdge)] {
        let w = resizeWidth, radius = cornerRadius
        guard r.width >= 2*radius, r.height >= 2*radius else { return [] }
        let sideY = r.minY+radius
        var regions: [(rect: CGRect, edge: ResizeEdge)] = [
            (CGRect(x:r.minX,y:sideY,width:w,height:r.height-2*radius), .left),
            (CGRect(x:r.maxX-w,y:sideY,width:w,height:r.height-2*radius), .right),
            (CGRect(x:r.minX+radius,y:below ? r.minY : r.maxY-w,width:r.width-2*radius,height:w), .far)
        ]
        for offset in stride(from: CGFloat(0), to: radius, by: 1) {
            let inner = radius-10
            let reach = radius-sqrt(max(0, inner*inner-pow(radius-offset, 2)))
            let y = below ? r.minY+offset : r.maxY-offset-1
            regions.append((CGRect(x:r.minX,y:y,width:reach,height:1), [.left,.far]))
            regions.append((CGRect(x:r.maxX-reach,y:y,width:reach,height:1), [.right,.far]))
            let nearY = below ? r.maxY-offset-1 : r.minY+offset
            regions.append((CGRect(x:r.minX,y:nearY,width:reach,height:1), [.left,.near]))
            regions.append((CGRect(x:r.maxX-reach,y:nearY,width:reach,height:1), [.right,.near]))
        }
        return regions
    }
    static func resizeEdge(at point: CGPoint, bubble: CGRect, below: Bool) -> ResizeEdge {
        resizeRegions(bubble: bubble, below: below).first { $0.rect.contains(point) }?.edge ?? []
    }
    /// The page beside the conversation is never dragged narrower than this.
    static let defaultPaneWidth = expandedSize.width * 2
    static let defaultPaneHeight = expandedSize.height * 2
    static func paneHeight(base: CGFloat, open: Bool, saved: CGFloat?) -> CGFloat {
        open ? max(base, saved ?? defaultPaneHeight) : base
    }
    static let minimumPaneWidth: CGFloat = 280
    /// The least a page is worth opening at; with less room than this it goes to the browser instead.
    static let usablePaneWidth: CGFloat = 240
    /// How the width is shared when a page opens beside the conversation. The conversation keeps its width while the
    /// screen has room for both. When it has not, the page takes what is left, and with less than 360pt left
    /// the conversation gives way, down to its own least width.
    static func paneSplit(base: CGFloat, minimumBase: CGFloat, wanted: CGFloat, available: CGFloat) -> (base: CGFloat, pane: CGFloat) {
        let kept = min(base, available)
        guard wanted > 0 else { return (kept, 0) }
        let need = min(wanted, minimumChatSize.width)
        if available - kept >= need { return (kept, min(wanted, available - kept)) }
        let narrowed = max(min(minimumBase, kept), available - need)
        return (narrowed, max(0, available - narrowed))
    }
    /// `trailing` is the width of the page open at the conversation's right; the size returned is the conversation's own.
    static func resized(_ placement: PetPlacement, edge: ResizeEdge, delta: CGPoint, screen: CGRect, trailing: CGFloat = 0, screenFrame: CGRect? = nil) -> CGSize {
        let safe = screen.insetBy(dx: 12, dy: 12)
        var bubble = placement.globalBubble; bubble.size.width -= trailing
        let center = bubble.midX
        var width = bubble.width, height = bubble.height
        if edge.contains(.right) {
            let target = min(safe.maxX, bubble.maxX+delta.x)
            if bubble.maxX >= safe.maxX-0.5 && bubble.width > 2*(safe.maxX-center) {
                width += min(0,delta.x)
            } else { width = min(2*(target-center),target-safe.minX) }
        } else if edge.contains(.left) {
            let target = max(safe.minX,bubble.minX+delta.x)
            // With a page attached, preserve the content's right edge while resizing its left edge.
            if trailing > 0 { width = bubble.maxX-target }
            else if bubble.minX <= safe.minX+0.5 && bubble.width > 2*(center-safe.minX) {
                width -= max(0,delta.x)
            } else { width = min(2*(center-target),safe.maxX-target) }
        }
        if edge.contains(.far) { height += placement.bubbleBelow ? -delta.y : delta.y }
        if edge.contains(.near) { height += placement.bubbleBelow ? delta.y : -delta.y }
        let availableHeight: CGFloat
        if edge.contains(.near) {
            availableHeight = placement.bubbleBelow ? safe.maxY-bubble.minY : bubble.maxY-safe.minY
        } else {
            availableHeight = placement.bubbleBelow ? placement.globalBubble.maxY-safe.minY : safe.maxY-placement.globalBubble.minY
        }
        return CGSize(width: min(safe.width,max(minimumChatSize.width,width)),
                      height: min(max(0,availableHeight),max(minimumChatSize.height,height)))
    }
    /// Keep the conversation above or below the pet, never beside it.
    /// Only the conversation yields when screen space is insufficient.
    static func constrainedBubble(_ bubble: CGRect, screen: CGRect, avoiding sprite: CGRect, headerOverlap: CGFloat = 0) -> CGRect {
        let safe = screen.insetBy(dx: min(12,screen.width/2), dy: min(12,screen.height/2))
        let obstacle = placementSprite(in: sprite)
        let lowerEdge = obstacle.minY + min(headerPerch,max(0,headerOverlap))
        func fit(_ region: CGRect) -> CGRect {
            let size = CGSize(width:min(max(0,bubble.width),region.width),height:min(max(0,bubble.height),region.height))
            // Keep the pet horizontally over the surface even after screen clamping.
            let center = min(max(obstacle.midX,region.minX),region.maxX)
            let minX = max(region.minX,center-size.width)
            let maxX = min(region.maxX-size.width,center)
            return CGRect(x:min(max(bubble.minX,minX),maxX),
                          y:min(max(bubble.minY,region.minY),region.maxY-size.height),width:size.width,height:size.height)
        }
        let clamped = fit(safe)
        if clamped.maxY <= lowerEdge || clamped.minY >= obstacle.maxY { return clamped }
        let bottom = min(safe.maxY,max(safe.minY,lowerEdge))
        let top = min(safe.maxY,max(safe.minY,obstacle.maxY))
        let regions = [
            CGRect(x:safe.minX,y:safe.minY,width:safe.width,height:bottom-safe.minY),
            CGRect(x:safe.minX,y:top,width:safe.width,height:safe.maxY-top)
        ]
        func rank(_ rect: CGRect) -> Int {
            if rect.width >= bubble.width && rect.height >= bubble.height { return 2 }
            return rect.width >= min(bubble.width,minimumChatSize.width) && rect.height >= min(bubble.height,minimumChatSize.height) ? 1 : 0
        }
        func distance(_ rect: CGRect) -> CGFloat {
            pow(rect.minX-bubble.minX,2)+pow(rect.minY-bubble.minY,2)
        }
        var best: CGRect?
        for region in regions where region.width > 0 && region.height > 0 {
            let candidate = fit(region)
            guard let previous = best else { best = candidate; continue }
            let a = rank(candidate), b = rank(previous)
            let area = candidate.width*candidate.height, oldArea = previous.width*previous.height
            if a > b || (a == b && ((a < 2 && area > oldArea) ||
                ((a == 2 || area == oldArea) && distance(candidate) < distance(previous)))) {
                best = candidate
            }
        }
        // A display wholly covered by the pet has no usable conversation region.
        // An empty surface is preferable to covering the pet or moving it implicitly.
        return best ?? CGRect(origin:safe.origin,size:.zero)
    }
    let scale: CGFloat
    var spriteSize: CGSize { CGSize(width: 192 * scale, height: 208 * scale) }
    var windowSize: CGSize {
        CGSize(width: max(Self.bubbleSize.width, spriteSize.width) + 24,
               height: spriteSize.height + Self.bubbleSize.height + 32)
    }
    var spriteRect: CGRect {
        CGRect(x: (windowSize.width - spriteSize.width) / 2, y: 12,
               width: spriteSize.width, height: spriteSize.height)
    }
    var bubbleRect: CGRect {
        CGRect(x: (windowSize.width - Self.bubbleSize.width) / 2, y: spriteRect.maxY + 8,
               width: Self.bubbleSize.width, height: Self.bubbleSize.height)
    }
}

/// The sprite is the position anchor. The bubble shifts independently to stay on the display.
struct PetPlacement {
    private(set) var drawer: CGFloat = 0
    /// The resize/drag contract uses the opened box minus its right-hand drawer allowance.
    var contentBubble: CGRect { CGRect(x:globalBubble.minX,y:globalBubble.minY,width:globalBubble.width-drawer,height:globalBubble.height) }
    func withDrawer(_ width:CGFloat, visibleFrame:CGRect) -> PetPlacement {
        guard expanded,width>0 else{return self}
        let bubble=PetLayout.constrainedBubble(CGRect(x:globalBubble.minX,y:globalBubble.minY,
            width:globalBubble.width+width,height:globalBubble.height),screen:visibleFrame,avoiding:globalSprite,headerOverlap:expanded ? PetLayout.headerPerch:0)
        var result=PetPlacement(globalSprite:globalSprite,globalBubble:bubble,
            expanded:expanded)
        result.drawer=min(width,max(0,bubble.width-min(bubble.width,PetLayout.minimumChatSize.width)/2))
        return result
    }

    let windowFrame: CGRect
    let spriteRect: CGRect
    let bubbleRect: CGRect
    let bubbleBelow: Bool
    let expanded: Bool
    var globalSprite: CGRect { spriteRect.offsetBy(dx: windowFrame.minX, dy: windowFrame.minY) }
    var globalBubble: CGRect { bubbleRect.offsetBy(dx: windowFrame.minX, dy: windowFrame.minY) }
    var anchorOrigin: CGPoint { globalSprite.origin }

    func dragged(by delta: CGPoint, visibleFrame: CGRect, screenFrame: CGRect? = nil) -> PetPlacement {
        let sprite = PetLayout.constrainedSprite(globalSprite.offsetBy(dx:delta.x,dy:delta.y),screen:visibleFrame,screenFrame:screenFrame)
        let bubble = PetLayout.constrainedBubble(globalBubble.offsetBy(dx:delta.x,dy:delta.y),screen:visibleFrame,avoiding:sprite,headerOverlap:expanded ? PetLayout.headerPerch:0)
        return PetPlacement(globalSprite:sprite,globalBubble:bubble,
                            expanded:expanded,drawer:drawer)
    }

    init(globalSprite: CGRect, globalBubble: CGRect, windowFrame: CGRect? = nil, expanded: Bool = false, drawer: CGFloat = 0, below: Bool? = nil) {
        // Preserve the usual inline drawer, but leave input space when avoidance narrows the box.
        self.drawer=min(max(0,drawer),max(0,globalBubble.width-min(globalBubble.width,PetLayout.minimumChatSize.width)/2))
        self.expanded = expanded
        // NSWindow rounds its frame to screen pixels. Enclose the union on whole points
        // before deriving local coordinates so that rounding cannot displace the pet.
        self.windowFrame = (windowFrame ?? globalSprite.union(globalBubble).insetBy(dx: -12, dy: -12)).integral
        spriteRect = globalSprite.offsetBy(dx: -self.windowFrame.minX, dy: -self.windowFrame.minY)
        bubbleRect = globalBubble.offsetBy(dx: -self.windowFrame.minX, dy: -self.windowFrame.minY)
        bubbleBelow = below ?? (globalBubble.midY < globalSprite.midY)
    }

    init(spriteOrigin: CGPoint, scale: CGFloat, visibleFrame: CGRect, screenFrame: CGRect? = nil,
         bubbleSize: CGSize = PetLayout.bubbleSize, expanded: Bool = false,
         preferredSize: CGSize = PetLayout.expandedSize, below: Bool? = nil, trailing: CGFloat = 0, drawer: CGFloat = 0) {
        let full = screenFrame ?? visibleFrame
        let safe = visibleFrame.insetBy(dx:12,dy:12)
        let requested = CGRect(origin:spriteOrigin,size:PetLayout(scale:scale).spriteSize)
        let sprite = PetLayout.constrainedSprite(requested,screen:visibleFrame,screenFrame:full)
        let foot = PetLayout.visibleSprite(in:sprite)
        let body = PetLayout.placementSprite(in:sprite)
        let roomBelow = max(0,body.minY-safe.minY)
        let above = max(0,safe.maxY-sprite.maxY-8)
        let isBelow = expanded ? below ?? (roomBelow >= preferredSize.height || (above < preferredSize.height && roomBelow > above)) : sprite.maxY+8+bubbleSize.height > safe.maxY
        let size = expanded ? preferredSize : bubbleSize
        let center = expanded && isBelow ? foot.midX : sprite.midX
        let top = body.minY+(expanded ? PetLayout.headerPerch:-8)
        let candidate = CGRect(x:center-size.width/2,y:isBelow ? top-size.height : sprite.maxY+8,
                               width:size.width+(expanded ? trailing+drawer:0),height:size.height)
        let bubble = PetLayout.constrainedBubble(candidate,screen:visibleFrame,avoiding:sprite,headerOverlap:expanded ? PetLayout.headerPerch:0)
        self=PetPlacement(globalSprite:sprite,globalBubble:bubble,expanded:expanded,drawer:expanded ? drawer:0)
    }
}
/// Frame-rate independent easing. Keep the bubble inside the current screen even during a transition.
/// How the conversation looks while the bubble grows into it or folds back: it clears as it opens and blurs away as it
/// closes, staying where it is while the glass moves over it.
enum ChatMorph {
    static func genieBlur(_ progress: CGFloat) -> CGFloat {
        let p = min(1, max(0, progress))
        return 1 - p * p * (3 - 2 * p)
    }
    static func genieProgress(from start: CGFloat, opening: Bool, fraction: CGFloat) -> CGFloat {
        let p = min(1, max(0, fraction))
        return opening ? start + (1 - start) * p : start * (1 - p)
    }
    static let genieDuration: TimeInterval = 0.30
    static let genieStripHeight: CGFloat = 3
    /// First bend the mouth toward the pet, then pull the body along the funnel.
    static func genieStrip(_ rect: CGRect, target: CGPoint, lower: CGFloat, upper: CGFloat,
                           progress: CGFloat, below: Bool = true) -> CGRect {
        let p = min(1,max(0,progress))
        func smooth(_ x: CGFloat) -> CGFloat { let t = min(1,max(0,x)); return t*t*(3-2*t) }
        let bend = smooth((1-p)/0.42)
        let pull = smooth((1-p-0.32)/0.68)
        let mouth = min(28,rect.width)/rect.width
        func edge(_ u: CGFloat) -> (CGFloat,CGFloat,CGFloat) {
            let near = below ? u : 1-u
            let curve = near*near*(3-2*near)
            let amount = bend*curve
            let width = rect.width*(1-amount*(1-mouth))*(1-pull)
            let center = rect.midX+(target.x-rect.midX)*(amount+(1-amount)*pull)
            let y = (rect.minY+u*rect.height)*(1-pull)+target.y*pull
            return (center,width,y)
        }
        let a=edge(lower), b=edge(upper), m=edge((lower+upper)/2)
        return CGRect(x:m.0-m.1/2,y:a.2,width:m.1,height:max(0,b.2-a.2))
    }
    static let blur: CGFloat = 16
    /// `progress` runs from 0, the folded bubble, to 1, the open conversation.
    static func look(progress: CGFloat) -> (blur: CGFloat, alpha: CGFloat, bubbleAlpha: CGFloat) {
        let p = max(0, min(1, progress))
        // Softest at the start, sharp a little before the window has finished growing.
        let clear = min(1, p / 0.9)
        let radius = blur * (1 - clear) * (1 - clear)
        return (radius < 0.3 ? 0 : radius, min(1, p * 1.5), max(0, 1 - p * 3.2))
    }
    /// How far the glass has grown between the two heights.
    static func progress(height: CGFloat, folded: CGFloat, open: CGFloat) -> CGFloat {
        open > folded ? max(0, min(1, (height - folded) / (open - folded))) : 1
    }
}

enum ChatWidthSlide {
    static let duration: TimeInterval = 0.3
    static let fadeDuration: TimeInterval = 0.06
    static func cover(_ progress: CGFloat) -> CGFloat {
        let p = min(1, max(0, progress / 0.2))
        return p * p * (3 - 2 * p)
    }
}

struct PetBubbleMotion {
    private(set) var position: CGPoint?
    private var target = CGPoint.zero
    private var lastTime: TimeInterval?
    private var bounds = CGRect.zero
    private(set) var size = PetLayout.bubbleSize
    private var targetSize = PetLayout.bubbleSize
    private var widthSlide: (start: TimeInterval, origin: CGPoint, size: CGSize, duration: TimeInterval)?
    private(set) var widthProgress: CGFloat = 1
    var easedWidthProgress: CGFloat { widthProgress * widthProgress * (3 - 2 * widthProgress) }
    mutating func slideWidth(now: TimeInterval, duration: TimeInterval = ChatWidthSlide.duration) {
        widthSlide = (now, position ?? target, size, duration); widthProgress = 0
    }
    mutating func cancelWidthSlide() { widthSlide = nil; widthProgress = 1 }
    private var glideUntil: TimeInterval = 0
    /// Opening and folding the conversation take a little longer than following the pet, so the change can be seen.
    mutating func glide(now: TimeInterval) { glideUntil = now + 0.8 }

    mutating func retarget(_ point: CGPoint, visibleFrame: CGRect, now: TimeInterval, immediately: Bool = false,
                           size: CGSize = PetLayout.bubbleSize, headerAtTop: Bool = false) {
        targetSize = size
        bounds = visibleFrame.insetBy(dx: 12, dy: 12)
        if headerAtTop { bounds.size.height += 12 }
        target = clamped(point, size: targetSize)
        if position == nil || immediately { cancelWidthSlide(); self.size = targetSize; position = target; lastTime = now }
        else if let position { self.position = clamped(position) }
    }

    mutating func step(now: TimeInterval) -> CGPoint {
        if let slide = widthSlide {
            widthProgress = CGFloat(min(1, max(0, (now - slide.start) / slide.duration)))
            let eased = easedWidthProgress
            size = CGSize(width: slide.size.width + (targetSize.width - slide.size.width) * eased,
                          height: slide.size.height + (targetSize.height - slide.size.height) * eased)
            position = CGPoint(x: slide.origin.x + (target.x - slide.origin.x) * eased,
                               y: slide.origin.y + (target.y - slide.origin.y) * eased)
            lastTime = now
            if widthProgress == 1 { widthSlide = nil; size = targetSize; position = target }
            return position!
        }
        let dt = min(0.1, max(0, now - (lastTime ?? now)))
        lastTime = now
        let previous = position ?? target
        let fraction = 1 - exp(-dt / (now < glideUntil ? 0.105 : 0.065))
        size = CGSize(width: size.width + (targetSize.width - size.width) * fraction,
                      height: size.height + (targetSize.height - size.height) * fraction)
        if abs(size.width - targetSize.width) + abs(size.height - targetSize.height) < 0.2 { size = targetSize }
        let next = CGPoint(x: previous.x + (target.x - previous.x) * fraction,
                           y: previous.y + (target.y - previous.y) * fraction)
        position = hypot(next.x - target.x, next.y - target.y) < 0.2 ? target : clamped(next)
        return position!
    }

    private func clamped(_ point: CGPoint, size requestedSize: CGSize? = nil) -> CGPoint {
        let size = requestedSize ?? self.size
        return CGPoint(x: min(max(point.x, bounds.minX), max(bounds.minX, bounds.maxX - size.width)),
                y: min(max(point.y, bounds.minY), max(bounds.minY, bounds.maxY - size.height)))
    }
}
