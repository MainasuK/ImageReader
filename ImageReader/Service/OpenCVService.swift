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

struct SURFOptions {
    var enabled = true
    var minHessian = 400.0
}

struct FLANNOptions {
    var enabled = true
    var minHessian = 400.0
    var ratioThresh = 0.8       // Lowe's ratio 0.4 ~ 0.6
}

final class OpenCVService: ObservableObject {

    var disposeBag = Set<AnyCancellable>()

    // input
    let image = CurrentValueSubject<NSImage, Never>(NSImage())
    var imageSubscription: AnyCancellable?

    let flannMatchingImage = CurrentValueSubject<NSImage, Never>(NSImage())
    var flannMatchingImageSubscription: AnyCancellable?
    
    let surfOptions = CurrentValueSubject<SURFOptions, Never>(SURFOptions())
    var surfOptionsSubscription: AnyCancellable?
    
    let flannOptions = CurrentValueSubject<FLANNOptions, Never>(FLANNOptions())
    var flannOptionsSubscription: AnyCancellable?
    
    // output
    let theSURFKeypoints = CurrentValueSubject<[OpenCVFeatureDetectionResult], Never>([])
    var theSURFKeypointsSubscription: AnyCancellable?
    
    let flannMacthingResult = CurrentValueSubject<OpenCVFeatureMatchingResult, Never>(OpenCVFeatureMatchingResult())
    var flannMacthingResultSubscription: AnyCancellable?
    
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
        
        let flannMatchingImagePublisher = flannMatchingImage.share()
        flannMatchingImagePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // reset output
                //self.theSURFKeypoints.send([])
            }
            .store(in: &disposeBag)
        
        let throttledFLANNMatchingImagePublisher = flannMatchingImagePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .share()
        
        Publishers.CombineLatest3(throttledImagePublisher, throttledFLANNMatchingImagePublisher, flannOptions)
            .map { image, matchingImage, options -> AnyPublisher<OpenCVFeatureMatchingResult, Never> in
                guard image.isValid && matchingImage.isValid, image.size != .zero, matchingImage.size != .zero else {
                    return Just(OpenCVFeatureMatchingResult()).eraseToAnyPublisher()
                }
                
                return Future<OpenCVFeatureMatchingResult, Never> { promise in
                    let detector = CVBSURF(hessianThreshold: options.minHessian)
                    
                    let object = CVBMat(nsImage: matchingImage)
                    let objectKeypointsDescriptor = CVBMat()
                    let objectKeypoints = detector.detectAndCompute(object, mask: nil, descriptors: objectKeypointsDescriptor)
                    
                    let scene = CVBMat(nsImage: image)
                    let sceneKeypointsDescriptor = CVBMat()
                    let sceneKeypoints = detector.detectAndCompute(scene, mask: nil, descriptors: sceneKeypointsDescriptor)
                    
                    let matcher = CVBDescriptorMatcher(descriptorMatcherType: .FLANNBASED)
                    let knnMatches = matcher.knnMatch(objectKeypointsDescriptor, descriptor2: sceneKeypointsDescriptor, k: 2)
                    
                    // Filter matches using the Lowe's ratio test
                    let ratioThresh = options.ratioThresh
                    var goodMatches: [CVBDMatch] = []
                    for i in knnMatches.indices {
                        if knnMatches[i][0].distance < Float(ratioThresh) * knnMatches[i][1].distance {
                            goodMatches.append(knnMatches[i][0])
                        }
                    }
                    
                    guard goodMatches.count >= 4 else {
                        DispatchQueue.main.async {
                            let result = OpenCVFeatureMatchingResult(goodMatchCount: goodMatches.count, determinant: 0, rectangle: nil)
                            promise(.success(result))
                        }
                        return
                    }
                    
                    // Localize the object
                    var objectPoints: [CGPoint] = []
                    var scenePoints: [CGPoint] = []
                    for i in goodMatches.indices {
                        objectPoints.append(objectKeypoints[Int(goodMatches[i].queryIdx)].pt)
                        scenePoints.append(sceneKeypoints[Int(goodMatches[i].trainIdx)].pt)
                    }
                    let H = CVBCalib3D.findHomography2f(objectPoints.map { NSValue(point: $0) },
                                                        dst: scenePoints.map { NSValue(point: $0) },
                                                        method: .RANSAC)
                    let determinant = H.empty() ? 0.0 : CVBCore.determinant(H)
                
                    let objectRect: [CGPoint] = [
                        CGPoint.zero,
                        CGPoint(x: Int(object.cols()), y: 0),
                        CGPoint(x: Int(object.cols()), y: Int(object.rows())),
                        CGPoint(x: 0, y: Int(object.rows())),
                    ]
                    
                    let objectRectValue = objectRect.map { NSValue(point: $0) }
                    let objectRectInScene: [CGPoint] = {
                        guard !H.empty() else {
                            return Array(repeating: CGPoint.zero, count: 4)
                        }
                        
                        return CVBCore.perspectiveTransform2f(objectRectValue, m: H).map { $0.pointValue }
                    }()
                    let rectangle = Rectangle(topLeft: objectRectInScene[0],
                                              topRight: objectRectInScene[1],
                                              bottomLeft: objectRectInScene[2],
                                              bottomRight: objectRectInScene[3])
                    
                    // Draw preview image
                    let previewImage = CVBMat()
                    CVBFeatures2D.drawMatches(object, keypoints1: objectKeypoints, img2: scene, keypoints2: sceneKeypoints, matches: goodMatches, outImg: previewImage)
                    let objectRectInPreview: [CGPoint] = objectRectInScene.map { CGPoint(x: $0.x + CGFloat(object.cols()), y: $0.y) }
                    // RGB red color -> BGR blue color
                    CVBimgproc.line(previewImage, pt1: objectRectInPreview[0], pt2: objectRectInPreview[1], color: .red, thickness: 4)
                    CVBimgproc.line(previewImage, pt1: objectRectInPreview[1], pt2: objectRectInPreview[2], color: .red, thickness: 4)
                    CVBimgproc.line(previewImage, pt1: objectRectInPreview[2], pt2: objectRectInPreview[3], color: .red, thickness: 4)
                    CVBimgproc.line(previewImage, pt1: objectRectInPreview[3], pt2: objectRectInPreview[0], color: .red, thickness: 4)
                    let previewCGImage = previewImage.imageRef().takeRetainedValue()
                    let result = OpenCVFeatureMatchingResult(goodMatchCount: goodMatches.count,
                                                             determinant: determinant,
                                                             rectangle: rectangle,
                                                             previewImage: NSImage(cgImage: previewCGImage, size: .zero))
                    DispatchQueue.main.async {
                        promise(.success(result))
                    }
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .assign(to: \.value, on: flannMacthingResult)
            .store(in: &disposeBag)
        
    }
    
}
