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
            self.visionService.imageSubscription = self.store.content.imagePublisher
                .assign(to: \.value, on: self.visionService.image)
            // bind textObservations output to store
            self.visionService.textObservationsSubscription = self.visionService.textObservations
                .assign(to: \.content.textObservations, on: self.store)
            // subscribe recognizeTextRequestOptions.textRecognitionLevel
            self.visionService.recognizeTextRequestOptionsSubscription = self.store.utility.recognizeTextRequestOptionsPublisher
                .sink(receiveValue: { options in
                    self.visionService.recognizeTextRequestOptions.value = options
                })
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
