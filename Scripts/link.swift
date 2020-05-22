#!/usr/bin/swift

// This script setup correct tesseract dependencies linking environment:
// 1. scan the bin/tesseract exec dependencies using `otool -L $(which tesseract)`
// 2. resolve the dylib paths to link-time path and build the dependency tree
// 3. use `install_name_tool` change the Xcode target application exec dylib install path to @rpath
// 4. use `install_name_tool` change the dylib internal dependency to @rpath

// Q: Why change to @rpath
// A: The dylib needs embeded (copy) and sign to avoid app signature issue
//    The dylib needs set correct link path otherwise the app will fail to load dylib on client devices and crash
//    (if without tesseract install, so no /usr/local/lib/lib*.dylib)

import Foundation

let env = ProcessInfo.processInfo.environment

Bash.debugEnabled = false

class Bash {
    static var debugEnabled = false

    // save command search time
    static var commandCache: [String: String] = [:]
    
    @discardableResult
    func run(_ command: String, arguments: [String] = [], environment: [String: String]? = ProcessInfo.processInfo.environment, _line: Int = #line) throws -> String {
        let _command: String
        if let cache = Bash.commandCache[command] {
            _command = cache
        } else {
            var theCommand = try run(command: "/bin/bash" , arguments: ["-l", "-c", "which \(command)"], environment: environment)
            theCommand = theCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            _command = theCommand
            Bash.commandCache[command] = theCommand
        }
        let arguments = arguments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let result = try run(command: _command, arguments: arguments, environment: environment)
        if Bash.debugEnabled {
            print("+\((#file as NSString).lastPathComponent):\(_line)> \(_command) \(arguments.joined(separator: " "))")
            print(result)
        }
        return result
    }
    
    private func run(command: String, arguments: [String] = [], environment: [String: String]? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        if let environment = environment { process.environment = environment }
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        var output = String(decoding: outputData, as: UTF8.self)
        process.waitUntilExit()
        if output.hasSuffix("\n") {
            output.removeLast(1)
        }
        if process.terminationStatus != 0 { fatalError("shell execute coccus fail") }
        return output
    }
}


// save reduplicate query time
var otoolResultCache: [String: String] = [:]
// otool -L <path>
func extractDependenciesFromOtoolWithFlagL(path: String) throws -> [String] {
    let result: String
    if let cache = otoolResultCache[path] {
        result = cache
    } else {
        result = try Bash().run("otool", arguments: ["-L", path])
        otoolResultCache[path] = result
    }
    return result
        .components(separatedBy: .newlines)
        .dropFirst()    // drop otool first prompt line
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } // trim space
        .map { line -> String in
            guard let range = line.range(of: #"/usr/local/.*dylib"#, options: .regularExpression) else {
                return ""
            }
            return String(line[range.lowerBound..<range.upperBound])
        }   // extract embeded dylib path
        .filter { $0.hasPrefix("/usr/local/") } // filter out empty line
}

struct DylibTree {
    let isDylib: Bool
    let path: String
    var dependencies: [DylibTree]

    init() {
        self.isDylib = false
        self.path = ""
        self.dependencies = []
    }

    // resolvePath: if should use the path from otool
    // note: only needs resolve when scan bin/tesseract exec
    init(path: String, resolvePath: Bool = false) throws {
        self.isDylib = true
        let dependencies = try extractDependenciesFromOtoolWithFlagL(path: path)
        self.path = resolvePath ? dependencies[0] : path
        self.dependencies = try dependencies
            .dropFirst()
            .map { path in
                try DylibTree(path: path)
            }
    }

    // insert dependencies at root
    mutating func insert(path: String, resolvePath: Bool = false) throws {
        let new = try DylibTree(path: path, resolvePath: resolvePath)
        self.dependencies.append(new)
    }

