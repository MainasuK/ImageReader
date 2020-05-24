//
//  VisionService.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-16.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Cocoa
import Combine
import Vision
import CommonOSLog

struct RequestHandlerOptions { }

protocol RequestOptions  {
    associatedtype Request: VNRequest
    
    var enabled: Bool { get set }
    var usesCPUOnly: Bool { get set }
    func update(request: Request)
}

struct RecognizeTextRequestOptions: RequestOptions {
    typealias Request = VNRecognizeTextRequest
    
    var enabled = true
    var usesCPUOnly = false
    var textRecognitionLevel: VNRequestTextRecognitionLevel = .accurate
    
    func update(request: VNRecognizeTextRequest) {
        request.usesCPUOnly = usesCPUOnly
        request.recognitionLevel = textRecognitionLevel
    }
}

struct GenerateImageFeaturePrintRequestOptions: RequestOptions {
    typealias Request = VNGenerateImageFeaturePrintRequest
    
    var enabled = true
    var usesCPUOnly = false
    
    func update(request: VNGenerateImageFeaturePrintRequest) {
        request.usesCPUOnly = usesCPUOnly
    }
    
}

struct ImageBasedRequestOptions: RequestOptions {
    typealias Request = VNImageBasedRequest
    
    var enabled = true
    var usesCPUOnly = false
    
    func update(request: VNImageBasedRequest) {
        request.usesCPUOnly = usesCPUOnly
    }
    
}

final class VisionService: ObservableObject {
    
    var disposeBag = Set<AnyCancellable>()
    
    // Recognize Text
    private(set) lazy var recognizeTextRequest: VNRecognizeTextRequest = VNRecognizeTextRequest(completionHandler: self.recognizeTextRequestCompletionHandler)
    
    // Image Feature Print
    private(set) lazy var generateImageFeaturePrintRequest = VNGenerateImageFeaturePrintRequest(completionHandler: self.featurePrintRequestCompletionHandler)
    
    // Attention Based Saliency
    private(set) lazy var generateAttentionBasedSaliencyImageRequest = VNGenerateAttentionBasedSaliencyImageRequest(completionHandler: self.generateAttentionBasedSaliencyImageRequestCompletionHandler)
    
    // Objectness Based Saliency
    private(set) lazy var generateObjectnessBasedSaliencyImageRequest = VNGenerateObjectnessBasedSaliencyImageRequest(completionHandler: self.generateObjectnessBasedSaliencyImageRequestCompletionHandler)

    // input
    let image = CurrentValueSubject<NSImage, Never>(NSImage())
    var imageSubscription: AnyCancellable?

    let imageRequestHandlerOptions = CurrentValueSubject<RequestHandlerOptions, Never>(RequestHandlerOptions())
    
    let recognizeTextRequestOptions = CurrentValueSubject<RecognizeTextRequestOptions, Never>(RecognizeTextRequestOptions())
    var recognizeTextRequestOptionsSubscription: AnyCancellable?

    let generateImageFeaturePrintRequestOptions = CurrentValueSubject<GenerateImageFeaturePrintRequestOptions, Never>(GenerateImageFeaturePrintRequestOptions())
    
    let generateAttentionBasedSaliencyImageRequestOptions = CurrentValueSubject<ImageBasedRequestOptions, Never>(ImageBasedRequestOptions())
    let generateObjectnessBasedSaliencyImageRequestOptions = CurrentValueSubject<ImageBasedRequestOptions, Never>(ImageBasedRequestOptions())

    // output
    private let imageRequestHandler = PassthroughSubject<VNImageRequestHandler, Never>()
    let textObservations = PassthroughSubject<[VNRecognizedTextObservation], Never>()
    var textObservationsSubscription: AnyCancellable?
    
    let attentionBasedSaliencyImageObservation = PassthroughSubject<[VNSaliencyImageObservation], Never>()
    var attentionBasedSaliencyImageObservationSubscription: AnyCancellable?
    
    let objectnessBasedSaliencyImageObservation = PassthroughSubject<[VNSaliencyImageObservation], Never>()
    var objectnessBasedSaliencyImageObservationSubscription: AnyCancellable?
    
    init() {
        let imagePublisher = image.share()
        imagePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // reset output
                self.textObservations.send([])
            }
            .store(in: &disposeBag)
        
