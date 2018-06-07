//
//  ViewController.swift
//  OhMyDog
//
//  Created by Projet2A on 28/05/2018.
//  Copyright © 2018 Projet2A. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Speech

class ViewController: UIViewController, ARSCNViewDelegate, SFSpeechRecognizerDelegate {
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    @IBOutlet weak var recordButton: UIButton!
    
    var nodeModel:SCNNode!
    var nodeName = "Armature"
    var sceneLight : SCNLight!
    var modelScene = SCNScene()
    var dogPosition : SCNVector3!
    var dogHere = false
    var dog:SCNNode!
    var animations = [String: CAAnimation]()
    var walk = false
    var sit = false
    var down = false
    var feed = false
    var drink = false
    var destination:SCNVector3!
    var timer = Timer()
    var dogAnchor:ARAnchor!
    var positionOfCamera:SCNVector3!
    
    var focusSquare = FocusSquare()
    
    
    @IBOutlet weak var drinkButton: UIButton!
    @IBOutlet weak var feedButton: UIButton!
    @IBOutlet weak var downButton: UIButton!
    @IBOutlet weak var sitButton: UIButton!
    @IBOutlet weak var comeButton: UIButton!
    @IBOutlet weak var backToHome: UIButton!
    @IBOutlet weak var barkButton: UIButton!
    
    var session: ARSession {
        return sceneView.session
    }
    
    var screenCenter : CGPoint {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set up scene content.
        setupCamera()
        sceneView.scene.rootNode.addChildNode(focusSquare)
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        sceneView.autoenablesDefaultLighting = false
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        //create the array with all animations
        loadAnimations()
        
        //get light
        sceneLight = SCNLight()
        sceneLight.type = .omni
        
        let lightNode = SCNNode()
        lightNode.light = sceneLight
        lightNode.position = SCNVector3(x: 0, y: 10, z: 2)
        
        //initialize dogHere and Hide button
        dogHere = false
        recordButton.isHidden = true
        backToHome.isHidden = true
        comeButton.isHidden = true
        sitButton.isHidden = true
        downButton.isHidden = true
        feedButton.isHidden = true
        drinkButton.isHidden = true
        barkButton.isHidden = true
        
        sceneView.scene.rootNode.addChildNode(lightNode)
        
        modelScene = SCNScene(named: "art.scnassets/shiba.dae")!
        
        nodeModel = modelScene.rootNode.childNode(withName: nodeName, recursively: true)
    }
    
