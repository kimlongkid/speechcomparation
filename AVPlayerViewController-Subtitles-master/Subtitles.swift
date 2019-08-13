//
//  Subtitles.swift
//  Subtitles
//
//  Created by mhergon on 23/12/15.
//  Copyright © 2015 mhergon. All rights reserved.
//

import ObjectiveC
import MediaPlayer
import AVKit
import CoreMedia
import Speech

private struct AssociatedKeys {
    static var FontKey = "FontKey"
    static var ColorKey = "FontKey"
    static var SubtitleKey = "SubtitleKey"
    static var StateKey = "StateKey"
    static var MicroButtonKey = "MicroButtonKey"
    static var MicroButtonTitleListeningKey = "Listen"
    static var MicroButtonTitleStopKey = "Stop"
    static var SpeechRecognizerKey = "SpeechRecognizerKey"
    static var SubtitleHeightKey = "SubtitleHeightKey"
    static var PayloadKey = "PayloadKey"
}

public class Subtitles {
    
    // MARK: - Properties
    fileprivate var parsedPayload: NSDictionary?
    
    // MARK: - Public methods
    public init(file filePath: URL, encoding: String.Encoding = String.Encoding.utf8) {
        
        // Get string
        let string = try! String(contentsOf: filePath, encoding: encoding)
        
        // Parse string
        parsedPayload = Subtitles.parseSubRip(string, shouldCreateIndex: false)
        
    }
    
    public init(subtitles string: String) {
        
        // Parse string
        parsedPayload = Subtitles.parseSubRip(string, shouldCreateIndex: false)
        
    }
    
    /// Search subtitles at time
    ///
    /// - Parameter time: Time
    /// - Returns: String if exists
    public func searchSubtitles(at time: TimeInterval) -> String? {
        
        return Subtitles.searchSubtitles(parsedPayload, time)
        
    }
    
    // MARK: - Private methods

    /// Subtitle parser
    ///
    /// - Parameter payload: Input string
    /// - Returns: NSDictionary
    fileprivate static func parseSubRip(_ payload: String, shouldCreateIndex: Bool) -> NSDictionary? {
        
        do {
            
            // Prepare payload
            var payload = payload.replacingOccurrences(of: "\n\r\n", with: "\n\n")
            payload = payload.replacingOccurrences(of: "\n\n\n", with: "\n\n")
            payload = payload.replacingOccurrences(of: "\r\n", with: "\n")
            
            // Parsed dict
            let parsed = NSMutableDictionary()
            
            // Get groups
            let regexStr = "(\\d+)\\n([\\d:,.]+)\\s+-{2}\\>\\s+([\\d:,.]+)\\n([\\s\\S]*?(?=\\n{2,}|$))"
            let regex = try NSRegularExpression(pattern: regexStr, options: .caseInsensitive)
            let matches = regex.matches(in: payload, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, payload.characters.count))
            var indexOfSub = 1;
            for m in matches {
                
                let group = (payload as NSString).substring(with: m.range)
                
                // Get index
                var regex = try NSRegularExpression(pattern: "^[0-9]+", options: .caseInsensitive)
                var match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, group.characters.count))
                guard let i = match.first else {
                    continue
                }
                let index = (group as NSString).substring(with: i.range)
                
