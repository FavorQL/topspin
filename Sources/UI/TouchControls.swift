import UIKit
import simd

/// On-screen gamepad: a floating stick on the left, two action buttons on the right.
///
/// The view covers the whole screen but `point(inside:with:)` only claims touches in
/// the stick zone and on the buttons, so drags anywhere else fall through to the
/// camera-orbit recogniser sitting on the Metal view underneath.
final class TouchControlsView: UIView {

    private(set) var movement = SIMD2<Float>.zero
    private(set) var jumpHeld = false
    private(set) var hatHeld = false

    private let stickBase = UIView()
    private let stickKnob = UIView()
    private let jumpButton = UIButton(type: .custom)
    private let hatButton = UIButton(type: .custom)

    private var stickTouch: UITouch?
    private var stickOrigin: CGPoint = .zero
    private let stickTravel: CGFloat = 52

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("TouchControlsView must be created programmatically")
    }

    private func configure() {
        backgroundColor = .clear
        isMultipleTouchEnabled = true

        stickBase.frame = CGRect(x: 0, y: 0, width: 132, height: 132)
        stickBase.layer.cornerRadius = 66
        stickBase.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        stickBase.layer.borderWidth = 2
        stickBase.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        stickBase.isHidden = true
        stickBase.isUserInteractionEnabled = false
        addSubview(stickBase)

        stickKnob.frame = CGRect(x: 0, y: 0, width: 58, height: 58)
        stickKnob.layer.cornerRadius = 29
        stickKnob.backgroundColor = UIColor.white.withAlphaComponent(0.55)
        stickKnob.isHidden = true
        stickKnob.isUserInteractionEnabled = false
        addSubview(stickKnob)

        configureButton(jumpButton, title: "A")
        configureButton(hatButton, title: "B")

        jumpButton.addTarget(self, action: #selector(jumpDown),
                             for: [.touchDown, .touchDragEnter])
        jumpButton.addTarget(self, action: #selector(jumpUp),
                             for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        hatButton.addTarget(self, action: #selector(hatDown),
                            for: [.touchDown, .touchDragEnter])
        hatButton.addTarget(self, action: #selector(hatUp),
                            for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func configureButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 24, weight: .heavy)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        button.layer.masksToBounds = true
        addSubview(button)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let size = max(62, min(bounds.width, bounds.height) * 0.15)
        let margin: CGFloat = 26
        let bottomInset = safeAreaInsets.bottom

        hatButton.frame = CGRect(x: bounds.width - margin - size,
                                 y: bounds.height - bottomInset - margin - size,
                                 width: size, height: size)
        hatButton.layer.cornerRadius = size / 2

        jumpButton.frame = CGRect(x: hatButton.frame.minX - size - 20,
                                  y: bounds.height - bottomInset - margin - size * 0.78,
                                  width: size, height: size)
        jumpButton.layer.cornerRadius = size / 2
    }

    // MARK: - Hit testing

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if jumpButton.frame.insetBy(dx: -20, dy: -20).contains(point) { return true }
        if hatButton.frame.insetBy(dx: -20, dy: -20).contains(point) { return true }
        // Left-hand zone reserved for the virtual stick.
        if point.x < bounds.width * 0.5 && point.y > bounds.height * 0.4 { return true }
        return false
    }

    // MARK: - Stick

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard stickTouch == nil else { return }
        for touch in touches {
            let location = touch.location(in: self)
            guard location.x < bounds.width * 0.5 else { continue }

            let clamped = CGPoint(x: min(max(location.x, 90), bounds.width * 0.5 - 20),
                                  y: min(max(location.y, 90), bounds.height - 60))
            stickTouch = touch
            stickOrigin = clamped
            stickBase.center = clamped
            stickKnob.center = clamped
            stickBase.isHidden = false
            stickKnob.isHidden = false
            updateStick(location)
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = stickTouch, touches.contains(touch) else { return }
        updateStick(touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = stickTouch, touches.contains(touch) else { return }
        endStick()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = stickTouch, touches.contains(touch) else { return }
        endStick()
    }

    private func updateStick(_ location: CGPoint) {
        var dx = location.x - stickOrigin.x
        var dy = location.y - stickOrigin.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance > stickTravel {
            dx = dx / distance * stickTravel
            dy = dy / distance * stickTravel
        }
        stickKnob.center = CGPoint(x: stickOrigin.x + dx, y: stickOrigin.y + dy)
        // UIKit's y grows downward; the game's forward axis grows upward.
        movement = SIMD2<Float>(Float(dx / stickTravel), Float(-dy / stickTravel))
    }

    private func endStick() {
        stickTouch = nil
        movement = .zero
        stickBase.isHidden = true
        stickKnob.isHidden = true
    }

    // MARK: - Buttons

    @objc private func jumpDown() { jumpHeld = true }
    @objc private func jumpUp() { jumpHeld = false }
    @objc private func hatDown() { hatHeld = true }
    @objc private func hatUp() { hatHeld = false }
}
