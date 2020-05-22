//
//  ContentView.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-12.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI
import CommonOSLog

struct ContentView: View {

    @EnvironmentObject var store: Store
    @ObservedObject var visionService = VisionService()
    @ObservedObject var tesseractService = TesseractService()

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
            // subscribe image
            self.visionService.imageSubscription = self.store.content.imagePublisher.assign(to: \.value, on: self.visionService.image)
            self.tesseractService.imageSubscription = self.store.content.imagePublisher.assign(to: \.value, on: self.tesseractService.image)
            
            // subscribe options
            self.visionService.recognizeTextRequestOptionsSubscription = self.store.utility.recognizeTextRequestOptionsPublisher
                .assign(to: \.value, on: self.visionService.recognizeTextRequestOptions)
            self.tesseractService.tesseractOptionsSubscription = self.store.utility.tesseractOptionsPublisher
                .assign(to: \.value, on: self.tesseractService.tesseractOptions)
            
            // bind textObservations output to store
            self.visionService.textObservationsSubscription = self.visionService.textObservations
                .assign(to: \.content.textObservations, on: self.store)
            // bind attentionBasedSaliencyImageObservations to store
            self.visionService.attentionBasedSaliencyImageObservationSubscription = self.visionService.attentionBasedSaliencyImageObservation
                .assign(to: \.content.attentionBasedSaliencyImageObservations, on: self.store)
            // bind objectnessBasedSaliencyImageObservations to store
            self.visionService.objectnessBasedSaliencyImageObservationSubscription = self.visionService.objectnessBasedSaliencyImageObservation
                .assign(to: \.content.objectnessBasedSaliencyImageObservations, on: self.store)
            // bind wordRecognizeResults to store
            self.tesseractService.wordRecognizeResultsSubscription = self.tesseractService.wordRecognizeResults
                .assign(to: \.content.tesseractWordRecognizeResults, on: self.store)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
