//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import PreferencesView
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let topViewController = scene.keyWindow?.rootViewController,
           let presentedViewController = topViewController.presentedViewController,
           let preferencesHostingController = findPreferencesHostingController(from: presentedViewController)
        {
            return preferencesHostingController.supportedInterfaceOrientations
        }

        return UIDevice.isPad ? .allButUpsideDown : .portrait
    }

    private func findPreferencesHostingController(from viewController: UIViewController) -> UIPreferencesHostingController? {
        if let controller = viewController as? UIPreferencesHostingController {
            return controller
        }

        for child in viewController.children {
            if let found = findPreferencesHostingController(from: child) {
                return found
            }
        }

        if let presented = viewController.presentedViewController {
            return findPreferencesHostingController(from: presented)
        }

        return nil
    }
}
