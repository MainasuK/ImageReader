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
import OpenCVBridge

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
        
        // vision relay
        var textObservations: [VNRecognizedTextObservation] = []
        var attentionBasedSaliencyImageObservations: [VNSaliencyImageObservation] = []
        var objectnessBasedSaliencyImageObservations: [VNSaliencyImageObservation] = []
        
        // opencv relay
        var surfKeypoints: [OpenCVFeatureDetectionResult] = []
        
        // tesseract relay
        var tesseractWordRecognizeResults: [TesseractWordRecognizeResult] = []
    }
}

extension Store {
    struct Utility {
        // MARK: - Read Type Picker
        
        var readerType: ReaderType = .vision
        
        // MARK: - Vision
        
        // Saliency
        var saliencyType: SaliencyType = .none
        var saliencyMaskEnabled = true
        var saliencyMaskAlpha: CGFloat = 0.8
        var sailencyBoundingBoxEnabled = true
        
        // Text
        var recognizeTextRequestOptions = RecognizeTextRequestOptions() {
            didSet { recognizeTextRequestOptionsPublisher.send(recognizeTextRequestOptions) }
        }
        let recognizeTextRequestOptionsPublisher = PassthroughSubject<RecognizeTextRequestOptions, Never>()
        
        // MARK: - OpenCV
        
        // SURF feature detection
        var surfOptions = SURFfOptions() {
            didSet { surfOptionsPublisher.send(surfOptions) }
        }
        let surfOptionsPublisher = PassthroughSubject<SURFfOptions, Never>()
        
        // MARK: - Tesseract
        var tesseractOptions = TesseractOptions() {
            didSet { tesseractOptionsPublisher.send(tesseractOptions) }
        }
        let tesseractOptionsPublisher = PassthroughSubject<TesseractOptions, Never>()
        
        var enableVsionPreProcessing = true {
            didSet { enableVsionPreProcessingPublisher.send(enableVsionPreProcessing) }
        }
        let enableVsionPreProcessingPublisher = PassthroughSubject<Bool, Never>()
    }
}

extension Store.Utility {
    enum ReaderType: CaseIterable {
        case vision
        case opencv
        case tesseract
        
        var text: String {
            switch self {
            case .vision:     return "Vision"
            case .opencv:     return "OpenCV"
            case .tesseract:  return "Tesseract"
            }
        }
    }
    
    enum SaliencyType: CaseIterable, Hashable {
        case none
        case attention
        case objectness
        
        var text: String {
            switch self {
            case .none:       return "None"
            case .attention:  return "Attention"
            case .objectness: return "Objectness"
            }
        }
    }
}

extension VNRequestTextRecognitionLevel: Hashable { }

extension VNRequestTextRecognitionLevel: CaseIterable {
    public static var allCases: [VNRequestTextRecognitionLevel] {
        return [
            .accurate,
            .fast
        ]
    }
}

extension VNRequestTextRecognitionLevel {
    var text: String {
        switch self {
        case .accurate: return "Accurate"
        case .fast:     return "Fast"
        @unknown default:
            assertionFailure()
            return "Unknown"
        }
    }
}
