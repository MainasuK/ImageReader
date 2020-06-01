//
//  TesseractService.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-21.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Cocoa
import Combine
import Vision
import CommonOSLog
import SwiftTesseract

struct TesseractOptions {
    var enabled = true
    var mode: Mode = .fast
    var pageSegmentMode = Tesseract.PageSegMode.SINGLE_LINE // that could better when enable vision pre-processing
    var pageIteratorLevel = Tesseract.PageIteratorLevel.textline
    
    var isCustomEnabled = false
    
    enum Mode: CaseIterable {
        case fast
        case best
        
        var text: String {
            switch self {
            case .fast:     return "Fast"
            case .best:     return "Best"
            }
        }
    }
}

final class TesseractService: ObservableObject {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let image = CurrentValueSubject<NSImage, Never>(NSImage())
    var imageSubscription: AnyCancellable?
    
    let tesseractOptions = CurrentValueSubject<TesseractOptions, Never>(TesseractOptions())
    var tesseractOptionsSubscription: AnyCancellable?
    
    let isVisionSearchHelperEnabled = CurrentValueSubject<Bool, Never>(true)
    var isVisionSearchHelperEnabledSubscription: AnyCancellable?
    
    // output
    let wordRecognizeResults = CurrentValueSubject<[TesseractWordRecognizeResult], Never>([])
    var wordRecognizeResultsSubscription: AnyCancellable?
    
    init() {
        let imagePublisher = image.share()
        imagePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // reset output
                self.wordRecognizeResults.send([])
            }
            .store(in: &disposeBag)
        
        let throttledImagePublisher = imagePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .share()
            
        Publishers
            .CombineLatest3(
                throttledImagePublisher.eraseToAnyPublisher(),
                tesseractOptions.eraseToAnyPublisher(),
                isVisionSearchHelperEnabled.eraseToAnyPublisher()
            )
            .map { image, options, shouldUseVisionSearching -> AnyPublisher<(NSImage, TesseractOptions, [Rectangle]), Never> in
                // reset again to hint user update success
                DispatchQueue.main.async {
                    self.wordRecognizeResults.send([])
                }
                
                if options.enabled && shouldUseVisionSearching {
                    return Future<[Rectangle], Never> { promise in
                        DispatchQueue.global(qos: .userInitiated).async {
                            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                                promise(.success([]))
                                return
                            }
                            
                            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                            let reqeust = VNRecognizeTextRequest { request, error in
                                guard let request = request as? VNRecognizeTextRequest,
                                    let results = request.results as? [VNRecognizedTextObservation] else {
                                        promise(.success([]))
                                        return
                                }
                                
                                let rectangles = results.map { observation in
                                    Rectangle(
                                        topLeft: CGPoint(x: observation.topLeft.x, y: 1 - observation.topLeft.y),
                                        topRight: CGPoint(x: observation.topRight.x, y: 1 - observation.topRight.y),
                                        bottomLeft: CGPoint(x: observation.bottomLeft.x, y: 1 - observation.bottomLeft.y),
                                        bottomRight: CGPoint(x: observation.bottomRight.x, y: 1 - observation.bottomRight.y)
                                    )
                                }
                                
                                promise(.success(rectangles))
                            }
                            do {
                                try requestHandler.perform([reqeust])
                            } catch {
                                promise(.success([]))
                            }
                        }
                    }   // end Future
                    .map { (image, options, $0) }
                    .eraseToAnyPublisher()
                } else {
                    return Just((image, options, []))
                        .eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .sink { [weak self] image, options, rectangles in
                guard let `self` = self else { return }
                guard options.enabled else {
                    return
                }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    var results: [TesseractWordRecognizeResult] = []
                    do {
                        let datapath = Bundle.main.resourceURL.flatMap { resourceURL -> URL? in
                            let tessdataBundleURL = resourceURL.appendingPathComponent("Tessdata.bundle")
                            let resourceURL = Bundle(url: tessdataBundleURL)?.resourceURL
                            switch options.mode {
                            case .fast:
                                return resourceURL.flatMap { $0.appendingPathComponent("fast") }
                            case .best:
                                return resourceURL.flatMap { $0.appendingPathComponent("best") }
                            }
                        }
                        
                        guard let imageRep = image.representations.first else {
                            return
                        }
                        let imageSize = CGSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh)
                        
                        let searchRectangles: [Rectangle] = {
                            if rectangles.isEmpty {
                                return [
                                    Rectangle(
                                        topLeft: .zero,
                                        topRight: CGPoint(x: 1, y: 0),
                                        bottomLeft: CGPoint(x: 0, y: 1),
                                        bottomRight: CGPoint(x: 1, y: 1)
                                    )
                                ]
                            } else {
                                return rectangles
                            }
                        }()

                        let tesseract = Tesseract()
                        let language: Tesseract.Language = options.mode == .best && options.isCustomEnabled ? .custom("NotoSans_SemiLight") : .custom("chi_sim")
                        try tesseract.init3(datapath: datapath, language: language)
                        tesseract.setPageSegMode(mode: options.pageSegmentMode)
                        try tesseract.setImage2(nsImage: image)
                        
                        for searchRectangle in searchRectangles {

                            let left = Int(min(searchRectangle.topLeft.x, searchRectangle.bottomLeft.x) * imageSize.width)
                            let top = Int(min(searchRectangle.topLeft.y, searchRectangle.bottomLeft.y) * imageSize.height)
                            let right = Int(max(searchRectangle.topRight.x, searchRectangle.bottomRight.x) * imageSize.width)
                            let bottom = Int(max(searchRectangle.bottomLeft.y, searchRectangle.bottomRight.y) * imageSize.height)
                            let width = right - left
                            let height = bottom - top
                            guard width > 0, height > 0 else { continue }
                            tesseract.setRectangle(left: left, top: top, width: width, height: height)
                            try tesseract.recognize()
                            
                            let level = options.pageIteratorLevel
                            guard let iterator = tesseract.resultIterator() else {
                                self.wordRecognizeResults.value = results
                                return
                            }
                            repeat {
                                let text = iterator.text(level: level)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                let confidence = iterator.confidence(level: level)
                                let boundingBox = iterator.pageIterator().boundingBox(level: level)
                                let rectangle = Rectangle(
                                    topLeft: CGPoint(x: boundingBox.minX / imageSize.width, y: boundingBox.minY / imageSize.height),
                                    topRight: CGPoint(x: boundingBox.maxX / imageSize.width, y: boundingBox.minY / imageSize.height),
                                    bottomLeft: CGPoint(x: boundingBox.minX / imageSize.width, y: boundingBox.maxY / imageSize.height),
                                    bottomRight: CGPoint(x: boundingBox.maxX / imageSize.width, y: boundingBox.maxY / imageSize.height)
                                )
                                let result = TesseractWordRecognizeResult(text: text, confidence: confidence, rectangle: rectangle)
                                results.append(result)
                            } while iterator.next(level: level) == true
                        }   // end searchRectangle
                        
                    } catch {
                        //assertionFailure(error.localizedDescription)
                    }
                    
                    DispatchQueue.main.async {
                        self.wordRecognizeResults.value = results
                    }
                }
            }
            .store(in: &disposeBag)
    }
    
}
