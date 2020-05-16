//
//  ImageOverlayView.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-16.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI

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
