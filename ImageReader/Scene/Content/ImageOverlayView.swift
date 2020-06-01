//
//  ImageOverlayView.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-16.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Cocoa
import SwiftUI
import Vision
import GameKit

struct ImageOverlayView: View {
    
    @EnvironmentObject var store: Store
    
    var body: some View {
        GeometryReader { proxy in
            self.visionOverlay(proxy: proxy)
            self.openCVOverlay(proxy: proxy)
            self.tesseractOverlay(proxy: proxy)
        }
    }
    
}

// MARK: - Vision
extension ImageOverlayView {
    private func visionOverlay(proxy: GeometryProxy) -> some View {
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
            Path { path in
                for observation in self.store.content.textObservations {
                    path.move(to: CGPoint(x: proxy.size.width * observation.topLeft.x, y: proxy.size.height * (1 - observation.topLeft.y)))
                    path.addLine(to: CGPoint(x: proxy.size.width * observation.topRight.x, y: proxy.size.height * (1 - observation.topRight.y)))
                    path.addLine(to: CGPoint(x: proxy.size.width * observation.bottomRight.x, y: proxy.size.height * (1 - observation.bottomRight.y)))
                    path.addLine(to: CGPoint(x: proxy.size.width * observation.bottomLeft.x, y: proxy.size.height * (1 - observation.bottomLeft.y)))
                    path.closeSubpath()
                }
            }
            .stroke(Color.red, lineWidth: 2)
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
    }
    
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

extension ImageOverlayView {
    private func openCVOverlay(proxy: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            // SURF feature points
            surfFeaturePointOverlay(in: proxy).drawingGroup()
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        .drawingGroup()
    }
    
    private func surfFeaturePointOverlay(in proxy: GeometryProxy) -> some View {
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: nil,
                                width: Int(proxy.size.width * scale),
                                height: Int(proxy.size.height * scale),
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)!

        let r: CGFloat = 3.0
        context.setLineWidth(1 * scale)
        for result in self.store.content.surfKeypoints {
            let seed = UInt64(result.keypoint.response)
            context.setStrokeColor(NSColor.random(seed: seed).cgColor)
            context.addEllipse(in:
                CGRect(
                    x: result.point.x * proxy.size.width * scale - r,
                    y: (1 - result.point.y) * proxy.size.height * scale - r,
                    width: 2 * r,
                    height: 2 * r
                )
            )
            context.drawPath(using: .stroke)
        }
        
        let cgImage = context.makeImage()!
        return Image(decorative: cgImage, scale: scale)
    }
}

fileprivate extension NSColor {
    static func random(seed: UInt64) -> NSColor {
        let rng = GKMersenneTwisterRandomSource(seed: seed)
        let red =   rng.nextInt(upperBound: 255)
        let green = rng.nextInt(upperBound: 255)
        let blue =  rng.nextInt(upperBound: 255)
        let color = NSColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        return color
    }
}

// MARK: - Tesseract
extension ImageOverlayView {
    private func tesseractOverlay(proxy: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            // Word Recognize
            ForEach(self.store.content.tesseractWordRecognizeResults, id: \.id) { result in
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width * result.rectangle.topLeft.x, y: proxy.size.height * result.rectangle.topLeft.y))
                    path.addLine(to: CGPoint(x: proxy.size.width * result.rectangle.topRight.x, y: proxy.size.height * result.rectangle.topRight.y))
                    path.addLine(to: CGPoint(x: proxy.size.width * result.rectangle.bottomRight.x, y: proxy.size.height * result.rectangle.bottomRight.y))
                    path.addLine(to: CGPoint(x: proxy.size.width * result.rectangle.bottomLeft.x, y: proxy.size.height * result.rectangle.bottomLeft.y))
                    path.closeSubpath()
                }
                .stroke(Color.blue, lineWidth: 2)
            }
            
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
    }
}
