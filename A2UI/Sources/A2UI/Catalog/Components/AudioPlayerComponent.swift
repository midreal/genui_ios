import UIKit
import AVFoundation

/// An audio player with play/pause controls.
///
/// Parameters:
/// - `url`: Audio file URL.
/// - `title`: Display title (optional).
enum AudioPlayerComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "AudioPlayer") { context in
            let urlStr = context.data["url"] as? String
            let title = context.data["title"] as? String

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 12
            stack.alignment = .center

            let playButton = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 28)
            playButton.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: config), for: .normal)
            playButton.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(playButton)

            let infoStack = UIStackView()
            infoStack.axis = .vertical
            infoStack.spacing = 2
            stack.addArrangedSubview(infoStack)

            if let t = title {
                let titleLabel = UILabel()
                titleLabel.text = t
                titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
                infoStack.addArrangedSubview(titleLabel)
            }

            let statusLabel = UILabel()
            statusLabel.text = urlStr != nil ? "Ready" : "No audio URL"
            statusLabel.font = .systemFont(ofSize: 12)
            statusLabel.textColor = .secondaryLabel
            infoStack.addArrangedSubview(statusLabel)

            var player: AVPlayer?
            var isPlaying = false

            if let urlStr = urlStr, let url = URL(string: urlStr) {
                player = AVPlayer(url: url)
            }

            playButton.addAction(UIAction { [weak playButton, weak statusLabel] _ in
                guard let p = player else { return }
                if isPlaying {
                    p.pause()
                    isPlaying = false
                    playButton?.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: config), for: .normal)
                    statusLabel?.text = "Paused"
                } else {
                    p.play()
                    isPlaying = true
                    playButton?.setImage(UIImage(systemName: "pause.circle.fill", withConfiguration: config), for: .normal)
                    statusLabel?.text = "Playing"
                }
            }, for: .touchUpInside)

            return stack
        }
    }
}
