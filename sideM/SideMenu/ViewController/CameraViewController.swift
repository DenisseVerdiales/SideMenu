//
//  CameraViewController.swift
//  SideMenu
//
//  Created by Consultant on 2/12/23.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {

    var captureSession = AVCaptureSession()
    var backCamera : AVCaptureDevice?
    var frontCamera : AVCaptureDevice?
    var backInput : AVCaptureInput?
    var frontInput : AVCaptureInput?
    var previewLayer = AVCaptureVideoPreviewLayer()
    var videoOutput = AVCaptureVideoDataOutput()
    var captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
    var takePicture = false
    var backCameraOn = true
    private var captureButtonBarConstraintsPortraint = [NSLayoutConstraint]()
    private var captureButtonBarConstraintsLandScape = [NSLayoutConstraint]()
    
    lazy var switchCameraButton: UIButton = {
        let button = UIButton()
        let image = UIImage(named: "switchcamera")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        return button
      }()
    
    lazy var captureImageButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        return button
    }()
    
    let capturedImageView = CapturedImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
       super.viewDidAppear(animated)
       checkPermissions()
       setupAndStartCaptureSession()
    }

    func setupAndStartCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async{
           //init session
           self.captureSession = AVCaptureSession()
           //start configuration
            self.captureSession.beginConfiguration()
           
           //session specific configuration
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
           }
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
           
           //setup inputs
           self.setupInputs()
            
            DispatchQueue.main.async {
               //setup preview layer
               self.setupPreviewLayer()
            }
            
            //setup output
            self.setupOutput()
           
           //commit configuration
            self.captureSession.commitConfiguration()
           //start running it
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        self.configureVideoOrientation()
    }

    private func configureVideoOrientation() {
        
          if let connection = previewLayer.connection {
            let orientation = UIDevice.current.orientation
             
            if connection.isVideoOrientationSupported,
                let videoOrientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue) {
                previewLayer.frame = self.view.bounds
                connection.videoOrientation = videoOrientation
            }
              
              if orientation.isLandscape {
                  NSLayoutConstraint.deactivate(captureButtonBarConstraintsPortraint)
                  NSLayoutConstraint.activate(captureButtonBarConstraintsLandScape)
              } else {
                  NSLayoutConstraint.activate(captureButtonBarConstraintsPortraint)
                  NSLayoutConstraint.deactivate(captureButtonBarConstraintsLandScape)
              }
        }
    }
    
    func setupPreviewLayer(){
       previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
       view.layer.insertSublayer(previewLayer, below: switchCameraButton.layer)
        previewLayer.frame = self.view.bounds
    }
    
    func setupOutput(){
       videoOutput = AVCaptureVideoDataOutput()
       let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
       
     
        if captureSession.canAddOutput(videoOutput){
            captureSession.addOutput(videoOutput)
       } else {
           fatalError("could not add video output")
       }
        
        //deal with the orientation
        videoOutput.connections.first?.videoOrientation = .portrait
    }
    
    func setupInputs(){
        //get back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = device
        } else {
            //handle this appropriately for production purposes
            fatalError("no back camera")
        }
        
        //get front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        } else {
            fatalError("no front camera")
        }
        
        //now we need to create an input objects from our devices
        guard let backC = backCamera else{return}
        guard let bInput = try? AVCaptureDeviceInput(device: backC) else {
            fatalError("could not create input device from back camera")
        }
        backInput = bInput
        guard let bInputC = backInput else {return}
        if !captureSession.canAddInput(bInputC) {
            fatalError("could not add back camera input to capture session")
        }
        
        guard let fCamera = frontCamera else {return}
        guard let fInput = try? AVCaptureDeviceInput(device: fCamera) else {
            fatalError("could not create input device from front camera")
        }
        frontInput = fInput
        guard let fInputC = frontInput else {return}
        if !captureSession.canAddInput(fInputC) {
            fatalError("could not add front camera input to capture session")
        }
        
        //connect back camera input to session
        guard let bInputC = backInput else {return}
        captureSession.addInput(bInputC)
    }
    
    func switchCameraInput(){
        //don't let user spam the button, fun for the user, not fun for performance
        switchCameraButton.isUserInteractionEnabled = false
        
        //reconfigure the input
        captureSession.beginConfiguration()
        guard let bInputC = backInput else {return}
        guard let fInputC = frontInput else {return}
        if backCameraOn {
            captureSession.removeInput(bInputC)
            captureSession.addInput(fInputC)
            backCameraOn = false
        } else {
            captureSession.removeInput(fInputC)
            captureSession.addInput(bInputC)
            backCameraOn = true
        }
        
        //deal with the connection again for portrait mode
        videoOutput.connections.first?.videoOrientation = .portrait
        
        //mirror the video stream for front camera
        videoOutput.connections.first?.isVideoMirrored = !backCameraOn
        
        //commit config
        captureSession.commitConfiguration()
        
        //acitvate the camera button again
        switchCameraButton.isUserInteractionEnabled = true
    }
    
    // Permissions
      func checkPermissions() {
          let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
          switch cameraAuthStatus {
            case .authorized:
              return
            case .denied:
              abort()
            case .notDetermined:
              AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler:
              { (authorized) in
                if(!authorized){
                  abort()
                }
              })
            case .restricted:
              abort()
            @unknown default:
              fatalError()
          }
      }
    
    func setupView(){
        
        let vStackViewContent = UIStackView(frame: .zero)
        vStackViewContent.translatesAutoresizingMaskIntoConstraints = false
        vStackViewContent.spacing = 10
        vStackViewContent.axis = .vertical
        vStackViewContent.distribution = .equalCentering

        let vStackViewCaptureBar = UIStackView(frame: .zero)
        vStackViewCaptureBar.translatesAutoresizingMaskIntoConstraints = false
        vStackViewCaptureBar.spacing = 10
        vStackViewCaptureBar.axis = .vertical
        vStackViewCaptureBar.distribution = .equalCentering

        let hStackViewContent = UIStackView(frame: .zero)
        hStackViewContent.translatesAutoresizingMaskIntoConstraints = false
        hStackViewContent.spacing = 8
        hStackViewContent.axis = .horizontal
        hStackViewContent.distribution = .fillEqually
        hStackViewContent.backgroundColor = .blue

        view.backgroundColor = .black

        view.addSubview(switchCameraButton)
        view.addSubview(captureImageButton)
        view.addSubview(capturedImageView)

        captureButtonBarConstraintsPortraint = [
            switchCameraButton.widthAnchor.constraint(equalToConstant: 30),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 30),
            switchCameraButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -25),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),

            captureImageButton.widthAnchor.constraint(equalToConstant: 50),
            captureImageButton.heightAnchor.constraint(equalToConstant: 50),
            captureImageButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            captureImageButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            capturedImageView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.05, constant: 4),
            capturedImageView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.1, constant: 4),
            capturedImageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22),
            capturedImageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),

        ]

        captureButtonBarConstraintsLandScape = [
            switchCameraButton.widthAnchor.constraint(equalToConstant: 30),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 30),
            switchCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 5),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -15),

            captureImageButton.widthAnchor.constraint(equalToConstant: 50),
            captureImageButton.heightAnchor.constraint(equalToConstant: 50),
            captureImageButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            captureImageButton.topAnchor.constraint(equalTo: switchCameraButton.bottomAnchor, constant: 80),

            capturedImageView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.1, constant: 3),
            capturedImageView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.05, constant: 3),
            capturedImageView.topAnchor.constraint(equalTo: captureImageButton.bottomAnchor, constant: 60),
            capturedImageView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -15),
        ]

        NSLayoutConstraint.activate(captureButtonBarConstraintsPortraint)

    }
  
    @objc func switchCamera(){
        switchCameraInput()
    }
    
    @objc func captureImage(){
        takePicture = true
    }
}
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
           if !takePicture {
               return //we have nothing to do with the image buffer
           }
           
           //try and get a CVImageBuffer out of the sample buffer
           guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
               return
           }
           
           //get a CIImage out of the CVImageBuffer
           let ciImage = CIImage(cvImageBuffer: cvBuffer)
           
           //get UIImage out of CIImage
           let uiImage = UIImage(ciImage: ciImage)
           
           DispatchQueue.main.async {
               self.capturedImageView.image = uiImage
               self.takePicture = false
           }
       }
}
