import Foundation

actor TemplateEngine {
    static let shared = TemplateEngine()
    private init() {}
    
    private var variables: [String: String] = [
        "USER": NSUserName(),
        "HOME": NSHomeDirectory(),
        "HOSTNAME": ProcessInfo.processInfo.hostName,
        "DATE": ISO8601DateFormatter().string(from: Date())
    ]
    
    func setVariable(_ key: String, value: String) {
        variables[key] = value
    }
    
    func render(template: String) -> String {
        var result = template
        
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{ \(key) }}", with: value)
            result = result.replacingOccurrences(of: "{{ \(key)}}", with: value)
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return result
    }
    
    func renderFile(at path: String) throws -> String {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return render(template: content)
    }
    
    func renderFiles(in directory: String) throws -> [(path: String, content: String)] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: directory)
        
        return try contents.compactMap { filename in
            let filePath = (directory as NSString).appendingPathComponent(filename)
            guard fileManager.isReadableFile(atPath: filePath) else { return nil }
            
            let content = try renderFile(at: filePath)
            return (path: filePath, content: content)
        }
    }
}
