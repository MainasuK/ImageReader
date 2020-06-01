//
//  OpenCVService.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-6-1.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Cocoa
import Combine
import CommonOSLog
import OpenCVBridge

struct SURFfOptions {
    var enabled = true
    var minHessian = 400.0
}

final class OpenCVService: ObservableObject {

    var disposeBag = Set<AnyCancellable>()

    // input
    let image = CurrentValueSubject<NSImage, Never>(NSImage())
    var imageSubscription: AnyCancellable?
    
    let surfOptions = CurrentValueSubject<SURFfOptions, Never>(SURFfOptions())
    var surfOptionsSubscription: AnyCancellable?
    
    // output
    let theSURFKeypoints = CurrentValueSubject<[OpenCVFeatureDetectionResult], Never>([])
    var theSURFKeypointsSubscription: AnyCancellable?
    
    init() {
        let imagePublisher = image.share()
        imagePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // reset output
                self.theSURFKeypoints.send([])
            }
            .store(in: &disposeBag)
        
        let throttledImagePublisher = imagePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .share()
        
        Publishers.CombineLatest(throttledImagePublisher, surfOptions)
            .map { image, options -> AnyPublisher<[OpenCVFeatureDetectionResult], Never> in
                guard options.enabled else {
                    return Just([]).eraseToAnyPublisher()
                }
                
                return Future<[OpenCVFeatureDetectionResult], Never> { promise in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let detector = CVBSURF(hessianThreshold: options.minHessian)
                        let img = CVBMat(nsImage: image)
                        let keypoints = detector.detect(img)
                        
                        let width = CGFloat(img.cols())
                        let height = CGFloat(img.rows())
                        let results = keypoints.map { keypoint in
                            OpenCVFeatureDetectionResult(point: CGPoint(x: keypoint.pt.x / width, y: keypoint.pt.y / height),
                                                         keypoint: keypoint)
                        }
                        DispatchQueue.main.async {
                            promise(.success(results))
                        }
                    }
                }.eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .assign(to: \.value, on: self.theSURFKeypoints)
            .store(in: &disposeBag)
    }
    
}
