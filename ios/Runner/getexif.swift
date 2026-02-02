import Foundation
import ImageIO

class GetExif {
    var imagePath: String?

    func getExif() -> [String: Any]? {
        guard let path = imagePath else {
            print("Error: imagePath is nil")
            return nil
        }
        
        // ファイルパスからURLを作成
        let url = URL(fileURLWithPath: path)
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("Error: Failed to create image source from URL: \(url)")
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("Error: Failed to get properties from image source")
            return nil
        }
        
        return properties
    }
}