                // Get "from" & "to" time
                regex = try NSRegularExpression(pattern: "\\d{1,2}:\\d{1,2}:\\d{1,2}[,.]\\d{1,3}", options: .caseInsensitive)
                match = regex.matches(in: group, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, group.characters.count))
                guard match.count == 2 else {
                    continue
                }
                guard let from = match.first, let to = match.last else {
                    continue
                }
                
                var h: TimeInterval = 0.0, m: TimeInterval = 0.0, s: TimeInterval = 0.0, c: TimeInterval = 0.0
                
                let fromStr = (group as NSString).substring(with: from.range)
                var scanner = Scanner(string: fromStr)
                scanner.scanDouble(&h)
                scanner.scanString(":", into: nil)
                scanner.scanDouble(&m)
                scanner.scanString(":", into: nil)
                scanner.scanDouble(&s)
                scanner.scanString(",", into: nil)
                scanner.scanDouble(&c)
                let fromTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)
                
                let toStr = (group as NSString).substring(with: to.range)
                scanner = Scanner(string: toStr)
                scanner.scanDouble(&h)
                scanner.scanString(":", into: nil)
                scanner.scanDouble(&m)
                scanner.scanString(":", into: nil)
                scanner.scanDouble(&s)
                scanner.scanString(",", into: nil)
                scanner.scanDouble(&c)
                let toTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)
                
                // Get text & check if empty
                let range = NSMakeRange(0, to.range.location + to.range.length + 1)
                guard (group as NSString).length - range.length > 0 else {
                    continue
                }
                let text = (group as NSString).replacingCharacters(in: range, with: "")
                
                // Create final object
                let final = NSMutableDictionary()
                final["from"] = fromTime
                final["to"] = toTime
                final["text"] = text
                if (shouldCreateIndex){
                    parsed[indexOfSub] = final
                    indexOfSub += 1
                }
                else{
                    parsed[index] = final
                }
                
            }
            
            return parsed
            
        } catch {
            
            return nil
            
        }
        
    }
    
    /// Search subtitle on time
    ///
    /// - Parameters:
    ///   - payload: Inout payload
    ///   - time: Time
    /// - Returns: String
    fileprivate static func searchSubtitles(_ payload: NSDictionary?, _ time: TimeInterval) -> String? {
        
        let predicate = NSPredicate(format: "(%f >= %K) AND (%f <= %K)", time, "from", time, "to")
        
        guard let values = payload?.allValues, let result = (values as NSArray).filtered(using: predicate).first as? NSDictionary else {
            return nil
        }
        
        guard let text = result.value(forKey: "text") as? String else {
            return nil
        }
        
        return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
    }
    
}

public extension AVPlayerViewController {
    
    enum SpeakingState {
        case Listening
        case Stop
    }
    
