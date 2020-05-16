//
//  ImageOverlayView.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-16.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI
import Vision

struct ImageOverlayView: View {
    
    @EnvironmentObject var store: Store
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // Attention Based Saliency
                if self.store.utility.saliencyType == .attention {
                    ForEach(self.store.content.attentionBasedSaliencyImageObservations, id: \.self) { observation in
                        Group {
                            if self.store.utility.saliencyMaskEnabled {
                                self.heatmap(fromSaliencyImageObservation: observation, size: proxy.size, maskAlpha: self.store.utility.saliencyMaskAlpha)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                            if self.store.utility.sailencyBoundingBoxEnabled {
                                self.salientObjectBoxes(fromSaliencyImageObservation: observation, size: proxy.size)
                                     .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                        }
                    }
                }
                // Objectness Based Saliency
                if self.store.utility.saliencyType == .objectness {
                    ForEach(self.store.content.objectnessBasedSaliencyImageObservations, id: \.self) { observation in
                        Group {
                            if self.store.utility.saliencyMaskEnabled {
                                self.heatmap(fromSaliencyImageObservation: observation, size: proxy.size, maskAlpha: self.store.utility.saliencyMaskAlpha)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                            if self.store.utility.sailencyBoundingBoxEnabled {
                                self.salientObjectBoxes(fromSaliencyImageObservation: observation, size: proxy.size)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                        }
                    }
                }
                // Text Observations
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

extension ImageOverlayView {
    
    func heatmap(fromSaliencyImageObservation observation: VNSaliencyImageObservation, size: CGSize, maskAlpha: CGFloat) -> some View {
        let ciImage = CIImage(cvPixelBuffer: observation.pixelBuffer)
    
        let saliencyImage = ciImage.applyingFilter("CIColorMatrix", parameters:
            [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: maskAlpha),
            ]
        )
        
        let cgImage = CIContext().createCGImage(saliencyImage, from: saliencyImage.extent)!
        let nsImage = NSImage(cgImage: cgImage, size: size)
        return Image(nsImage: nsImage)
            .resizable()
    }
    
    func salientObjectBoxes(fromSaliencyImageObservation observation: VNSaliencyImageObservation, size: CGSize) -> some View {
        Path { path in
            guard let objects = observation.salientObjects else { return }
            for object in objects {
                path.move(to: CGPoint(x: size.width * object.topLeft.x, y: size.height * (1 - object.topLeft.y)))
                path.addLine(to: CGPoint(x: size.width * object.topRight.x, y: size.height * (1 - object.topRight.y)))
                path.addLine(to: CGPoint(x: size.width * object.bottomRight.x, y: size.height * (1 - object.bottomRight.y)))
                path.addLine(to: CGPoint(x: size.width * object.bottomLeft.x, y: size.height * (1 - object.bottomLeft.y)))
                path.closeSubpath()
            }
        }
        .stroke(Color.yellow, lineWidth: 2)
    }
}
