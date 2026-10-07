import SwiftUI
import UIKit

// MARK: - Core Animation Marquee (render-server smooth)

/// UIKit view that scrolls a duplicated label using CABasicAnimation.
/// Core Animation runs on the render server so it cannot be interrupted
/// by SwiftUI view re-evaluations or main-thread timer callbacks.
final class MarqueeUIView: UIView {
    private let scrollView = UIView()
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let fadeLayer = CAGradientLayer()

    private let gap: CGFloat = 60
    private var scrollSpeed: CGFloat = 35
    private var needsScroll = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        backgroundColor = .clear

        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        for lbl in [primaryLabel, secondaryLabel] {
            lbl.backgroundColor = .clear
            scrollView.addSubview(lbl)
        }

        // Fade edges
        fadeLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        fadeLayer.locations = [0, 0.08, 0.92, 1]
        fadeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fadeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.mask = fadeLayer
    }

    func configure(text: String, uiFont: UIFont, textColor: UIColor, speed: CGFloat, tracking: CGFloat) {
        scrollSpeed = speed

        let attrs: [NSAttributedString.Key: Any] = [
            .font: uiFont,
            .foregroundColor: textColor,
            .kern: tracking
        ]
        let attrStr = NSAttributedString(string: text.uppercased(), attributes: attrs)

        primaryLabel.attributedText = attrStr
        secondaryLabel.attributedText = attrStr
        primaryLabel.sizeToFit()
        secondaryLabel.sizeToFit()

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let textW = primaryLabel.bounds.width
        let containerW = bounds.width

        fadeLayer.frame = bounds

        if textW > containerW {
            needsScroll = true
            let totalW = textW + gap + textW
            scrollView.frame = CGRect(x: 0, y: 0, width: totalW, height: bounds.height)
            primaryLabel.frame = CGRect(x: 0, y: 0, width: textW, height: bounds.height)
            secondaryLabel.frame = CGRect(x: textW + gap, y: 0, width: textW, height: bounds.height)
            secondaryLabel.isHidden = false

            // Fade mask on
            fadeLayer.locations = [0, 0.08, 0.92, 1]

            startAnimation(textWidth: textW)
        } else {
            needsScroll = false
            scrollView.layer.removeAnimation(forKey: "marquee")
            scrollView.frame = bounds
            primaryLabel.frame = CGRect(
                x: (containerW - textW) / 2,
                y: 0,
                width: textW,
                height: bounds.height
            )
            secondaryLabel.isHidden = true

            // No fade needed when not scrolling
            fadeLayer.locations = [0, 0, 1, 1]
        }
    }

    private func startAnimation(textWidth: CGFloat) {
        let distance = textWidth + gap
        let duration = Double(distance / scrollSpeed)

        let anim = CABasicAnimation(keyPath: "transform.translation.x")
        anim.fromValue = 0
        anim.toValue = -distance
        anim.duration = duration
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        scrollView.layer.removeAnimation(forKey: "marquee")
        scrollView.layer.add(anim, forKey: "marquee")
    }
}

/// SwiftUI wrapper.
struct MarqueeText: UIViewRepresentable {
    var text: String
    var font: Font = .system(size: 13, weight: .medium)    // kept for call-site compatibility
    var color: Color = Color.primary.opacity(0.7)
    var speed: Double = 35
    var tracking: Double = 3
    var fontSize: CGFloat = 13

    func makeUIView(context: Context) -> MarqueeUIView {
        let view = MarqueeUIView()
        view.configure(
            text: text,
            uiFont: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            textColor: UIColor(color),
            speed: speed,
            tracking: tracking
        )
        return view
    }

    func updateUIView(_ uiView: MarqueeUIView, context: Context) {
        uiView.configure(
            text: text,
            uiFont: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            textColor: UIColor(color),
            speed: speed,
            tracking: tracking
        )
    }
}

