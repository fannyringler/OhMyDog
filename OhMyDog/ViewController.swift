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
    var destination:SCNVector3!
    var timer = Timer()
    
    var focusSquare = FocusSquare()
    
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
        
        sceneLight = SCNLight()
        sceneLight.type = .omni
        
        let lightNode = SCNNode()
        lightNode.light = sceneLight
        lightNode.position = SCNVector3(x: 0, y: 10, z: 2)
        
        dogHere = false
        
        sceneView.scene.rootNode.addChildNode(lightNode)
        
        modelScene = SCNScene(named: "art.scnassets/shibaWouf.dae")!
        
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
        let y = from.y - to.y
        return sqrtf( (x * x) + (y * y))
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
                sceneView.session.add(anchor: ARAnchor(transform: finalTransform))
                dogHere = true
            }
        } else {
            if let hit = hitResultsFeaturePoints.first {
                // hit.localTransform ou hit.worldTransform
                destination  = SCNVector3 (hit.worldTransform.translation.x, hit.worldTransform.translation.y, hit.worldTransform.translation.z)
                modelScene = SCNScene(named: "art.scnassets/shibaWalk.dae")!
                if dog != nil {
                    //playAnimation(key: "walk")
                    //dog = modelScene.rootNode.childNode(withName: nodeName, recursively: true)
                    walk = true
                    //dog.position = position
                    timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.move), userInfo: nil, repeats: true)
                    
                }
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
        if let estimate = self.sceneView.session.currentFrame?.lightEstimate {
            sceneLight.intensity = estimate.ambientIntensity
        }
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
        loadAnimation(withKey: "walk", sceneName: "art.scnassets/shibaWalk", animationIdentifier: "<untitled animation>")
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
    
    func playAnimation(key: String) {
        // Add the animation to start playing it right away
        sceneView.scene.rootNode.addAnimation(animations[key]!, forKey: key)
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
                    indexX -= 0.1
                }
            } else {
                if destination.x > indexX {
                    indexX += 0.1
                }
            }
            var indexY = dog.position.y
            var smallerY = destination.y < dogPosition.y
            if smallerY {
                if destination.y < indexY {
                    indexY -= 0.1
                }
            } else {
                if destination.y > indexY {
                    indexY += 0.1
                }
            }
            dog.position = SCNVector3Make(indexX, indexY, dog.position.z)
            if (smallerX && smallerY && destination.x > dog.position.x) || (!smallerX && !smallerY && destination.x < dog.position.x){
                walk = false
                timer.invalidate()
                dogPosition = dog.position
            }
            
        }
    }
    
    func moveSlowy(){
        
    }

}
