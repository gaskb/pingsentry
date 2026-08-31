import AppKit

enum StatusIconRenderer {
    static func makeIcon(filledBars: Int, isAlert: Bool) -> NSImage {
        let barCount = 4
        let width: CGFloat = 18
        let height: CGFloat = 13
        let barWidth: CGFloat = 3
        let spacing: CGFloat = 1.5

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let startX = (width - totalWidth) / 2

        for i in 0..<barCount {
            let barHeight = height * CGFloat(i + 1) / CGFloat(barCount)
            let x = startX + CGFloat(i) * (barWidth + spacing)
            let rect = NSRect(x: x, y: 0, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: 0.75, yRadius: 0.75)

            if i < filledBars {
                (isAlert ? NSColor.systemRed : NSColor.black).setFill()
            } else {
                NSColor.black.withAlphaComponent(0.25).setFill()
            }
            path.fill()
        }

        image.unlockFocus()
        image.isTemplate = !isAlert
        return image
    }
}
