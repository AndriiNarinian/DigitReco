
import UIKit

class SettingsViewController: UIViewController {

    var info = SettingsInfo()
    
    convenience init(info: SettingsInfo) {
        self.init()
        self.info = info
    }
    
    // View
    let settingsView = SettingsView()
    
    override func loadView() {
        settingsView.delegate = self
        settingsView.setInfo(info)
        self.view = settingsView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
}

// MARK: Settings
extension SettingsViewController: SettingsViewDelegate {
    func didTapSettingsButton() {
        self.dismiss(animated: true) { }
    }
}