    func setupCamera() {
        guard let camera = sceneView.pointOfView?.camera else {
            fatalError("Expected a valid `pointOfView` from the scene.")
        }
        
        /*
         Enable HDR camera settings for the most realistic appearance
         with environmental lighting and physically based materials.
         */
        camera.wantsHDR = true
        camera.exposureOffset = -1
        camera.minimumExposure = -1
        camera.maximumExposure = 3
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        speechRecognizer?.delegate = self
        
        // Start the `ARSession`.
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func calculateDistance(from:SCNVector3,to:SCNVector3) -> Float{
        let x = from.x - to.x
        let z = from.z - to.z
        return sqrtf( (x * x) + (z * z))
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: sceneView)
        var hitTestOptions = [SCNHitTestOption: Any]()
        hitTestOptions[SCNHitTestOption.boundingBoxOnly] = true
        let hitResults: [SCNHitTestResult]  =
            sceneView.hitTest(location, options: hitTestOptions)
        let hitResultsFeaturePoints: [ARHitTestResult] =
            sceneView.hitTest(screenCenter, types: .featurePoint)
        if !dogHere {
            //add AR dog
            if let hit = hitResultsFeaturePoints.first {
                // Get a transformation matrix with the euler angle of the camera
                let rotate = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y, 0, 1, 0))
                var finalTransform:simd_float4x4
                let hitTest = sceneView.hitTest(screenCenter, types: .existingPlane).filter { (result) -> Bool in
                    return (result.anchor as? ARPlaneAnchor)?.alignment == ARPlaneAnchor.Alignment.vertical
                    }.first
                if (hitTest != nil) {
                    let verticaltransform = smartHitTest(screenCenter)
                    finalTransform = (verticaltransform?.worldTransform)!
                }else {
                    // Combine both transformation matrices
                    finalTransform = simd_mul(hit.worldTransform,rotate)
                }
                // Use the resulting matrix to position the anchor
                dogAnchor = ARAnchor(transform: finalTransform)
                sceneView.session.add(anchor: dogAnchor)
                guard let pointOfView = sceneView.pointOfView else { return }
                let transform = pointOfView.transform
                let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
                let location = SCNVector3(transform.m41, transform.m42, transform.m43)
                positionOfCamera = SCNVector3(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
                dogHere = true
                //make button visible and initialize their title
                backToHome.isHidden = false
                barkButton.isHidden = false
                barkButton.setTitle("Aboie", for: .normal)
                comeButton.isHidden = false
                comeButton.setTitle("Au pied", for: .normal)
                sitButton.isHidden = false
                sitButton.setTitle("Assis", for: .normal)
                downButton.isHidden = false
                downButton.setTitle("Couché", for: .normal)
                feedButton.isHidden = false
                feedButton.setTitle("Mange", for: .normal)
                drinkButton.isHidden = false
                drinkButton.setTitle("Bois", for: .normal)
                recordButton.isHidden = false
                recordButton.setTitle("Donner un ordre", for: .normal)
            }
        }
    }
        
    func getParent(_ nodeFound: SCNNode?) -> SCNNode? {
        if let node = nodeFound {
            if node.name == nodeName {
                return node
            } else if let parent = node.parent {
                return getParent(parent)
            }
        }
        return nil
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
       //get the light intensity and change the luminosty of AR objects
        if let estimate = self.sceneView.session.currentFrame?.lightEstimate {
            sceneLight.intensity = estimate.ambientIntensity
        }
        if dogHere {
            self.focusSquare.hide()
        } else {
            //show focus square
            DispatchQueue.main.async {
                self.updateFocusSquare()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if dog == nil  {
            dog = node
        }
        if !anchor.isKind(of: ARPlaneAnchor.self) {
            DispatchQueue.main.async {
                let modelClone = self.nodeModel.clone()
                modelClone.position = SCNVector3Zero
                // Add model as a child of the node
                node.addChildNode(modelClone)
                self.dogPosition = SCNVector3Make(anchor.transform.columns.3.x,anchor.transform.columns.3.y,anchor.transform.columns.3.z)
            }
        }
    }
    
    func updateFocusSquare() {
        // Perform hit testing only when ARKit tracking is in a good state.
        if let camera = session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = self.smartHitTest(screenCenter) {
            DispatchQueue.main.async {
                self.focusSquare.unhide()
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
            }
        } else {
            DispatchQueue.main.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
                self.focusSquare.hide()
            }
        }
    }
    
    func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: Position Testing
    func smartHitTest(_ point: CGPoint,
                      infinitePlane: Bool = false,
                      objectPosition: float3? = nil,
                      allowedAlignments: [ARPlaneAnchor.Alignment] = [.horizontal, .vertical]) -> ARHitTestResult? {
        
        // Perform the hit test.
        let results = sceneView.hitTest(point, types: [.existingPlaneUsingGeometry, .estimatedVerticalPlane, .estimatedHorizontalPlane])
        
        // 1. Check for a result on an existing plane using geometry.
        if let existingPlaneUsingGeometryResult = results.first(where: { $0.type == .existingPlaneUsingGeometry }),
            let planeAnchor = existingPlaneUsingGeometryResult.anchor as? ARPlaneAnchor, allowedAlignments.contains(planeAnchor.alignment) {
            return existingPlaneUsingGeometryResult
        }
        
        if infinitePlane {
            
            // 2. Check for a result on an existing plane, assuming its dimensions are infinite.
            //    Loop through all hits against infinite existing planes and either return the
            //    nearest one (vertical planes) or return the nearest one which is within 5 cm
            //    of the object's position.
            let infinitePlaneResults = sceneView.hitTest(point, types: .existingPlane)
            
            for infinitePlaneResult in infinitePlaneResults {
                if let planeAnchor = infinitePlaneResult.anchor as? ARPlaneAnchor, allowedAlignments.contains(planeAnchor.alignment) {
                    if planeAnchor.alignment == .vertical {
                        // Return the first vertical plane hit test result.
                        return infinitePlaneResult
                    } else {
                        // For horizontal planes we only want to return a hit test result
                        // if it is close to the current object's position.
                        if let objectY = objectPosition?.y {
                            let planeY = infinitePlaneResult.worldTransform.translation.y
                            if objectY > planeY - 0.05 && objectY < planeY + 0.05 {
                                return infinitePlaneResult
                            }
                        } else {
                            return infinitePlaneResult
                        }
                    }
                }
            }
        }
        
        // 3. As a final fallback, check for a result on estimated planes.
        let vResult = results.first(where: { $0.type == .estimatedVerticalPlane })
        let hResult = results.first(where: { $0.type == .estimatedHorizontalPlane })
        switch (allowedAlignments.contains(.horizontal), allowedAlignments.contains(.vertical)) {
        case (true, false):
            return hResult
        case (false, true):
            // Allow fallback to horizontal because we assume that objects meant for vertical placement
            // (like a picture) can always be placed on a horizontal surface, too.
            return vResult ?? hResult
        case (true, true):
            if hResult != nil && vResult != nil {
                return hResult!.distance < vResult!.distance ? hResult! : vResult!
            } else {
                return hResult ?? vResult
            }
        default:
            return nil
        }
    }
    
    func loadAnimations () {
        // Load all the DAE animations
        loadAnimation(withKey: "wouf", sceneName: "art.scnassets/shibaWouf2", animationIdentifier: "shibaWouf2-1")
        loadAnimation(withKey: "walk", sceneName: "art.scnassets/shibaWalk2", animationIdentifier: "shibaWalk2-1")
        loadAnimation(withKey: "waitStandUp", sceneName: "art.scnassets/shibaWaitStandUp2", animationIdentifier: "shibaWaitStandUp2-1")
        loadAnimation(withKey: "sit", sceneName: "art.scnassets/shibaSit2", animationIdentifier: "shibaSit2-1")
        loadAnimation(withKey: "waitSit", sceneName: "art.scnassets/shibaWaitSit2", animationIdentifier: "shibaWaitSit2-1")
        loadAnimation(withKey: "up", sceneName: "art.scnassets/shibaUp2", animationIdentifier: "shibaUp2-1")
        loadAnimation(withKey: "down", sceneName: "art.scnassets/shibaDown2", animationIdentifier: "shibaDown2-1")
        loadAnimation(withKey: "waitDown", sceneName: "art.scnassets/shibaWaitDown2", animationIdentifier: "shibaWaitDown2-1")
        loadAnimation(withKey: "downToSit", sceneName: "art.scnassets/shibaDownToSit2", animationIdentifier: "shibaDownToSit2-1")
        loadAnimation(withKey: "drink", sceneName: "art.scnassets/shibaDrink2", animationIdentifier: "shibaDrink2-1")
        loadAnimation(withKey: "eat", sceneName: "art.scnassets/shibaEat2", animationIdentifier: "shibaEat2-1")
    }
    
    func loadAnimation(withKey: String, sceneName:String, animationIdentifier:String) {
        let sceneURL = Bundle.main.url(forResource: sceneName, withExtension: "dae")
        let sceneSource = SCNSceneSource(url: sceneURL!, options: nil)
        if let animationObject = sceneSource?.entryWithIdentifier(animationIdentifier, withClass: CAAnimation.self) {
            // The animation will only play once
            animationObject.repeatCount = 1
            // To create smooth transitions between animations
            animationObject.fadeInDuration = CGFloat(1)
            animationObject.fadeOutDuration = CGFloat(0.5)
            
            // Store the animation for later use
            animations[withKey] = animationObject
        }
    }
    
    func playAnimation(key: String, infinity: Bool) {
        // Add the animation to start playing it right away
        if infinity {
            let animation = animations[key]
            animation?.repeatCount = .infinity
            sceneView.scene.rootNode.addAnimation(animation!, forKey: key)
        } else {
            sceneView.scene.rootNode.addAnimation(animations[key]!, forKey: key)
        }
    }
    
    func stopAnimation(key: String) {
        // Stop the animation with a smooth transition
        sceneView.scene.rootNode.removeAnimation(forKey: key, blendOutDuration: CGFloat(0.5))
    }
    
    @objc func move(){
        //move step by step
        if walk && destination != nil && dog != nil {
            var indexX = dog.position.x
            var smallerX = destination.x < dogPosition.x
            if smallerX {
                if destination.x < indexX {
                    indexX -= 0.02
                }
            } else {
                if destination.x > indexX {
                    indexX += 0.02
                }
            }
            var indexZ = dog.position.z
            var smallerZ = destination.z < dogPosition.z
            if smallerZ {
                if destination.z < indexZ {
                    indexZ -= 0.02
                }
            } else {
                if destination.z > indexZ {
                    indexZ += 0.02
                }
            }
            dog.position = SCNVector3Make(indexX, dog.position.y, indexZ)
            //if dog is on destination
            if (smallerZ  && destination.x > dog.position.x) || (!smallerX  && destination.x < dog.position.x){
                if (smallerZ  && destination.z > dog.position.z) || (!smallerZ  && destination.z < dog.position.z){
                    walk = false
                    dogPosition = dog.position
                    dog.eulerAngles.y = sceneView.session.currentFrame!.camera.eulerAngles.y
                    stopAnimation(key: "walk")
                    playAnimation(key: "waitStandUp", infinity: true)
                    comeButton.setTitle("Au pied", for: .normal)
                    sitButton.isHidden = false
                    downButton.isHidden = false
                    feedButton.isHidden = false
                    barkButton.isHidden = false
                    drinkButton.isHidden = false
                    recordButton.isHidden = false
                    timer.invalidate()
                }
            }
            
        }
    }
    
    @IBAction func come(_ sender: Any) {
        if !walk && dog != nil {
            guard let pointOfView = sceneView.pointOfView else { return }
            let transform = pointOfView.transform
            let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
            let location = SCNVector3(transform.m41, transform.m42, transform.m43)
            destination = SCNVector3(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
            let distanceDestToCam = calculateDistance(from: destination, to: positionOfCamera)
            let distanceFromToCam = calculateDistance(from: dogPosition, to: positionOfCamera)
            let distanceDestToFrom = calculateDistance(from: destination, to: dog.position)
            let angle = acos((distanceFromToCam * distanceFromToCam + distanceDestToFrom * distanceDestToFrom - distanceDestToCam * distanceDestToCam) / (2 * distanceFromToCam * distanceDestToFrom)) //* 180 / Float.pi
            dog.eulerAngles.y -= angle
            walk = true
            playAnimation(key: "walk", infinity: true)
            comeButton.setTitle("Stop", for: .normal)
            //other button are hidden
            sitButton.isHidden = true
            downButton.isHidden = true
            barkButton.isHidden = true
            feedButton.isHidden = true
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isHidden = true
            recordButton.setTitle("", for: .normal)
            drinkButton.isHidden = true
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ViewController.move), userInfo: nil, repeats: true)
        } else {
            walk = false
            dogPosition = dog.position
            //make other button visible
            sitButton.isHidden = false
            downButton.isHidden = false
            feedButton.isHidden = false
            barkButton.isHidden = false
            drinkButton.isHidden = false
            recordButton.isHidden = false
            stopAnimation(key: "walk")
            playAnimation(key: "waitStandUp", infinity: true)
            comeButton.setTitle("Au pied", for: .normal)
        }
    }
    
    @IBAction func sit(_ sender: Any) {
        if !sit && dog != nil {
            sit = true
            playAnimation(key: "waitSit", infinity: true)
            playAnimation(key: "sit", infinity: false)
            sitButton.setTitle("Debout", for: .normal)
            comeButton.isHidden = true
            downButton.isHidden = true
            barkButton.isHidden = true
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isHidden = true
            recordButton.setTitle("", for: .normal)
            feedButton.isHidden = true
            drinkButton.isHidden = true
        } else {
            sit = false
            sitButton.setTitle("Assis", for: .normal)
            stopAnimation(key: "waitSit")
            stopAnimation(key: "sit")
            playAnimation(key: "up", infinity: false)
            comeButton.isHidden = false
            downButton.isHidden = false
            feedButton.isHidden = false
            barkButton.isHidden = false
            drinkButton.isHidden = false
            recordButton.isHidden = false
            playAnimation(key: "waitStandUp", infinity: true)
        }
    }
    
    @IBAction func down(_ sender: Any) {
        if !down && dog != nil {
            down = true
            playAnimation(key: "waitDown", infinity: true)
            playAnimation(key: "sit", infinity: false)
            playAnimation(key: "down", infinity: false)
            downButton.setTitle("Debout", for: .normal)
            comeButton.isHidden = true
            sitButton.isHidden = true
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isHidden = true
            recordButton.setTitle("", for: .normal)
            feedButton.isHidden = true
            barkButton.isHidden = true
            drinkButton.isHidden = true
        } else {
            down = false
            sit = false
            downButton.setTitle("Couché", for: .normal)
            stopAnimation(key: "waitDown")
            stopAnimation(key: "down")
            stopAnimation(key: "sit")
            playAnimation(key: "downToSit", infinity: false)
            comeButton.isHidden = false
            sitButton.isHidden = false
            feedButton.isHidden = false
            barkButton.isHidden = false
            recordButton.isHidden = false
            drinkButton.isHidden = false
            playAnimation(key: "waitStandUp", infinity: true)
        }
    }
    
    @IBAction func feed(_ sender: Any) {
        if !feed && dog != nil {
            //add dog bowl
            let eat = SCNScene(named: "art.scnassets/shibaEat2.dae")!
            if let bowleat = eat.rootNode.childNodes.first?.childNodes.first {
                dog.childNodes.first?.addChildNode(bowleat)
                feed = true
                feedButton.setTitle("Stop", for: .normal)
                playAnimation(key: "eat", infinity: true)
                comeButton.isHidden = true
                barkButton.isHidden = true
                sitButton.isHidden = true
                audioEngine.stop()
                recognitionRequest?.endAudio()
                recordButton.isHidden = true
                recordButton.setTitle("", for: .normal)
                downButton.isHidden = true
                drinkButton.isHidden = true
            }
            
        } else {
            //delete dog bowl
            print(sceneView.scene.rootNode.childNodes.last?.childNodes.first?.childNodes)
            if let childNodes = sceneView.scene.rootNode.childNodes.last?.childNodes.first?.childNodes {
                for child in childNodes{
                    if child.name == "DogBowl" {
                        child.removeFromParentNode()
                    }
                }
                feed = false
                feedButton.setTitle("Mange", for: .normal)
                stopAnimation(key: "eat")
                comeButton.isHidden = false
                barkButton.isHidden = false
                sitButton.isHidden = false
                downButton.isHidden = false
                recordButton.isHidden = false
                drinkButton.isHidden = false
                playAnimation(key: "waitStandUp", infinity: true)
            }
            /*
            if let bowleat = sceneView.scene.rootNode.childNodes.last?.childNodes.first?.childNodes.last {
                
                if bowleat.name == "DogBowl" {
                    bowleat.removeFromParentNode()
                }
            }*/
            
        }
    }
    
    @IBAction func drink(_ sender: Any) {
        if !drink && dog != nil {
            let animation = SCNScene(named: "art.scnassets/shibaDrink2.dae")!
            if let bowldrink = animation.rootNode.childNodes.first?.childNodes.first {
                dog.childNodes.first?.addChildNode(bowldrink)
                drink = true
                drinkButton.setTitle("Stop", for: .normal)
                playAnimation(key: "drink", infinity: true)
                comeButton.isHidden = true
                sitButton.isHidden = true
                barkButton.isHidden = true
                downButton.isHidden = true
                feedButton.isHidden = true
                recordButton.isHidden = true
            }
        } else {
            if let childNodes = sceneView.scene.rootNode.childNodes.last?.childNodes.first?.childNodes {
                for child in childNodes{
                    if child.name == "DogBowl" {
                        child.removeFromParentNode()
                    }
                }
                drink = false
                drinkButton.setTitle("Bois", for: .normal)
                stopAnimation(key: "drink")
                comeButton.isHidden = false
                sitButton.isHidden = false
                downButton.isHidden = false
                barkButton.isHidden = false
                recordButton.isHidden = false
                feedButton.isHidden = false
                playAnimation(key: "waitStandUp", infinity: true)
            }
        }
    }
    
    @IBAction func bark(_ sender: Any) {
        playAnimation(key: "wouf", infinity: false)
    }
    
    private func startRecording() throws {
        comeButton.isHidden = true
        sitButton.isHidden = true
        downButton.isHidden = true
        barkButton.isHidden = true
        feedButton.isHidden = true
        drinkButton.isHidden = true
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            var sentence = result?.bestTranscription.formattedString
            if sentence != nil {
                self.treat(sentence!)
            }
            self.audioEngine.stop()
            recognitionRequest.endAudio()
            self.recordButton.setTitle("Donner un ordre", for: [])
            if let result = result {
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isHidden = false
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isHidden = false
        } else {
            recordButton.isHidden = true
        }
    }
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.setTitle("Donner un ordre", for: .normal)
            comeButton.isHidden = false
            sitButton.isHidden = false
            downButton.isHidden = false
            barkButton.isHidden = false
            drinkButton.isHidden = false
            feedButton.isHidden = false
        } else {
            try! startRecording()
            recordButton.setTitle("Arrêt", for: [])
        }
    }
    
    func treat(_ sentence: String){
        //delete dog bowl if present
        if feed {
            stopAnimation(key: "eat")
            playAnimation(key: "waitStandUp", infinity: true)
            if let bowleat = sceneView.scene.rootNode.childNodes.last?.childNodes.first?.childNodes.last {
                if bowleat.name == "DogBowl" {
                    bowleat.removeFromParentNode()
                }
            }
            feed = false
        }
        if drink {
            stopAnimation(key: "drink")
            playAnimation(key: "waitStandUp", infinity: true)
            if let bowldrink = sceneView.scene.rootNode.childNodes.last?.childNodes.first?.childNodes.last {
                if bowldrink.name == "DogBowl" {
                    bowldrink.removeFromParentNode()
                }
            }
            drink = false
        }
        //play animation if exist
        switch sentence {
        case "Assis":
            playAnimation(key: "waitSit", infinity: true)
            break
        case "Debout":
            playAnimation(key: "waitStandUp", infinity: true)
            break
        case "Couché":
            playAnimation(key: "waitDown", infinity: true)
            break
        case "Mange":
            feed = true
            let eat = SCNScene(named: "art.scnassets/shibaEat2.dae")!
            if let bowleat = eat.rootNode.childNodes.first?.childNodes.first {
                dog.childNodes.first?.addChildNode(bowleat)
            }
            playAnimation(key: "eat", infinity: true)
            break
        case "Bois":
            drink = true
            let animation = SCNScene(named: "art.scnassets/shibaDrink2.dae")!
            if let bowldrink = animation.rootNode.childNodes.first?.childNodes.first {
                dog.childNodes.first?.addChildNode(bowldrink)
            }
            playAnimation(key: "drink", infinity: true)
            break
        case "Aboie":
            playAnimation(key: "waitStandUp", infinity: true)
            playAnimation(key: "wouf", infinity: false)
            break
        default:
            self.comeButton.isHidden = false
            self.sitButton.isHidden = false
            self.barkButton.isHidden = false
            self.downButton.isHidden = false
            self.feedButton.isHidden = false
            self.drinkButton.isHidden = false
            playAnimation(key: "waitStandUp", infinity: true)
            break
        }
    }
    
    @IBAction func backToHomeTapped(_ sender: Any) {
        if dog != nil{
            dog.removeFromParentNode()
            backToHome.isHidden = true
            dogHere = false
            dog = nil
            comeButton.isHidden = true
            sitButton.isHidden = true
            downButton.isHidden = true
            feedButton.isHidden = true
            barkButton.isHidden = true
            drinkButton.isHidden = true
            recordButton.isHidden = true
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isHidden = true
            recordButton.setTitle("", for: .normal)
            walk = false
            sit = false
            down = false
            feed = false
            drink = false
        }
        for child in (sceneView.scene.rootNode.childNodes.last?.childNodes)! {
            if(child.name == "Armature"){
                child.removeFromParentNode()
            }
        }
    }
}
