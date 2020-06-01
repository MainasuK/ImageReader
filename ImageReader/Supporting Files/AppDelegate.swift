//
//  AppDelegate.swift
//  ImageReader
//
//  Created by Cirno MainasuK on 2020-5-12.
//  Copyright © 2020 MainasuK. All rights reserved.
//

import Cocoa
import SwiftUI
import OpenCVBridge

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    
    let store = Store()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Create the window and set the content view. 
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView.environmentObject(store))
        window.makeKeyAndOrderFront(nil)
        
        let cvMat = CVBMat()
        print(cvMat.rows())
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        #if PREVIEW
        guard store.content.image.size == .zero else { return }
        store.content.image = NSImage(named: "test-snapshot")!
        #endif
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        
    }

}

