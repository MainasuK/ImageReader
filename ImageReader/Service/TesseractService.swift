//
//  TesseractService.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-21.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Cocoa
import Combine
import CommonOSLog
import SwiftTesseract

struct TesseractOptions {
    var enabled = true
    var pageSegmentMode = Tesseract.PageSegMode.SPARSE_TEXT
    var pageIteratorLevel = Tesseract.PageIteratorLevel.textline
}

final class TesseractService: ObservableObject {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let image = CurrentValueSubject<NSImage, Never>(NSImage())
    var imageSubscription: AnyCancellable?
    
    let tesseractOptions = CurrentValueSubject<TesseractOptions, Never>(TesseractOptions())
    var tesseractOptionsSubscription: AnyCancellable?
    
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
            
        Publishers
            .CombineLatest(throttledImagePublisher.eraseToAnyPublisher(), tesseractOptions.eraseToAnyPublisher())
            .sink { [weak self] image, options in
                guard let `self` = self else { return }
                
                // reset again to hint user update success
                self.wordRecognizeResults.send([])
                guard options.enabled else {
                    return
                }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    var results: [TesseractWordRecognizeResult] = []
                    let tesseract = Tesseract()
                    do {
                        let datapath = Bundle.main.resourceURL.flatMap { resourceURL -> URL? in
                            let tessdataBundleURL = resourceURL.appendingPathComponent("Tessdata.bundle")
                            return Bundle(url: tessdataBundleURL)?.resourceURL
                        }
                        
                        try tesseract.init3(datapath: datapath, language: .custom("chi_sim"))
                        //_ = tesseract.setVariable(name: "user_defined_dpi", value: "72")
                        tesseract.setPageSegMode(mode: options.pageSegmentMode)
                        try tesseract.setImage2(nsImage: image)
                        
                        guard let imageRep = image.representations.first else {
                            return
                        }
                        let imageSize = CGSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh)
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
                            
                            let result = TesseractWordRecognizeResult(text: text, confidence: confidence, boundingBox: boundingBox, imageSize: imageSize)
                            results.append(result)
                        } while iterator.next(level: level) == true
                        
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
