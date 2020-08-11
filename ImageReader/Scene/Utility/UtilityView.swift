//
//  UtilityView.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-13.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI
import Vision
// import SwiftTesseract

struct ListPopoverBoundsPreferenceKey: PreferenceKey {
    typealias Value = [UUID:Anchor<CGRect>]
    
    static var defaultValue: Value = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct UtilityView: View {
    
    static let grideWidth: CGFloat = 80
    
    @EnvironmentObject var store: Store
    
    @State var selectTextObservation: VNRecognizedTextObservation?
    @State var showTextObservationPopover = false
    
    @State var isFLANNMatchingActive = false

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
                if store.utility.readerType == .tesseract {
                    tesseractUtilityView
                }
            }
        } // end VStack
        .font(.gridRegular)
    }
}

// MARK: - Vision
extension UtilityView {
    var visionUtilityView: some View {
        VStack(alignment: .leading) {
            visionSaliencyUtilityView
            Divider()
            visionTextRecognitionUtilityView
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
    
    static let saliencyMaskAlphaNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        return formatter
    }()
    
    var visionSaliencyUtilityView: some View {
        VStack(alignment: .leading) {
            Text("Saliency")
                .font(.caption)
            GridRow(title: "Kind") {
                Picker(selection: $store.utility.saliencyType, label: EmptyView()) {
                    ForEach(Store.Utility.SaliencyType.allCases, id: \.self) { saliencyType in
                        Text(saliencyType.text)
                            .tag(saliencyType)
                            .fixedSize()
                    }
                }
                .overlay(NSPickerConfigurator {
                    $0.segmentDistribution = .fillEqually
                })
                .pickerStyle(SegmentedPickerStyle())
                
            }
            GridRow(title: "Drawing") {
                VStack(alignment: .leading) {
                    Toggle("Mask", isOn: $store.utility.saliencyMaskEnabled)
                    Toggle("Bounding Box", isOn: $store.utility.sailencyBoundingBoxEnabled)
                }
            }
            GridRow(title: "Alpha") {
                TextField("Alpha", value: $store.utility.saliencyMaskAlpha, formatter: UtilityView.saliencyMaskAlphaNumberFormatter)
            }
        }
        .padding([.leading, .trailing])
    }
    
    var visionTextRecognitionUtilityView: some View {
        VStack(alignment: .leading) {
            Text("Text Recognition")
                .font(.caption)
            GridRow(title: "") {
                Toggle("Enabled", isOn: $store.utility.recognizeTextRequestOptions.enabled)
            }
            GridRow(title: "Options") {
                Toggle("CPU Only", isOn: $store.utility.recognizeTextRequestOptions.usesCPUOnly)
            }
            GridRow(title: "Level") {
                Picker(selection: $store.utility.recognizeTextRequestOptions.textRecognitionLevel, label: EmptyView()) {
                    ForEach(VNRequestTextRecognitionLevel.allCases, id: \.self) { level in
                        Text(level.text)
                    }
                }
            }
        }
        .padding([.leading, .trailing])
    }

}

// MARK: - OpenCV
extension UtilityView {
    static let minHessianNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    static let ratioThreashNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    var openCVUtilityView: some View {
        VStack(alignment: .leading) {
            openCVSURFFeatureDetectionUtilityView
            Divider()
            openCVFLANNFeatureMatchingUtilityView
            Divider()
            Spacer()
        }
    }
    
    var openCVSURFFeatureDetectionUtilityView: some View {
        return VStack(alignment: .leading) {
            Text("SURF Feature Detection")
                .font(.caption)
            GridRow(title: " ") {
                Toggle("Enabled", isOn: $store.utility.surfOptions.enabled)
            }
            GridRow(title: "Min Hessian") {
                TextField("Min Hessian", value: $store.utility.surfOptions.minHessian, formatter: UtilityView.minHessianNumberFormatter)
            }
        }
        .padding([.leading, .trailing])
    }
    
