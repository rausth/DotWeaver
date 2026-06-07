import Foundation

enum DotWeaverResourceBundle {
    private static let bundleName = "DotWeaver_DotWeaver"

    static let bundle: Bundle? = {
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources"),
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
            Bundle.main.executableURL?.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        ].compactMap { $0 }

        for baseURL in candidates {
            let bundleURL = baseURL.appendingPathComponent(bundleName).appendingPathExtension("bundle")
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        return nil
    }()

    static func url(forResource name: String, withExtension fileExtension: String) -> URL? {
        bundle?.url(forResource: name, withExtension: fileExtension)
    }
}
