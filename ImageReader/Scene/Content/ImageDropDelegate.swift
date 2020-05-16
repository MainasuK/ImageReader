//
//  ImageDropDelegate.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-12.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import SwiftUI
import CommonOSLog

struct ImageDropDelegate: DropDelegate {
    
    @Binding var image: NSImage
    @Binding var isActive: Bool
    
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
        
        guard let item = info.itemProviders(for: ["public.file-url"]).first else {
            return false
        }
        
        item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (data, error) in
            DispatchQueue.main.async {
                let _url = data
                    .flatMap { $0 as? Data }
                    .flatMap { NSURL(absoluteURLWithDataRepresentation: $0, relativeTo: nil) }
                
                guard let url = _url else {
                    return
                }
                
                let image = NSImage(byReferencing: url as URL)
                if image.isValid {
                    self.image = image
                }
            }
        }
        
        return true
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: ["public.file-url"])
    }
    
}
