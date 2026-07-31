import UIKit

enum FabricPattern { case solid, stripes, denim, knit, plaid }

/// Procedurally-drawn fabric textures so garments read as real fabric rather
/// than flat colour. Tiled across the garment geometry.
enum PatternTextures {
    static func pattern(for garment: GarmentDTO) -> FabricPattern {
        let n = garment.name.lowercased()
        if n.contains("jean") || n.contains("denim") { return .denim }
        if n.contains("hoodie") || n.contains("knit") || n.contains("sweater") { return .knit }
        if n.contains("blouse") || n.contains("shirt") { return .stripes }
        if n.contains("skirt") || n.contains("dress") { return .plaid }
        return .solid
    }

    private static func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: 1)
    }

    static func image(_ pattern: FabricPattern, color: UIColor, size: CGFloat = 128) -> UIImage? {
        guard pattern != .solid else { return nil }
        let s = CGSize(width: size, height: size)
        let light = mix(color, .white, 0.16)
        let dark = mix(color, .black, 0.16)
        return UIGraphicsImageRenderer(size: s).image { ctx in
            let c = ctx.cgContext
            color.setFill(); c.fill(CGRect(origin: .zero, size: s))
            switch pattern {
            case .stripes:
                light.setFill()
                var y: CGFloat = 0
                while y < size { c.fill(CGRect(x: 0, y: y, width: size, height: 6)); y += 14 }
            case .plaid:
                light.setStroke(); c.setLineWidth(5)
                var p: CGFloat = 0
                while p < size {
                    c.move(to: CGPoint(x: p, y: 0)); c.addLine(to: CGPoint(x: p, y: size))
                    c.move(to: CGPoint(x: 0, y: p)); c.addLine(to: CGPoint(x: size, y: p))
                    p += 24
                }
                c.strokePath()
            case .denim:
                dark.setStroke(); c.setLineWidth(1)
                var x: CGFloat = -size
                while x < size {
                    c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x + size, y: size)); x += 5
                }
                c.strokePath()
            case .knit:
                dark.setStroke(); c.setLineWidth(2)
                var g: CGFloat = 0
                while g < size {
                    c.move(to: CGPoint(x: g, y: 0)); c.addLine(to: CGPoint(x: g, y: size))
                    c.move(to: CGPoint(x: 0, y: g)); c.addLine(to: CGPoint(x: size, y: g))
                    g += 10
                }
                c.strokePath()
            case .solid: break
            }
        }
    }
}