    var openCVFLANNFeatureMatchingUtilityView: some View {
        let flannMatchingDropDelegate = ImageDropDelegate(image: $store.utility.flannMatchingImage, isActive: $isFLANNMatchingActive)
        
        return VStack(alignment: .leading) {
            Text("FLANN Feature Maching")
                .font(.caption)
            GridRow(title: " ") {
                Toggle("Enabled", isOn: $store.utility.flannOptions.enabled)
            }
            GridRow(title: "Min Hessian") {
                TextField("Min Hessian", value: $store.utility.flannOptions.minHessian, formatter: UtilityView.minHessianNumberFormatter)
            }
            GridRow(title: "Lowe's ratio") {
                TextField("Lowe's ratio", value: $store.utility.flannOptions.ratioThresh, formatter: UtilityView.ratioThreashNumberFormatter)
            }
            GridRow(title: " ") {
                Image(nsImage: store.utility.flannMatchingImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    //.overlay(ImageOverlayView())
                    .background(Text("Drag and drop image here."))
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .background(isFLANNMatchingActive ? Color.green : Color.gray)
                    .onDrop(of: ImageDropDelegate.itemsType, delegate: flannMatchingDropDelegate)
            }
            GridRow(title: "Good Match") {
                HStack {
                    Text("\(store.content.flannFeatureMatchingResult.goodMatchCount)")
                    if store.content.flannFeatureMatchingResult.goodMatchCount < 4 {
                        Text("< 4, skipped")
                    }
                }
            }
            GridRow(title: "Determinant") {
                Text("\(store.content.flannFeatureMatchingResult.determinant)")
            }.padding(.top, 4)
            GridRow(title: "Preview", alignment: .center) {
                Button(action: {
                    guard let image = self.store.content.flannFeatureMatchingResult.previewImage else { return }
                    let hostingView = NSHostingView(rootView: self.createPreviewView(preview: image))
                    (NSApp.delegate as? AppDelegate)?.showWindow(with: hostingView)
                }, label: {
                    Text("Preview")
                }).disabled(store.content.flannFeatureMatchingResult.previewImage == nil)
            }
        }
        .padding([.leading, .trailing])
    }
    
    private func createPreviewView(preview image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

// MARK: - Tesseract
extension UtilityView {
    var tesseractUtilityView: some View {
        VStack(alignment: .leading) {
            tesseractTextRecognitionUtilityView
            Divider()
            List(store.content.tesseractWordRecognizeResults, id: \.id) { result in
                VStack(alignment: .leading) {
                    Text("\(result.text) - \(result.confidence)")
                    Divider()
                }
            }
            .listStyle(SidebarListStyle())
        }
    }

    var tesseractTextRecognitionUtilityView: some View {
        VStack(alignment: .leading) {
            Text("Text Recognition")
                .font(.caption)
            GridRow(title: " ") {
                Toggle("Enabled", isOn: $store.utility.tesseractOptions.enabled)
            }
            GridRow(title: " ") {
                Toggle("Vision Pre-Processing Enabled", isOn: $store.utility.enableVsionPreProcessing)
            }
            //GridRow(title: " ") {
            //    Toggle("Custom Enabled", isOn: $store.utility.tesseractOptions.isCustomEnabled)
            //}
            GridRow(title: "Language") {
                HStack {
                    Toggle("eng", isOn: $store.utility.tesseractOptions.engEnabled)
                    Toggle("chi_sim", isOn: $store.utility.tesseractOptions.chisimEnabled)
                    Toggle("NotoSans (best only)", isOn: $store.utility.tesseractOptions.bestNotoSansEnabled)
                        .disabled(store.utility.tesseractOptions.mode != .best)
                }
            }
//            GridRow(title: "Mode") {
//                Picker(selection: $store.utility.tesseractOptions.mode, label: EmptyView()) {
//                    ForEach(TesseractOptions.Mode.allCases, id: \.self) { mode in
//                        Text(mode.text)
//                    }
//                }
//            }
//            GridRow(title: "Segment") {
//                Picker(selection: $store.utility.tesseractOptions.pageSegmentMode, label: EmptyView()) {
//                    ForEach(Tesseract.PageSegMode.allCases, id: \.self) { mode in
//                        Text(mode.text)
//                    }
//                }
//            }
//            GridRow(title: "Level") {
//                Picker(selection: $store.utility.tesseractOptions.pageIteratorLevel, label: EmptyView()) {
//                    ForEach(Tesseract.PageIteratorLevel.allCases, id: \.self) { level in
//                        Text(level.text)
//                    }
//                }
//            }
        }
        .padding([.leading, .trailing])
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

struct GridRow<Content>: View where Content: View {
    
    let title: String
    let alignment: VerticalAlignment
    var content: Content
    
    init(title: String, alignment: VerticalAlignment = .firstTextBaseline, @ViewBuilder content: () -> Content) {
        self.title = title
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment) {
            Text(title)
                .font(.gridSubtitle)
                .frame(width: UtilityView.grideWidth, alignment: .trailing)
            content
        }
    }
    
}


protocol PickerOverlayViewDelegate {
    func viewDidMoveToSuperview(_ view: PickerOverlayView)
}

class PickerOverlayView: NSView {
    
    var delegate: PickerOverlayViewDelegate?
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        delegate?.viewDidMoveToSuperview(self)
    }
    
}

struct NSPickerConfigurator: NSViewRepresentable {
    
    var configure: (NSSegmentedControl) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = PickerOverlayView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
    
    }
    
    class Coordinator: PickerOverlayViewDelegate {
        let configurator: NSPickerConfigurator
        
        init(_ configurator: NSPickerConfigurator) {
            self.configurator = configurator
        }
        
        func viewDidMoveToSuperview(_ view: PickerOverlayView) {
            DispatchQueue.main.async {
                guard let holder = view.superview?.superview else {
                    return
                }
                
                for index in holder.subviews.indices {
                    let overlayViewParentViewIndex = index + 1
                    guard overlayViewParentViewIndex < holder.subviews.count else {
                        return
                    }
                    
                    guard holder.subviews[overlayViewParentViewIndex].subviews.first === view else {
                        continue
                    }
                    
                    guard let segmentedControl = holder.subviews[index].subviews.first as? NSSegmentedControl else {
                        assertionFailure("the overlay should slibling's subview of overlayed view")
                        return
                    }
                    
                    self.configurator.configure(segmentedControl)
                }
            }
        }
    }
    
}
