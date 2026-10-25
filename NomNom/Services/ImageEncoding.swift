import UIKit

extension UIImage {
    /// Verkleinert auf `maxSide` Pixel an der längsten Seite und kodiert als JPEG.
    func jpegData(maxSide: CGFloat, quality: CGFloat = 0.8) -> Data {
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality) ?? Data()
    }
}
