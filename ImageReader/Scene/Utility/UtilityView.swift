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
        
    var body: some View {
        VStack {
            // Reader picker
            Picker(selection: $store.utility.readerType, label: EmptyView()) {
                ForEach(Store.Utility.ReaderType.allCases, id: \.self) {
                    Text($0.text)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
            Divider()
            VStack {
                if store.utility.readerType == .vision {
                    visionUtilityView
                }
                if store.utility.readerType == .opencv {
                    openCVUtilityView
                }
            }
        }   // end VStack
    }
}

extension UtilityView {
    var visionUtilityView: some View {
        VStack(alignment: .leading) {
            Text("Text Recognition")
                .font(.caption)
                .padding(.leading)
            HStack {
                Toggle("Enabled", isOn: $store.utility.recognizeTextRequestOptions.enabled)
                Toggle("CPU Only", isOn: $store.utility.recognizeTextRequestOptions.usesCPUOnly)
                Picker("Level", selection: $store.utility.recognizeTextRequestOptions.textRecognitionLevel) {
                    ForEach(VNRequestTextRecognitionLevel.allCases, id: \.self) { level in
                        Text(level.text)
                    }
                }
            }
            .padding([.leading, .trailing])
            Divider()
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
    
    var openCVUtilityView: some View {
        VStack {
            Spacer()
        }
    }
}


struct UtilityView_Previews: PreviewProvider {
    
    static func store(for readType: Store.Utility.ReaderType) -> Store {
        let store = Store()
        store.utility.readerType = readType
        return store
    }
    
    static var previews: some View {
        return Group {
            ForEach(Store.Utility.ReaderType.allCases, id: \.self) { type in
                UtilityView().environmentObject(store(for: type))
                    .previewLayout(.fixed(width: 400, height: 300))
                    .previewDisplayName(type.text)
                
            }
        }
    }
}
