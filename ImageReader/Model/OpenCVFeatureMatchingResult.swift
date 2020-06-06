//
//  OpenCVFeatureMatchingResult.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-6-2.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Foundation
import OpenCVBridge

struct OpenCVFeatureMatchingResult: Identifiable {
    
    let id = UUID()
    let goodMatchCount: Int
    let determinant: Double
    let rectangle: Rectangle?
    let previewImage: NSImage?
    
    init() {
        self.init(goodMatchCount: 0, determinant: 0)
    }
    
    init(goodMatchCount: Int, determinant: Double, rectangle: Rectangle? = nil, previewImage: NSImage? = nil) {
        self.goodMatchCount = goodMatchCount
        self.determinant = determinant
        self.rectangle = rectangle
        self.previewImage = previewImage
    }
}

