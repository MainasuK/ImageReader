//
//  ContentView.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-12.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI
import CommonOSLog

import Vision
import Combine

final class VisionService: ObservableObject {

    var disposeBag = Set<AnyCancellable>()
    var imageObservation: AnyCancellable?
    var textObservationsSubscription: AnyCancellable?
    
    private(set) var requestHandler: VNImageRequestHandler?
    private(set) lazy var textRecognitionRequest: VNRecognizeTextRequest = VNRecognizeTextRequest(completionHandler: self.recognizeTextRequestCompletionHandler)
    private(set) lazy var featurePrintRequest = VNGenerateImageFeaturePrintRequest(completionHandler: self.featurePrintRequestCompletionHandler)
    
    private(set) var featurePrintRequestHandler: VNImageRequestHandler?
    
    let image = CurrentValueSubject<NSImage, Never>(NSImage())
    let textObservations = PassthroughSubject<[VNRecognizedTextObservation], Never>()
    
    init() {
        let imagePublisher = image.share()
        
        imagePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                self.textObservations.send([])
            }
            .store(in: &disposeBag)
        
        let cgImagePublisher = imagePublisher
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .compactMap { image in image.cgImage(forProposedRect: nil, context: nil, hints: nil) }
            .share()
            
        cgImagePublisher
            .receive(on: DispatchQueue.main)
            .sink { cgImage in
                // cancel task
                self.textRecognitionRequest.cancel()
                self.featurePrintRequest.cancel()
                self.requestHandler = nil

                // perform request
                self.requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try self.requestHandler?.perform([self.textRecognitionRequest])
                    } catch {
                        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: text recognition perform get error: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    }
                    do {
                        try self.requestHandler?.perform([self.featurePrintRequest])
                    } catch {
                        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: feature print perform get error: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
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
            
            print(result.first.debugDescription)
            self.textObservations.send(result)
        }
    }
    
    func featurePrintRequestCompletionHandler(request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            os_log(.info, log: .logic, "%{public}s[%{public}ld], %{public}s: featurePrint callback with request: %s, error: %s", ((#file as NSString).lastPathComponent), #line, #function, request.debugDescription, error.debugDescription)
            
            guard let request = request as? VNGenerateImageFeaturePrintRequest else { return }
            guard let result = request.results as? [VNFeaturePrintObservation] else { return }
            
            print(result.first.debugDescription)
//            self.textObservations.send(result)
        }
    }

}

struct ImageOverlayView: View {

    @EnvironmentObject var store: Store

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(self.store.content.textObservations, id: \.self) { observation in
                    Path { path in
                        path.move(to: CGPoint(x: proxy.size.width * observation.topLeft.x, y: proxy.size.height * (1 - observation.topLeft.y)))
                        path.addLine(to: CGPoint(x: proxy.size.width * observation.topRight.x, y: proxy.size.height * (1 - observation.topRight.y)))
                        path.addLine(to: CGPoint(x: proxy.size.width * observation.bottomRight.x, y: proxy.size.height * (1 - observation.bottomRight.y)))
                        path.addLine(to: CGPoint(x: proxy.size.width * observation.bottomLeft.x, y: proxy.size.height * (1 - observation.bottomLeft.y)))
                        path.closeSubpath()
                    }
                    .stroke(Color.red, lineWidth: 2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

struct ContentView: View {

    @EnvironmentObject var store: Store
    @ObservedObject var visionService = VisionService()

    @State var isActive = false

    var body: some View {
        let dropDelegate = ImageDropDelegate(image: $store.content.image, isActive: $isActive)
        
        return HStack(spacing: 0) {
            Image(nsImage: store.content.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(ImageOverlayView())
                .background(Text("Drag and drop image here."))
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                .background(isActive ? Color.green : Color.gray)
                .onDrop(of: ["public.file-url"], delegate: dropDelegate)
            UtilityView()
                .frame(width: 400)
        }
        .frame(minHeight: 400)
        .onAppear {
            self.visionService.imageObservation = self.store.content.imagePublisher
                .assign(to: \.value, on: self.visionService.image)
            self.visionService.textObservationsSubscription = self.visionService.textObservations
                .assign(to: \.content.textObservations, on: self.store)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