    // print tree struct
    func printTree(level: Int = 0) {
        if level != 0 {
            let intend = level > 0 ? String(repeating: "-", count: (level - 1) * 4) : ""
            let prefix = level > 1 ? "|" : "@"
            print("\(prefix)\(intend)> \(path)")
        }
        
        for node in dependencies {
            node.printTree(level: level + 1)
        }
    }

    var paths: Set<String> {
        var pathSet = Set<String>()
        
        if !path.isEmpty {
            pathSet.insert(path)
        }

        for node in dependencies {
            for path in node.paths {
                pathSet.insert(path)
            }
        }

        return pathSet
    }
}


let bash = Bash()
// % otool -L /usr/local/bin/tesseract
// /usr/local/Cellar/tesseract/4.1.1/lib/libtesseract.4.dylib (compatibility version 5.0.0, current version 5.1.0) 
// /usr/local/opt/leptonica/lib/liblept.5.dylib (compatibility version 6.0.0, current version 6.3.0)
let tesseractLocation = try bash.run("which", arguments: ["tesseract"])
let dependencies = try extractDependenciesFromOtoolWithFlagL(path: tesseractLocation)

// build tree
var tree = DylibTree()
for path in dependencies {
    try tree.insert(path: path, resolvePath: true)
}
if Bash.debugEnabled { 
    print("+\(#file):\(#line):tree.printTree()")
    tree.printTree() 
}

// reduce tree paths
let paths = tree.paths
if Bash.debugEnabled { 
    print("+\(#file):\(#line):print(tree.paths) # count: \(paths.count)")
    for path in paths {
        print(path)
    }
}

// 1. Redirect executable
print("+\(#file):\(#line):redirect executable dylib location")
for path in paths {
    // rpath needs real file destination
    let filename: String = {
        let fileURL = URL(fileURLWithPath: path)
        return fileURL.resolvingSymlinksInPath().lastPathComponent
    }()
    
    Bash.debugEnabled = true
    let executablePath = env["BUILT_PRODUCTS_DIR"]! + "/" + env["EXECUTABLE_PATH"]!
    try Bash().run("install_name_tool", arguments: ["-change", path, "@rpath/\(filename)", executablePath])
    Bash.debugEnabled = false
}

extension DylibTree {
    // [source_dylib_name : [dependencies_dylib_path]]
    func flatDependencies() -> [String: Set<String>] {
        var flatResults: [String: Set<String>] = [:]
        guard let url = URL(string: path), !dependencies.isEmpty else {
            for node in dependencies {
                let results = node.flatDependencies()
                for (key, value) in results {
                    flatResults[key] = flatResults[key].flatMap { $0.union(value) } ?? value
                }
            }
            return flatResults
        }

        let filename = url.lastPathComponent
        for node in dependencies {
            flatResults[filename] = flatResults[filename].flatMap { $0.union([node.path]) } ?? Set([node.path])
        }

        for node in dependencies {
            let results = node.flatDependencies()
            for (key, value) in results {
                flatResults[key] = flatResults[key].flatMap { $0.union(value) } ?? value
            }
        }

        return flatResults
    }
}

// 2. redirect dylib
Bash.debugEnabled = true
print("+\(#file):\(#line):redirect dylib's dependencies location")
let flatDependencies = tree.flatDependencies()
for (dylibFilename, dependencyPaths) in flatDependencies {
    print("# \(dylibFilename)")
    for dependencyPath in dependencyPaths {
        // rpath needs real file destination
        let dependencyFilename: String = {
            let dependencyURL = URL(fileURLWithPath: dependencyPath)
            return dependencyURL.resolvingSymlinksInPath().lastPathComponent
        }()
        Bash.debugEnabled = true
        let dylibPath = env["BUILT_PRODUCTS_DIR"]! + "/" + env["FRAMEWORKS_FOLDER_PATH"]! + "/" + dylibFilename
        try Bash().run("install_name_tool", arguments: ["-change", dependencyPath, "@rpath/\(dependencyFilename)", dylibPath])
        Bash.debugEnabled = false
    }
}
