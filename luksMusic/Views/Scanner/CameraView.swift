// CameraView.swift
// luksMusic
//
// Live camera capture view with sheet music alignment guides and photo output.

import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    var onPhotoCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onPhotoCaptured = { image in
            onPhotoCaptured(image)
            dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onPhotoCaptured: ((UIImage) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlayUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(input)
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        captureSession.commitConfiguration()
        
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview
        
        let session = self.captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func setupOverlayUI() {
        // Alignment Guide Frame
        let guideFrame = UIView()
        guideFrame.layer.borderColor = UIColor.systemIndigo.cgColor
        guideFrame.layer.borderWidth = 2.0
        guideFrame.layer.cornerRadius = 12
        guideFrame.translatesAutoresizingMaskIntoConstraints = false
        guideFrame.isUserInteractionEnabled = false
        view.addSubview(guideFrame)
        
        // Guidance label
        let label = UILabel()
        label.text = "Align piano sheet music inside frame"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        // Shutter Button
        let shutterButton = UIButton(type: .custom)
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 5
        shutterButton.layer.borderColor = UIColor.systemGray.cgColor
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)
        view.addSubview(shutterButton)
        
        // Close Button
        let closeButton = UIButton(type: .close)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            guideFrame.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            guideFrame.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            guideFrame.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            guideFrame.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -40),
            
            label.bottomAnchor.constraint(equalTo: guideFrame.topAnchor, constant: -16),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }
    
    @objc private func didTapShutter() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func didTapClose() {
        dismiss(animated: true)
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        Task { @MainActor [weak self] in
            self?.onPhotoCaptured?(image)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
}
