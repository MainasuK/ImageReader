//
//  Store.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-15.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Cocoa
import Combine
import Vision


final class Store: ObservableObject {
        
    @Published var content = Content()
    @Published var utility = Utility()
    
}

extension Store {
    struct Content {
        // input
        var image = NSImage() {
            didSet { imagePublisher.send(image) }
        }
        
        // output
        let imagePublisher = PassthroughSubject<NSImage, Never>()
        var textObservations: [VNRecognizedTextObservation] = []
    }
}

extension Store {
    struct Utility {
        var readerType: ReaderType = .text
        
        enum ReaderType: CaseIterable {
            case text
            case feature
            
            var text: String {
                switch self {
                case .text:
                    return "Text"
                case .feature:
                    return "Feature"
                }
            }
        }
    }
}
