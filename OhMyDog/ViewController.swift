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

class ViewController: UIViewController, ARSCNViewDelegate {
    
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
    var destination:SCNVector3!
    var timer = Timer()
    var dogAnchor:ARAnchor!
    var positionOfCamera:SCNVector3!
    
    var focusSquare = FocusSquare()
    
    
    @IBOutlet weak var feedButton: UIButton!
    @IBOutlet weak var downButton: UIButton!
    @IBOutlet weak var sitButton: UIButton!
    @IBOutlet weak var comeButton: UIButton!
    
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
        //let scene = SCNScene(named: "art.scnassets/struct.dae")!
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        loadAnimations()
        
//        sceneView.debugOptions = ARSCNDebugOptions.showWorldOrigin
        
        sceneLight = SCNLight()
        sceneLight.type = .omni
        
        let lightNode = SCNNode()
        lightNode.light = sceneLight
        lightNode.position = SCNVector3(x: 0, y: 10, z: 2)
        
        dogHere = false
        comeButton.isHidden = true
        sitButton.isHidden = true
        downButton.isHidden = true
        feedButton.isHidden = true
        
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
        if let hit = hitResults.first {
            if let node = getParent(hit.node) {
                node.removeFromParentNode()
                dogHere = false
                dog = nil
                walk = false
                comeButton.isHidden = true
                sitButton.isHidden = true
                downButton.isHidden = true
                feedButton.isHidden = true
                return
            }
        }
        let hitResultsFeaturePoints: [ARHitTestResult] =
            sceneView.hitTest(screenCenter, types: .featurePoint)
        if !dogHere {
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
                comeButton.isHidden = false
                comeButton.setTitle("Au pied", for: .normal)
                sitButton.isHidden = false
                sitButton.setTitle("Assis", for: .normal)
                downButton.isHidden = false
                downButton.setTitle("Couché", for: .normal)
                feedButton.isHidden = false
                feedButton.setTitle("Mange", for: .normal)
                //playAnimation(key: "waitStandUp",infinity: true)
            }
//        } else {
//            if let hit = hitResultsFeaturePoints.first {
//                if dog != nil {
//                    if !walk {
//                        walk = true
//                        destination  = SCNVector3 (hit.worldTransform.translation.x, hit.worldTransform.translation.y, hit.worldTransform.translation.z)
//                        let distanceDestToCam = calculateDistance(from: destination, to: positionOfCamera)
//                        let distanceFromToCam = calculateDistance(from: dogPosition, to: positionOfCamera)
//                        let distanceDestToFrom = calculateDistance(from: destination, to: dog.position)
//                        let angle = acos((distanceFromToCam * distanceFromToCam + distanceDestToFrom * distanceDestToFrom - distanceDestToCam * distanceDestToCam) / (2 * distanceFromToCam * distanceDestToFrom)) //* 180 / Float.pi
//                        print(angle)
//                        dog.eulerAngles.y = angle
//
//                        //dog.transform = SCNMatrix4MakeRotation((Float.pi/2 - atan(dogPosition.x / dogPosition.z))*180/Float.pi , 0, 1, 0)
//                        //dog.transform = SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y, 0, 1, 0)
//
////                        dog.eulerAngles.y = atan((dogPosition.x - destination.x)/(dogPosition.z - destination.z))*180/Float.pi
//                        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ViewController.move), userInfo: nil, repeats: true)
//                    }
//                }
//            }
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
       
        if let estimate = self.sceneView.session.currentFrame?.lightEstimate {
            sceneLight.intensity = estimate.ambientIntensity
        }
//        if dog != nil && !walk {
//            dog.eulerAngles.y = sceneView.session.currentFrame!.camera.eulerAngles.y
//        }
        if dogHere {
            self.focusSquare.hide()
        } else {
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
            if (smallerZ  && destination.x > dog.position.x) || (!smallerX  && destination.x < dog.position.x){
                if (smallerZ  && destination.z > dog.position.z) || (!smallerZ  && destination.z < dog.position.z){
                    walk = false
                    dogPosition = dog.position
//                    guard let pointOfView = sceneView.pointOfView else { return }
//                    let transform = pointOfView.transform
//                    let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
//                    let location = SCNVector3(transform.m41, transform.m42, transform.m43)
//                    positionOfCamera = SCNVector3(orientation.x + location.x, orientation.y + location.y, orientation.z + location.z)
                    dog.eulerAngles.y = sceneView.session.currentFrame!.camera.eulerAngles.y
                    stopAnimation(key: "walk")
                    playAnimation(key: "waitStandUp", infinity: true)
                    comeButton.setTitle("Au pied", for: .normal)
                    sitButton.isHidden = false
                    downButton.isHidden = false
                    feedButton.isHidden = false
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
            //dog.eulerAngles.y = sceneView.session.currentFrame!.camera.eulerAngles.y
            walk = true
            stopAnimation(key: "wouf")
            playAnimation(key: "walk", infinity: true)
            comeButton.setTitle("Stop", for: .normal)
            sitButton.isHidden = true
            downButton.isHidden = true
            feedButton.isHidden = true
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ViewController.move), userInfo: nil, repeats: true)
        } else {
            walk = false
            dogPosition = dog.position
            sitButton.isHidden = false
            downButton.isHidden = false
            feedButton.isHidden = false
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
            feedButton.isHidden = true
        } else {
            sit = false
            sitButton.setTitle("Assis", for: .normal)
            stopAnimation(key: "waitSit")
            stopAnimation(key: "sit")
            playAnimation(key: "up", infinity: false)
            comeButton.isHidden = false
            downButton.isHidden = false
            feedButton.isHidden = false
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
            feedButton.isHidden = true
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
            playAnimation(key: "waitStandUp", infinity: true)
        }
    }
    
    @IBAction func feed(_ sender: Any) {
        if !feed && dog != nil {
            let eat = SCNScene(named: "art.scnassets/shibaEat2.dae")!
            if let bowleat = eat.rootNode.childNodes.first?.childNodes.first {
                dog.childNodes.first?.addChildNode(bowleat)
            }
            feed = true
            feedButton.setTitle("Stop", for: .normal)
            playAnimation(key: "drink", infinity: true)
            playAnimation(key: "eat", infinity: false)
            comeButton.isHidden = true
            sitButton.isHidden = true
            downButton.isHidden = true
        } else {
            if let bowleat = sceneView.scene.rootNode.childNodes.last?.childNodes.first?.childNodes.last {
                print(bowleat)
                bowleat.removeFromParentNode()
            }
            feed = false
            feedButton.setTitle("Mange", for: .normal)
            stopAnimation(key: "drink")
            stopAnimation(key: "eat")
            comeButton.isHidden = false
            sitButton.isHidden = false
            downButton.isHidden = false
            playAnimation(key: "waitStandUp", infinity: true)
        }
    }
    
}
