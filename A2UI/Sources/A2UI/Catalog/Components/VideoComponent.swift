import UIKit
import AVKit

/// A video player component.
///
/// Parameters:
/// - `url`: Video URL.
enum VideoComponent {

    static func register() -> CatalogItem {
        CatalogItem(name: "Video") { context in
            let urlStr = context.data["url"] as? String

            let container = UIView()
            container.backgroundColor = .black
            container.layer.cornerRadius = 8
            container.clipsToBounds = true
            container.translatesAutoresizingMaskIntoConstraints = false
            container.heightAnchor.constraint(equalToConstant: 200).isActive = true

            guard let urlStr = urlStr, let url = URL(string: urlStr) else {
                let label = UILabel()
                label.text = "No video URL"
                label.textColor = .white
                label.textAlignment = .center
                container.addSubview(label)
                label.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
                ])
                return container
            }

            let player = AVPlayer(url: url)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspect
            container.layer.addSublayer(playerLayer)

            let playButton = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 44)
            playButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
            playButton.tintColor = .white
            container.addSubview(playButton)
            playButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                playButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                playButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])

            var isPlaying = false
            playButton.addAction(UIAction { [weak playButton] _ in
                if isPlaying {
                    player.pause()
                    playButton?.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
                } else {
                    player.play()
                    playButton?.setImage(UIImage(systemName: "pause.fill", withConfiguration: config), for: .normal)
                }
                isPlaying.toggle()
            }, for: .touchUpInside)

            DispatchQueue.main.async {
                playerLayer.frame = container.bounds
            }

            return container
        }
    }
}