        let cgImagePublisher = imagePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .compactMap { image -> CGImage? in image.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            .share()
        
        Publishers
            .CombineLatest(cgImagePublisher.eraseToAnyPublisher(), imageRequestHandlerOptions.eraseToAnyPublisher())
            .map { cgImage, options -> VNImageRequestHandler in
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                return requestHandler
            }
            .sink { [weak self] requestHandler in
                self?.imageRequestHandler.send(requestHandler)
            }
            .store(in: &disposeBag)
        
        
        // Recognize Text
        Publishers
            .CombineLatest(imageRequestHandler.eraseToAnyPublisher(), recognizeTextRequestOptions.eraseToAnyPublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requestHandler, options in
                guard let `self` = self else { return }
                
                let request = self.recognizeTextRequest
                request.cancel()
                options.update(request: request)
                    
                // reset again to hint user update success
                self.textObservations.send([])
                guard options.enabled else { return }
                // perform new request
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try requestHandler.perform([request])
                    } catch {
                        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: text recognition perform get error: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    }
                }
            }
            .store(in: &disposeBag)

        // Generate Image Feature Print
        Publishers
            .CombineLatest(imageRequestHandler.eraseToAnyPublisher(), generateImageFeaturePrintRequestOptions.eraseToAnyPublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requestHandler, options in
                guard let `self` = self else { return }
                
                let request = self.generateImageFeaturePrintRequest
                request.cancel()
                options.update(request: request)
                
                // perform new request
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try requestHandler.perform([request])
                    } catch {
                        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: feature print perform get error: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    }
                }
            }
            .store(in: &disposeBag)
        
        // Attention Based Saliency
        Publishers
            .CombineLatest(imageRequestHandler.eraseToAnyPublisher(), generateAttentionBasedSaliencyImageRequestOptions.eraseToAnyPublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requestHandler, options in
                guard let `self` = self else { return }
                
                let request = self.generateAttentionBasedSaliencyImageRequest
                request.cancel()
                options.update(request: request)
                
                // perform new request
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try requestHandler.perform([request])
                    } catch {
                        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: attention based saliency perform get error: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    }
                }
            }
            .store(in: &disposeBag)

        // Objectness Based Saliency
        Publishers
            .CombineLatest(imageRequestHandler.eraseToAnyPublisher(), generateObjectnessBasedSaliencyImageRequestOptions.eraseToAnyPublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requestHandler, options in
                guard let `self` = self else { return }
                
                let request = self.generateObjectnessBasedSaliencyImageRequest
                request.cancel()
                options.update(request: request)
                
                // perform new request
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try requestHandler.perform([request])
                    } catch {
                        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: objectness based saliency perform get error: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    }
                }
            }
            .store(in: &disposeBag)
    }
    
}

extension VisionService {
    
    func recognizeTextRequestCompletionHandler(request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            os_log(.info, log: .logic, "%{public}s[%{public}ld], %{public}s: textRecognitionRequest callback with request: %s, error: %s", ((#file as NSString).lastPathComponent), #line, #function, request.debugDescription, error.debugDescription)
            
            guard let request = request as? VNRecognizeTextRequest else { return }
            guard let result = request.results as? [VNRecognizedTextObservation] else { return }
            
            // print(result.first.debugDescription)
            self.textObservations.send(result)
        }
    }
    
    func featurePrintRequestCompletionHandler(request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            os_log(.info, log: .logic, "%{public}s[%{public}ld], %{public}s: featurePrint callback with request: %s, error: %s", ((#file as NSString).lastPathComponent), #line, #function, request.debugDescription, error.debugDescription)
            
            guard let request = request as? VNGenerateImageFeaturePrintRequest else { return }
            guard let result = request.results as? [VNFeaturePrintObservation] else { return }
            
            print(result.first.debugDescription)
        }
    }
    
    func generateAttentionBasedSaliencyImageRequestCompletionHandler(request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            os_log(.info, log: .logic, "%{public}s[%{public}ld], %{public}s: generateAttentionBasedSaliencyImageRequest callback with request: %s, error: %s", ((#file as NSString).lastPathComponent), #line, #function, request.debugDescription, error.debugDescription)
            
            guard let request = request as? VNGenerateAttentionBasedSaliencyImageRequest else { return }
            guard let results = request.results as? [VNSaliencyImageObservation] else {
                return
            }
            
            self.attentionBasedSaliencyImageObservation.send(results)
        }
    }
    
    func generateObjectnessBasedSaliencyImageRequestCompletionHandler(request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            os_log(.info, log: .logic, "%{public}s[%{public}ld], %{public}s: generateObjectnessBasedSaliencyImageRequest callback with request: %s, error: %s", ((#file as NSString).lastPathComponent), #line, #function, request.debugDescription, error.debugDescription)
            
            guard let request = request as? VNGenerateObjectnessBasedSaliencyImageRequest else { return }
            guard let results = request.results as? [VNSaliencyImageObservation] else {
                return
            }
    
            self.objectnessBasedSaliencyImageObservation.send(results)
        }
    }
    
}
