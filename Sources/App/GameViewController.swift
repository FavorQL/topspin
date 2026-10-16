import UIKit
import MetalKit
import simd

final class GameViewController: UIViewController {

    private let game = Game()
    private var renderer: Renderer?

    private let metalView = MTKView(frame: .zero)
    private let controls = TouchControlsView()
    private let coinLabel = UILabel()
    private let statusLabel = UILabel()
    private let hintLabel = UILabel()

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.53, green: 0.78, blue: 0.92, alpha: 1)

        guard let device = MTLCreateSystemDefaultDevice() else {
            showUnsupported("This device has no Metal-capable GPU.")
            return
        }

        configureMetalView(device: device)
        configureOverlay()

        guard let renderer = Renderer(device: device, view: metalView, game: game) else {
            showUnsupported("Failed to build the Metal render pipeline.")
            return
        }

        renderer.inputProvider = { [weak self] in
            guard let self = self else { return InputState.idle }
            return InputState(move: self.controls.movement,
                              jumpHeld: self.controls.jumpHeld,
                              hatHeld: self.controls.hatHeld)
        }
        renderer.onFrame = { [weak self] game in
            self?.refreshHUD(with: game)
        }

        metalView.delegate = renderer
        self.renderer = renderer

        game.aspect = Float(view.bounds.width / max(view.bounds.height, 1))

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCameraPan(_:)))
        pan.maximumNumberOfTouches = 1
        metalView.addGestureRecognizer(pan)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // ProMotion panels (iPhone 13 Pro and later, all Pro models) can drive 120 Hz.
        // The simulation is delta-time driven, so a higher rate only makes motion
        // smoother — no physics or tuning change is needed. Reading the screen off the
        // window rather than UIScreen.main keeps this correct in multi-scene contexts.
        if let screen = view.window?.screen {
            metalView.preferredFramesPerSecond = min(120, screen.maximumFramesPerSecond)
        }
    }

    // MARK: - Setup

    private func configureMetalView(device: MTLDevice) {
        metalView.device = device
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = device.supportsTextureSampleCount(4) ? 4 : 1
        metalView.clearColor = MTLClearColor(red: 0.53, green: 0.78, blue: 0.92, alpha: 1)
        // Default to 60. viewDidAppear raises this on ProMotion displays.
        metalView.preferredFramesPerSecond = 60
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.isUserInteractionEnabled = true
        view.addSubview(metalView)

        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalView.topAnchor.constraint(equalTo: view.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureOverlay() {
        coinLabel.translatesAutoresizingMaskIntoConstraints = false
        coinLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        coinLabel.textColor = .white
        coinLabel.layer.shadowColor = UIColor.black.cgColor
        coinLabel.layer.shadowOpacity = 0.55
        coinLabel.layer.shadowRadius = 3
        coinLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        coinLabel.text = "COINS  0 / 0"

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        statusLabel.layer.shadowColor = UIColor.black.cgColor
        statusLabel.layer.shadowOpacity = 0.55
        statusLabel.layer.shadowRadius = 3
        statusLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        statusLabel.textAlignment = .right

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 13, weight: .medium)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.textAlignment = .center
        hintLabel.text = "Left half: move   ·   Drag elsewhere: camera   ·   A: jump   ·   B: throw cap / release host"

        controls.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(controls)
        view.addSubview(coinLabel)
        view.addSubview(statusLabel)
        view.addSubview(hintLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.topAnchor.constraint(equalTo: view.topAnchor),
            controls.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            coinLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            coinLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 14),

            statusLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            statusLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 18),

            hintLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -6)
        ])
    }

    private func showUnsupported(_ message: String) {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.text = message
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.7)
        ])
    }

    // MARK: - Camera

    @objc private func handleCameraPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: metalView)
        gesture.setTranslation(.zero, in: metalView)

        // Flip either sign here if the orbit feels inverted to you.
        let sensitivity: Float = 0.005
        game.camera.orbit(deltaYaw: Float(translation.x) * sensitivity,
                          deltaPitch: Float(translation.y) * sensitivity)
    }

    // MARK: - HUD

    private func refreshHUD(with game: Game) {
        coinLabel.text = "COINS  \(game.coinCount) / \(game.totalCoins)"

        switch game.state {
        case .cleared:
            statusLabel.text = "COURSE CLEAR"
        case .playing:
            if game.possessedKind != nil {
                statusLabel.text = "POSSESSING · tap B to release"
            } else {
                statusLabel.text = "Throw your cap at a creature to take it over"
            }
        }
    }
}
