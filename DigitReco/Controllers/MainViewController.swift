
import UIKit

class MainViewController: UIViewController {
    
    // View
    let mainView = MainView()
    
    // Neural network
    var neuralNet: NeuralNet!
    
    // Drawing state variables
    /// The sketch brush width.
    fileprivate let brushWidth: CGFloat = 20
    /// The last point traced by the brush during drawing.
    fileprivate var lastDrawPoint = CGPoint.zero
    /// Traces a bounding box around the sketch for easy extraction.
    fileprivate var boundingBox: CGRect?
    /// Flag designating whether the user has dragged on the canvas during drawing.
    fileprivate var hasSwiped = false
    /// Flag designating whether the user is currently in the process of drawing.
    fileprivate var isDrawing = false
    /// Timer used for snapshotting the sketch.
    fileprivate var timer = Timer()
    /// Flag designating whether first touch was at output view
    fileprivate var touchBeagnAtOutput = false
    /// Flag designating whether last result was confident
    fileprivate var isLastResultConfident = false
    
    fileprivate var recognitionLog = ""
    
    override func loadView() {
        mainView.delegate = self
        self.view = mainView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize neural network
        do {
            if let savedNetwork = readSavedNetwork() {
                neuralNet = savedNetwork
            } else {
                guard let url = Bundle.main.url(forResource: "neuralnet-mnist-trained_my_50x1", withExtension: nil) else {
                    fatalError("Unable to locate trained neural network file in bundle.")
                }
                neuralNet = try NeuralNet(url: url)
            }
        } catch {
            fatalError("\(error)")
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    fileprivate func readSavedNetwork() -> NeuralNet? {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                return try NeuralNet(url: url.appendingPathComponent("nn"))
            }
            catch {
                print(error)
            }
        }
        return nil
    }
    
    fileprivate func saveNetwork() {
        let fileManager = FileManager.default
        if let path = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = path.appendingPathComponent("nn")
            do {
                try neuralNet.save(to: url)
            }
            catch {
                print(error)
            }
        }
    }
}


// MARK: Touch handling

extension MainViewController {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Reset swipe state tracker
        hasSwiped = false
        
        // Make sure the touch is inside the canvas
        guard mainView.canvasContainer.frame.contains(touch.location(in: mainView)) else {
            if mainView.networkOutputView.frame.contains(touch.location(in: mainView)) {
                touchBeagnAtOutput = true
            }
            return super.touchesBegan(touches, with: event)
        }
        
        // Determine touch point
        let location = touch.location(in: mainView.canvas)
        
        // Reset bounding box if needed
        if boundingBox == nil {
            boundingBox = CGRect(x: location.x - brushWidth / 2,
                                 y: location.y - brushWidth / 2,
                                 width: brushWidth, height: brushWidth)
        }
        
        // Store draw location
        lastDrawPoint = location
        
        // Set drawing flag
        isDrawing = true
        
        // Invalidate timer
        timer.invalidate()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Make sure the touch is inside the canvas
        guard mainView.canvasContainer.frame.contains(touch.location(in: mainView)) else {
            hasSwiped = false
            return super.touchesMoved(touches, with: event)
        }
        
        // Determine touch point
        let currentPoint = touch.location(in: mainView.canvas)
        
        // Reset bounding box if needed
        if boundingBox == nil {
            boundingBox = CGRect(x: currentPoint.x - brushWidth,
                                 y: currentPoint.y - brushWidth,
                                 width: brushWidth, height: brushWidth)
        }
        
        // Draw a line from previous to current touch point
        if hasSwiped {
            drawLine(from: lastDrawPoint, to: currentPoint)
        } else {
            drawLine(from: currentPoint, to: currentPoint)
            hasSwiped = true
        }
        
        // Expand the bounding box to fit the extremes of the sketch
        if currentPoint.x < boundingBox!.minX {
            stretchBoundingBox(minX: currentPoint.x - brushWidth,
                               maxX: nil, minY: nil, maxY: nil)
        } else if currentPoint.x > boundingBox!.maxX {
            stretchBoundingBox(minX: nil,
                               maxX: currentPoint.x + brushWidth,
                               minY: nil, maxY: nil)
        }
        
        if currentPoint.y < boundingBox!.minY {
            stretchBoundingBox(minX: nil, maxX: nil,
                               minY: currentPoint.y - brushWidth,
                               maxY: nil)
        } else if currentPoint.y > boundingBox!.maxY {
            stretchBoundingBox(minX: nil, maxX: nil, minY: nil,
                               maxY: currentPoint.y + brushWidth)
        }
        
        // Store draw location
        lastDrawPoint = currentPoint
        
        // Invalidate timer
        timer.invalidate()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Make sure touch is inside canvas
        if mainView.canvasContainer.frame.contains(touch.location(in: mainView)) {
            if !hasSwiped {
                // Draw dot
                drawLine(from: lastDrawPoint, to: lastDrawPoint)
            }
        }
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] (_) in
            self?.timerExpired()
        }
        
        // We're no longer drawing
        isDrawing = false
        if mainView.networkOutputView.frame.contains(touch.location(in: mainView)) && touchBeagnAtOutput {
            touchBeagnAtOutput = false
            didTapCorrection()
        }
        super.touchesEnded(touches, with: event)
    }
    
}