    var speechRecognizer: SFSpeechRecognizer?{
        get{return objc_getAssociatedObject(self, &AssociatedKeys.StateKey) as? SFSpeechRecognizer }
        set (newValue) {objc_setAssociatedObject(self, &AssociatedKeys.SpeechRecognizerKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }
    
    var listeningState: SpeakingState?{
        get{return objc_getAssociatedObject(self, &AssociatedKeys.StateKey) as? SpeakingState }
        set (newValue) {objc_setAssociatedObject(self, &AssociatedKeys.StateKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }

    // MARK: - Public properties
    var subtitleLabel: UILabel? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleKey) as? UILabel }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var microButton: UIButton? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.MicroButtonKey) as? UIButton }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.MicroButtonKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // MARK: - Private properties
    fileprivate var subtitleLabelHeightConstraint: NSLayoutConstraint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleHeightKey) as? NSLayoutConstraint }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleHeightKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    fileprivate var parsedPayload: NSDictionary? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.PayloadKey) as? NSDictionary }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.PayloadKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // MARK: - Public methods
    func addSubtitles() -> Self {
        
        // Create label
        addSubtitleLabel()
        
        return self
        
    }
    
    func addMicro(){
        // Create label
        addMicroButton()
    }

    
    func open(file filePath: URL, encoding: String.Encoding = String.Encoding.utf8, shouldCreateIndex: Bool) {
        
        let contents = try! String(contentsOf: filePath, encoding: encoding)
        show(subtitles: contents, shouldCreateIndex: shouldCreateIndex)
        listeningState = SpeakingState.Listening
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))  //1
        speechRecognizer?.delegate = self as! SFSpeechRecognizerDelegate  //3
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4
            
            var isButtonEnabled = false
            
            switch authStatus {  //5
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
        }
    }
    
    func show(subtitles string: String, shouldCreateIndex: Bool) {
        
        // Parse
        parsedPayload = Subtitles.parseSubRip(string, shouldCreateIndex: shouldCreateIndex)
        
        // Add periodic notifications
        self.player?.addPeriodicTimeObserver(
            forInterval: CMTimeMake(1, 60),
            queue: DispatchQueue.main,
            using: { [weak self] (time) -> Void in
                
                guard let strongSelf = self else { return }
                guard let label = strongSelf.subtitleLabel else { return }
                
                // Search && show subtitles
                label.text = Subtitles.searchSubtitles(strongSelf.parsedPayload, time.seconds)
                
                // Adjust size
                let baseSize = CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude)
                let rect = label.sizeThatFits(baseSize)
                if label.text != nil {
                    strongSelf.subtitleLabelHeightConstraint?.constant = rect.height + 5.0
                } else {
                    strongSelf.subtitleLabelHeightConstraint?.constant = rect.height
                }
                
                
        })
        
    }
    
    // MARK: - Private methods
    fileprivate func addSubtitleLabel() {
        
        guard let _ = subtitleLabel else {
            
            // Label
            subtitleLabel = UILabel()
            subtitleLabel?.translatesAutoresizingMaskIntoConstraints = false
            subtitleLabel?.backgroundColor = UIColor.clear
            subtitleLabel?.textAlignment = .center
            subtitleLabel?.numberOfLines = 0
            subtitleLabel?.font = UIFont.boldSystemFont(ofSize: UI_USER_INTERFACE_IDIOM() == .pad ? 40.0 : 22.0)
            subtitleLabel?.textColor = UIColor.white
            subtitleLabel?.numberOfLines = 0;
            subtitleLabel?.layer.shadowColor = UIColor.black.cgColor
            subtitleLabel?.layer.shadowOffset = CGSize(width: 1.0, height: 1.0);
            subtitleLabel?.layer.shadowOpacity = 0.9;
            subtitleLabel?.layer.shadowRadius = 1.0;
            subtitleLabel?.layer.shouldRasterize = true;
            subtitleLabel?.layer.rasterizationScale = UIScreen.main.scale
            subtitleLabel?.lineBreakMode = .byWordWrapping
            contentOverlayView?.addSubview(subtitleLabel!)
            
            // Position
            var constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-(20)-[l]-(20)-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["l" : subtitleLabel!])
            contentOverlayView?.addConstraints(constraints)
            constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[l]-(30)-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["l" : subtitleLabel!])
            contentOverlayView?.addConstraints(constraints)
            subtitleLabelHeightConstraint = NSLayoutConstraint(item: subtitleLabel!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 30.0)
            contentOverlayView?.addConstraint(subtitleLabelHeightConstraint!)
            
            return
            
        }
        
    }
    
    fileprivate func addMicroButton(){
        guard let _ = microButton else {
            microButton = UIButton(type: UIButtonType.custom)
            microButton?.backgroundColor = UIColor.white
            microButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: UI_USER_INTERFACE_IDIOM() == .pad ? 40.0 : 22.0)
            microButton?.setTitle(AssociatedKeys.MicroButtonTitleListeningKey, for: .normal)
            microButton?.setTitleColor(UIColor.black, for: .normal)
            self.view.addSubview(microButton!)
            self.view.bringSubview(toFront: microButton!)
            
            microButton?.translatesAutoresizingMaskIntoConstraints = false
            let verticalConstraint = NSLayoutConstraint(item: microButton!, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 20)
            self.view.addConstraint(verticalConstraint)

            let horizontalConstraint = NSLayoutConstraint(item: microButton!, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0)
            self.view.addConstraint(horizontalConstraint)
            
//            let widthConstraint = NSLayoutConstraint(item: microButton!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
//            contentOverlayView?.addConstraint(widthConstraint)
//
//            let heightConstraint = NSLayoutConstraint(item: microButton!, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
//            contentOverlayView?.addConstraint(heightConstraint)
//            NSLayoutConstraint.activate([horizontalConstraint, verticalConstraint, widthConstraint, heightConstraint])
            NSLayoutConstraint.activate([horizontalConstraint, verticalConstraint])

            return
        }
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches{
            let location = touch.location(in: self.view)
            if (microButton?.frame.contains(location))!{
                respeak()
            }
        }
    }
    
    fileprivate func respeak(){
        switch listeningState {
        case .Listening?:
            //set title for listening
            listeningState = SpeakingState.Stop
            microButton?.setTitle(AssociatedKeys.MicroButtonTitleStopKey, for: .normal)

            break
        case .Stop?:
            //set title for stopped
            listeningState = SpeakingState.Listening
            microButton?.setTitle(AssociatedKeys.MicroButtonTitleListeningKey, for: .normal)

            break
        default:
            //set title for waiting
            print("State not set")
            break
        }
        print(listeningState)
    }
    
    func getCurrentSubtitle() -> String?{
        let text = Subtitles.searchSubtitles(self.parsedPayload, (self.player?.currentTime().seconds)!)
        print(text)
        return text
    }
}

public extension SFSpeechRecognizerDelegate{
    
}
