//
//  UtilityView.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-13.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI
import Vision

struct ListPopoverBoundsPreferenceKey: PreferenceKey {
    typealias Value = [UUID:Anchor<CGRect>]
    
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct UtilityView: View {
    
    @EnvironmentObject var store: Store
    
    @State var selectTextObservation: VNRecognizedTextObservation?
    @State var showTextObservationPopover = false
    
    // @State var tuple: (listPopoverAttachmentAnchor: PopoverAttachmentAnchor, : Bool) = (PopoverAttachmentAnchor.rect(.bounds), false)
    
    var body: some View {
        VStack {
//            Picker(selection: $store.utility.readerType, label: EmptyView()) {
//                ForEach(Store.Utility.ReaderType.allCases, id: \.self) {
//                    Text($0.text)
//                }
//            }.pickerStyle(SegmentedPickerStyle())
            
//            if store.utility.readerType == .text {
//                Text("Text")
//            }
            
            List(store.content.textObservations, id: \.self) { observation  in
                VStack(alignment: .leading) {
                    Text("confidence: \(observation.confidence)")
                        .onTapGesture {
                            self.selectTextObservation = observation
                            self.showTextObservationPopover = true
                        }
                        .anchorPreference(key: ListPopoverBoundsPreferenceKey.self, value: .bounds, transform: { [observation.uuid: $0] })
                    ForEach(observation.topCandidates(10), id: \.self) { text in
                        Text("\(text.confidence): \(text.string)")
                    }
                    Divider()
                }
            }
            .listStyle(SidebarListStyle())
            .overlayPreferenceValue(ListPopoverBoundsPreferenceKey.self, { value in
                // Popover
                GeometryReader { proxy in
                    return Group {
                        if self.selectTextObservation == nil {
                            EmptyView()
                        } else {
                            if value[self.selectTextObservation!.uuid] != nil {
                                Color.clear
                                    .frame(
                                        width: proxy[value[self.selectTextObservation!.uuid]!].width,
                                        height: proxy[value[self.selectTextObservation!.uuid]!].height
                                    )
                                    .popover(isPresented: self.$showTextObservationPopover) {
                                        return Group {
                                            if self.selectTextObservation == nil {
                                                Text("No Selection")
                                            } else {
                                                VStack {
                                                    Text("\(self.selectTextObservation!.uuid)")
                                                    Text("topLeft: " + String(describing: self.selectTextObservation!.topLeft))
                                                    Text("topRight: " + String(describing: self.selectTextObservation!.topRight))
                                                    Text("bottomLeft: " + String(describing: self.selectTextObservation!.bottomLeft))
                                                    Text("bottomRight: " + String(describing: self.selectTextObservation!.bottomRight))
                                                    Text(String(describing: self.selectTextObservation!.boundingBox))
                                                }
                                            }
                                        }
                                        .frame(minWidth: 400, minHeight: 44)
                                    }
                                    .offset(
                                        x: proxy[value[self.selectTextObservation!.uuid]!].minX,
                                        y: proxy[value[self.selectTextObservation!.uuid]!].minY
                                    )
                                    
                            } else {
                                Color.clear
                            }
                        }
                    }
                }   // end GeometryReader
            })  // end .overlayPreferenceValue
        }   // end VStack
    }
}
