
import UIKit

protocol SettingsViewDelegate: class {
    func didTapSettingsButton()
}

struct SettingsInfo {
    var log = ""
}

class SettingsView: UIView {
    
    // Nav bar
    let navBar = UIView()
    let settingsButton = UIButton()
    let titleLabel = UILabel()
    // Canvas
    let creditsLabel = UILabel()
    let canvasContainer = ShadowView()
    
    // Stats
    let statsContainer = ShadowView()
    let statsLabel = UILabel()
    let statsTextView = UITextView()

    // Info
    var info = SettingsInfo()
    
    weak var delegate: SettingsViewDelegate?
    
    convenience init() {
        self.init(frame: .zero)
        configureSubviews()
        configureLayout()
    }
    
    internal func didTapSettings() {
        delegate?.didTapSettingsButton()
    }
    
    public func setInfo(_ info: SettingsInfo) {
        self.info = info
        applyInfo()
    }
    
    private func applyInfo() {
        
        // Stats TextView
        statsTextView.text = info.log
        let bottom = NSMakeRange(statsTextView.text.characters.count - 1, 1)
        statsTextView.scrollRangeToVisible(bottom)
    }
    
    /// Configure view/subview appearances.
    private func configureSubviews() {
        backgroundColor = UIColor.saiExtraLightGray()
        
        // Nav bar
        navBar.backgroundColor = UIColor.saiOrange()
        
        // SettingsButton
        settingsButton.setTitle("close", for: .normal)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.addTarget(self, action: #selector(didTapSettings), for: .touchUpInside)
        
        // Title label
        titleLabel.text = "Settings"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.textAlignment = .center
        
        // Stats title
        statsLabel.text = "Recognition log"
        statsLabel.textColor = UIColor.darkGray
        statsLabel.font = UIFont.systemFont(ofSize: 15)
        statsLabel.textAlignment = .center
        
        // Stats TextView
        statsTextView.isEditable = false
        statsTextView.font = UIFont.systemFont(ofSize: 8)
        statsTextView.isScrollEnabled = true
        
        // Credits
        creditsLabel.text = "igyVigy 2017"
        creditsLabel.textColor = UIColor.darkGray
        creditsLabel.font = UIFont.systemFont(ofSize: 15)
        creditsLabel.textAlignment = .center
    }
    
    /// Add subviews and set constraints.
    private func configureLayout() {
        addAutoLayoutSubviews(navBar,
                              canvasContainer,
                              creditsLabel,
                              statsContainer,
                              statsLabel
        )
        navBar.addAutoLayoutSubview(titleLabel)
        navBar.addAutoLayoutSubview(settingsButton)
        statsContainer.addAutoLayoutSubviews(statsTextView)
        
        // Nav bar
        NSLayoutConstraint.activate([
            navBar.leftAnchor.constraint(equalTo: leftAnchor),
            navBar.rightAnchor.constraint(equalTo: rightAnchor),
            navBar.topAnchor.constraint(equalTo: topAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 64)
            ])
        
        // SettingsButton
        NSLayoutConstraint.activate([
            settingsButton.rightAnchor.constraint(equalTo: navBar.rightAnchor, constant: -7),
            settingsButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor, constant: 7),
            ])
        
        
        // Title label
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor, constant: 7)
            ])
        
        // Canvas container
        NSLayoutConstraint.activate([
            canvasContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: 8),
            canvasContainer.rightAnchor.constraint(equalTo: rightAnchor, constant: -8),
            canvasContainer.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 8),
            canvasContainer.heightAnchor.constraint(equalTo: canvasContainer.widthAnchor)
            ])
        
        // Stats title
        NSLayoutConstraint.activate([
            statsLabel.centerXAnchor.constraint(equalTo: statsContainer.centerXAnchor),
            statsLabel.bottomAnchor.constraint(equalTo: statsContainer.topAnchor, constant: -5)
            ])
        
        // Stats Container
        NSLayoutConstraint.activate([
            statsContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: 8),
            statsContainer.rightAnchor.constraint(equalTo: rightAnchor, constant: -8),
            statsContainer.topAnchor.constraint(equalTo: canvasContainer.bottomAnchor, constant: 30),
            statsContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30)
            ])
        
        // Stats Text View
        NSLayoutConstraint.activate([
            statsTextView.leftAnchor.constraint(equalTo: statsContainer.leftAnchor, constant: 4),
            statsTextView.rightAnchor.constraint(equalTo: statsContainer.rightAnchor, constant: -4),
            statsTextView.topAnchor.constraint(equalTo: statsContainer.topAnchor, constant: 4),
            statsTextView.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: -4)
            ])
        
        // Credits label
        NSLayoutConstraint.activate([
            creditsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            creditsLabel.topAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: 5)
            ])
        
    }
}