// MARK: Drawing and image manipulation

extension MainViewController {
    
    /// Draws a line on the canvas between the given points.
    fileprivate func drawLine(from: CGPoint, to: CGPoint) {
        // Begin graphics context
        UIGraphicsBeginImageContext(mainView.canvas.bounds.size)
        let context = UIGraphicsGetCurrentContext()
        
        // Store current sketch in context
        mainView.canvas.image?.draw(in: mainView.canvas.bounds)
        
        // Append new line to image
        context?.move(to: from)
        context?.addLine(to: to)
        context?.setLineCap(CGLineCap.round)
        context?.setLineWidth(brushWidth)
        context?.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
        context?.strokePath()
        
        // Store modified image back into image view
        mainView.canvas.image = UIGraphicsGetImageFromCurrentImageContext()
        
        // End context
        UIGraphicsEndImageContext()
    }
    
    /// Crops the given UIImage to the provided CGRect.
    fileprivate func crop(_ image: UIImage, to: CGRect) -> UIImage {
        let img = image.cgImage!.cropping(to: to)
        return UIImage(cgImage: img!)
    }
    
    /// Scales the given image to the provided size.
    fileprivate func scale(_ image: UIImage, to: CGSize) -> UIImage {
        let size = CGSize(width: min(20 * image.size.width / image.size.height, 20),
                          height: min(20 * image.size.height / image.size.width, 20))
        let newRect = CGRect(x: 0, y: 0, width: size.width, height: size.height).integral
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        let context = UIGraphicsGetCurrentContext()
        context?.interpolationQuality = .none
        image.draw(in: newRect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /// Centers the given image in a clear 28x28 canvas and returns the result.
    fileprivate func addBorder(to image: UIImage) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: 28, height: 28))
        image.draw(at: CGPoint(x: (28 - image.size.width) / 2,
                               y: (28 - image.size.height) / 2))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /// Updates the bounding box to stretch to the provided extremes.
    /// If `nil` is passed for any value, the box's current value will be preserved.
    fileprivate func stretchBoundingBox(minX: CGFloat?, maxX: CGFloat?, minY: CGFloat?, maxY: CGFloat?) {
        guard let box = boundingBox else { return }
        boundingBox = CGRect(x: minX ?? box.minX,
                             y: minY ?? box.minY,
                             width: (maxX ?? box.maxX) - (minX ?? box.minX),
                             height: (maxY ?? box.maxY) - (minY ?? box.minY))
    }
    
    /// Resets the canvas for a new sketch.
    fileprivate func clearCanvas() {
        // Animate snapshot box
        if let box = boundingBox {
            mainView.snapshotBox.frame = box
            mainView.snapshotBox.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            // Spring outward
            UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [], animations: { 
                self.mainView.snapshotBox.alpha = 1
                self.mainView.snapshotBox.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
            }, completion: nil)
            // Spring back inward
            UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [], animations: { 
                self.mainView.snapshotBox.transform = CGAffineTransform.identity
            }, completion: nil)
        }
        
        // Animate the sketch and bounding box away
        UIView.animate(withDuration: 0.1, delay: 0.4, options: [.curveEaseIn], animations: { 
            self.mainView.canvas.alpha = 0
            self.mainView.snapshotBox.alpha = 0
        }) { (_) in
            self.mainView.canvas.image = nil
            self.mainView.canvas.alpha = 1
        }
    }
    
}

// MARK: Classification

extension MainViewController {
    
    /// Called when the timer expires after the user stops drawing.
    fileprivate func timerExpired() {
        // Perform classification
        classifyImage()
        // Reset bounding box
        boundingBox = nil
    }
    
    /// Attempts to classify the current sketch, displays the result, and clears the canvas.
    private func classifyImage() {
        // Clear canvas when finished
        defer { clearCanvas() }
        
        // Extract and resize image from drawing canvas
        guard let imageArray = scanImage() else { return }
        
        performClassification(imageArray)
        
        // Clear the canvas
        clearCanvas()
    }
    /// makes another attempt to classify current downscaled image.
    fileprivate func reclassifyImage() {
        guard let imageArray = rescanImage() else { return }
        
        performClassification(imageArray)
    }
    
    private func performClassification(_ imageArray: [Float]) {
        // Perform classification
        do {
            let output = try neuralNet.infer(imageArray)
            var logValues = [String]()
            for (index, value) in output.enumerated() {
                logValues.append("\(index)-\((value * 100).toString(decimalPlaces: 1))%")
            }
            self.recognitionLog += "\(logValues.reduce("", { $0 == "" ? $1 : $0 + ", " + $1 }))\n"
            if let (label, confidence) = label(from: output) {
                displayOutputLabel(label: label, confidence: confidence)
            } else {
                mainView.outputLabel.text = "Err"
            }
        } catch {
            print(error)
        }
    }
    
