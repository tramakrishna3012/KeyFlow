import UIKit

final class ShareHost: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let button = UIButton(type: .system)
        button.setTitle("Share sample text", for: .normal)
        button.addTarget(self, action: #selector(showShare), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func showShare(_ sender: UIButton) {
        let sheet = UIActivityViewController(activityItems: ["KeyFlow share test"], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = sender
        present(sheet, animated: true)
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let appWindow = UIWindow(frame: UIScreen.main.bounds)
        appWindow.rootViewController = ShareHost()
        appWindow.makeKeyAndVisible()
        window = appWindow
        return true
    }
}
