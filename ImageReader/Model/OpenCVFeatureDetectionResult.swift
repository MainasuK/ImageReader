//
//  OpenCVFeatureDetectionResult.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-6-1.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Foundation
import OpenCVBridge

struct OpenCVFeatureDetectionResult: Identifiable {
    let id = UUID()
    let point: CGPoint
    let keypoint: CVBKeyPoint
}
