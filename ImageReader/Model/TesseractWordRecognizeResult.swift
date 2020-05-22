//
//  TesseractWordRecognizeResult.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-21.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Foundation

struct TesseractWordRecognizeResult: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let imageSize: CGSize
}
