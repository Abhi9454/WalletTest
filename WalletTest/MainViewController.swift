//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit
import UserNotifications

class MainViewController: UIViewController {
    var handshakeController: HandshakeViewController!
    var actionsController: ActionsViewController!
    var walletConnect: WalletConnect!

    @IBAction func connect(_ sender: Any) {
        let connectionUrl = walletConnect.connect()

        /// https://docs.walletconnect.org/mobile-linking#for-ios
        /// **NOTE**: Majority of wallets support universal links that you should normally use in production application
        /// Here deep link provided for integration with server test app only
        let deepLinkUrl = "https://metamask.app.link/wc?uri=\(connectionUrl)"

        if let url = URL(string: connectionUrl), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            handshakeController = HandshakeViewController.create(code: connectionUrl)
            present(handshakeController, animated: true)
        }
        
        AppData.shared.sendNotification(title: "Wallet Connect", body: "notification")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        walletConnect = WalletConnect(delegate: self)
        walletConnect.reconnectIfNeeded()
        
        AppData.shared.requestNotificationAuthorization()
    }

    func onMainThread(_ closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
    
    func getCurrentSession() {
        let peerId = AppData.shared.peerId
        print("peer id: \(peerId)")
        
        let accounts = AppData.shared.accounts
        print("accounts: \(accounts)")
    }
    
    @IBAction func getSessionAction(_ sender: Any) {
        getCurrentSession()
    }
}

extension MainViewController: WalletConnectDelegate {
    func failedToConnect() {
        onMainThread { [unowned self] in
            if let handshakeController = self.handshakeController {
                handshakeController.dismiss(animated: true)
            }
            UIAlertController.showFailedToConnect(from: self)
        }
    }

    func didConnect() {
        onMainThread { [unowned self] in
            self.actionsController = ActionsViewController.create(walletConnect: self.walletConnect)
            if let handshakeController = self.handshakeController {
                handshakeController.dismiss(animated: false) { [unowned self] in
                    self.present(self.actionsController, animated: false)
                }
            } else if self.presentedViewController == nil {
                self.present(self.actionsController, animated: false)
            }
        }
    }

    func didDisconnect() {
        onMainThread { [unowned self] in
            if let presented = self.presentedViewController {
                presented.dismiss(animated: false)
            }
            UIAlertController.showDisconnected(from: self)
        }
    }
}

extension UIAlertController {
    func withCloseButton() -> UIAlertController {
        addAction(UIAlertAction(title: "Close", style: .cancel))
        return self
    }

    static func showFailedToConnect(from controller: UIViewController) {
        let alert = UIAlertController(title: "Failed to connect", message: nil, preferredStyle: .alert)
        controller.present(alert.withCloseButton(), animated: true)
    }

    static func showDisconnected(from controller: UIViewController) {
        let alert = UIAlertController(title: "Did disconnect", message: nil, preferredStyle: .alert)
        controller.present(alert.withCloseButton(), animated: true)
    }
}

class AppData {
    static let shared = AppData()
    
    private init() {}
    
    var peerId: String {
        get{
            UserDefaults.standard.string(forKey: "peerId") ?? ""
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "peerId")
        }
    }
    
    var accounts: [Any] {
        get{
            UserDefaults.standard.array(forKey: "accounts") ?? []
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "accounts")
        }
    }
    
    private let userNotificationCenter = UNUserNotificationCenter.current()

    func requestNotificationAuthorization() {
        let authOptions = UNAuthorizationOptions.init(arrayLiteral: .alert, .badge, .sound)
        
        self.userNotificationCenter.requestAuthorization(options: authOptions) { (success, error) in
            if let error = error {
                print("Error: ", error)
            }
        }
    }

    func sendNotification(title: String, body: String) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = title
        notificationContent.body = body
        notificationContent.badge = NSNumber(value: 3)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "testNotification",
                                            content: notificationContent,
                                            trigger: trigger)
        
        userNotificationCenter.add(request) { (error) in
            if let error = error {
                print("Notification Error: ", error)
            }
        }
    }
}
