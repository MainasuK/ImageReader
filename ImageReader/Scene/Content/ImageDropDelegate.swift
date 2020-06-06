//
//  ImageDropDelegate.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-12.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI
import Combine
import CommonOSLog

struct ImageDropDelegate: DropDelegate {
    
    @Binding var image: NSImage
    @Binding var isActive: Bool
    
    static let itemsType = ["public.file-url", "public.jpeg", "public.tiff"]
    
    func dropEntered(info: DropInfo) {
        os_log(.info, log: .interaction, "%{public}s[%{public}ld], %{public}s: %s", ((#file as NSString).lastPathComponent), #line, #function, String(describing: info))
        isActive = true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // os_log(.info, log: .interaction, "%{public}s[%{public}ld], %{public}s: %s", ((#file as NSString).lastPathComponent), #line, #function, String(describing: info))
        
        return nil
    }
    
    func dropExited(info: DropInfo) {
        os_log(.info, log: .interaction, "%{public}s[%{public}ld], %{public}s: %s", ((#file as NSString).lastPathComponent), #line, #function, String(describing: info))
        
        isActive = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        os_log(.info, log: .interaction, "%{public}s[%{public}ld], %{public}s: %s", ((#file as NSString).lastPathComponent), #line, #function, String(describing: info))
        
        guard let firstItem = validItems(for: info, types: ImageDropDelegate.itemsType).first else {
            return false
        }
        
        loadImage(from: firstItem, type: firstItem.registeredTypeIdentifiers.first ?? "") { image in
            guard let image = image else { return }
            DispatchQueue.main.async {
                self.image = image
            }
        }
        
        return true
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: ImageDropDelegate.itemsType)
    }
    
}

extension ImageDropDelegate {
    
    private func validItems(for info: DropInfo, types: [String]) -> [NSItemProvider] {
        types.compactMap { type in
            guard info.hasItemsConforming(to: [type]), let item = info.itemProviders(for: [type]).first else { return nil }
            return item
        }
    }
    
    private func loadImage(from item: NSItemProvider, type: String, handler: @escaping (NSImage?) -> Void) {
        switch type {
        case "public.jpeg", "public.tiff":
            item.loadItem(forTypeIdentifier: type, options: nil) { data, error in
                guard let data = data as? Data, let image = NSImage(data: data) else {
                    handler(nil)
                    return
                }
                handler(image.isValid ? image : nil)
            }
        case "public.file-url":
            item.loadItem(forTypeIdentifier: type, options: nil) { (data, error) in
                let _url = data
                    .flatMap { $0 as? Data }
                    .flatMap { NSURL(absoluteURLWithDataRepresentation: $0, relativeTo: nil) }
                
                guard let url = _url else {
                    return
                }
                
                let image = NSImage(byReferencing: url as URL)
                handler(image.isValid ? image : nil)
            }
        default:
            handler(nil)
            break
        }
    }
}
