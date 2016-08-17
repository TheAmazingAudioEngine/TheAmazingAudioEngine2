//
//  AppDelegate.swift
//  TAAESample macOS
//
//  Created by Michael Tyson on 17/08/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var audio: AEAudioController?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        self.audio = AEAudioController();
        do {
            try self.audio!.start();
            if let viewController = NSApplication.sharedApplication().mainWindow?.contentViewController as? ViewController {
                viewController.audio = self.audio
            }
        } catch {
            print("Audio unavailable");
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