    /// Scans the current image from the canvas and returns the pixel data as Floats.
    private func scanImage() -> [Float]? {

        guard let image = mainView.canvas.image, let box = boundingBox else {
            return nil
        }
        
        // Extract drawing from canvas and remove surrounding whitespace
        let croppedImage = crop(image, to: box)
        
        // Scale sketch to max 20px in both dimmensions
        let scaledImage = scale(croppedImage, to: CGSize(width: 20, height: 20))
        
        // Center sketch in 28x28 white box
        let character = addBorder(to: scaledImage)
        
        // Dispaly character in view
        mainView.networkInputCanvas.image = character
        
        return pixelsArray(from: character)
    }
    
    private func pixelsArray(from image: UIImage) -> [Float]? {
        
        var pixelsArray = [Float]()
        
        // Extract pixel data from scaled/cropped image
        guard let cgImage = image.cgImage else { return nil }
        guard let pixelData = cgImage.dataProvider?.data else { return nil }
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        // Iterate through
        var position = 0
        for _ in 0..<Int(image.size.height) {
            for _ in 0..<Int(image.size.width) {
                // We only care about the alpha component
                let alpha = Float(data[position + 3])
                // Scale alpha down to range [0, 1] and append to array
                pixelsArray.append(alpha / 255)
                // Increment position
                position += bytesPerPixel
            }
            if position % bytesPerRow != 0 {
                position += (bytesPerRow - (position % bytesPerRow))
            }
        }
        return pixelsArray
    }
    
    private func rescanImage() -> [Float]? {
        guard let image = mainView.networkInputCanvas.image else { return nil }
        return pixelsArray(from: image)
    }
    
    /// Extracts the output integer and confidence from the given neural network output.
    private func label(from output: [Float]) -> (label: Int, confidence: Float)? {
        guard let max = output.max() else { return nil }
        return (output.index(of: max)!, max)
    }
    
    /// Displays the given label and confidence in the output view.
    private func displayOutputLabel(label: Int, confidence: Float) {
        // Only display label if confidence > 50%

        if confidence < 0.5 {
            isLastResultConfident = false
        } else {
            isLastResultConfident = true
        }
        let labelStr = "\(label)"
        let confidenceStr = "Confidence: \((confidence * 100).toString(decimalPlaces: 1))%"
        
        // Animate labels outward and change text
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: { 
            self.mainView.outputLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.mainView.confidenceLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.mainView.outputLabel.text = self.isLastResultConfident ? labelStr : ""
            self.mainView.confidenceLabel.text = self.isLastResultConfident ? confidenceStr : "can't recognize"
        }, completion: nil)
        
        // Spring labels back to normal position
        UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: { 
            self.mainView.outputLabel.transform = CGAffineTransform.identity
            self.mainView.confidenceLabel.transform = CGAffineTransform.identity
        }, completion: nil)
    }
}

// MARK: Correction

enum CorrectionCase {
    case networkInitiated, userInitiated
    var title: String {
        switch self {
        case .networkInitiated: return "Sorry for being stupid"
        case .userInitiated: return "Am i wrong?"
        }
    }
    
    var message: String {
        switch self {
        case .networkInitiated: return "teach me please"
        case .userInitiated: return "which one is correct?"
        }
    }
}

extension MainViewController {
    
    internal func didTapCorrection() {
        animateOutputViewTouch {
            self.askForCorrectionValue(forCase: self.isLastResultConfident ? .userInitiated : .networkInitiated) { value in
                self.performCorrection( value)
            }
        }
    }
    
    /// Displays touch confirmation for output view.
    private func animateOutputViewTouch(completion: @escaping () -> Void) {
        // Animate output view inward
        mainView.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
            self.mainView.networkOutputView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: nil)
        
        // Spring output view to normal position
        UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
            self.mainView.networkOutputView.transform = CGAffineTransform.identity
        }) { result in
            self.mainView.isUserInteractionEnabled = true
            completion()
        }
    }
    
    fileprivate func askForCorrectionValue(forCase correctionCase: CorrectionCase, completion: @escaping (Float) -> Void) {
        let alert = UIAlertController(title: correctionCase.title, message: correctionCase.message, preferredStyle: .actionSheet)
        for x in 0...9 {
            let action = UIAlertAction(title: "\(x)", style: .default, handler: { _ in
                completion(Float(x))
            })
            alert.addAction(action)
        }
        alert.view.tintColor = UIColor.saiOrange()
        
        let cancelAction = UIAlertAction(title: "cancel", style: .cancel) { _ in }
        alert.addAction(cancelAction)
        present(alert, animated: true) { }
    }
    
    private func performCorrection(_ value: Float) {
        var labels = [Float]()
        for i in 0...9 {
            labels.append(Float(i) == value ? 1 : 0)
        }
        do {
            try neuralNet.backpropagate(labels) {
                self.reclassifyImage()
                self.saveNetwork()
            }
        } catch {
            print(error)
        }
    }
}

// MARK: Settings
extension MainViewController: MainViewDelegate {
    func didTapSettingsButton() {
        var info = SettingsInfo()
        info.log = recognitionLog
        let settingsViewController = SettingsViewController(info: info)
        settingsViewController.modalTransitionStyle = .flipHorizontal
        present(settingsViewController, animated: true) { }
    }
}
