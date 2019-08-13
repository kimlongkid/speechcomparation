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
    static var SpeechKey = "SpeechKey"
    static var StateKey = "StateKey"
    static var MicroButtonKey = "MicroButtonKey"
    static var MicroButtonHeightKey = "MicroButtonHeightKey"
    static var MicroButtonTitleListeningKey = "Press me to listen your voice!"
    static var MicroButtonTitleStopKey = "Stop"
    static var SpeechRecognizerKey = "SpeechRecognizerKey"
    static var RecognitionRequestKey = "RecognitionRequestKey"
    static var RecognitionTaskKey = "RecognitionTaskKey"
    static var AudioEngineKey = "AudioEngineKey"
    static var SubtitleHeightKey = "SubtitleHeightKey"
    static var SpeechTextHeightKey = "SpeechTextHeightKey"
    static var PayloadKey = "PayloadKey"
    static var PlayerStatusKey = "PlayerStatusKey"
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

    var speechRecognizer: SFSpeechRecognizer?{
        get{return objc_getAssociatedObject(self, &AssociatedKeys.SpeechRecognizerKey) as? SFSpeechRecognizer }
        set (newValue) {objc_setAssociatedObject(self, &AssociatedKeys.SpeechRecognizerKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?{
        get{return objc_getAssociatedObject(self, &AssociatedKeys.RecognitionRequestKey) as? SFSpeechAudioBufferRecognitionRequest }
        set (newValue) {objc_setAssociatedObject(self, &AssociatedKeys.RecognitionRequestKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }
    private var recognitionTask: SFSpeechRecognitionTask?{
        get{return objc_getAssociatedObject(self, &AssociatedKeys.RecognitionTaskKey) as? SFSpeechRecognitionTask }
        set (newValue) {objc_setAssociatedObject(self, &AssociatedKeys.RecognitionTaskKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }
    private var audioEngine: AVAudioEngine?{
        get{return objc_getAssociatedObject(self, &AssociatedKeys.AudioEngineKey) as? AVAudioEngine }
        set (newValue) {objc_setAssociatedObject(self, &AssociatedKeys.AudioEngineKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }

    // MARK: - Public properties
    var subtitleLabel: UILabel? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SubtitleKey) as? UILabel }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SubtitleKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var speechTextLabel: UILabel? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SpeechKey) as? UILabel }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SpeechKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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
    
    fileprivate var speechTextLabelHeightConstraint: NSLayoutConstraint? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.SpeechTextHeightKey) as? NSLayoutConstraint }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.SpeechTextHeightKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var parsedPayload: NSDictionary? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.PayloadKey) as? NSDictionary }
        set (value) { objc_setAssociatedObject(self, &AssociatedKeys.PayloadKey, value, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // MARK: - Public methods
    func addSubtitles() -> Self {
        // Create label
        addSubtitleLabel()
        return self
    }
    
    func addSpeechText() {
        // Create label
        addSpeechTexLabel()
        speechTextLabel?.text = "Speak follow the subtitle below!"
    }
    
    func open(file filePath: URL, encoding: String.Encoding = String.Encoding.utf8, shouldCreateIndex: Bool) {
        
        let contents = try! String(contentsOf: filePath, encoding: encoding)
        show(subtitles: contents, shouldCreateIndex: shouldCreateIndex)
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
    
    func getSubtileAtTime(time: Double) ->String?{
        return Subtitles.searchSubtitles(self.parsedPayload, time)
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
    
    // MARK: - Private methods
    fileprivate func addSpeechTexLabel() {
        
        guard let _ = speechTextLabel else {
            
            // Label
            speechTextLabel = UILabel()
            speechTextLabel?.translatesAutoresizingMaskIntoConstraints = false
            speechTextLabel?.backgroundColor = UIColor.clear
            speechTextLabel?.textAlignment = .center
            speechTextLabel?.numberOfLines = 0
            speechTextLabel?.font = UIFont.boldSystemFont(ofSize: UI_USER_INTERFACE_IDIOM() == .pad ? 30.0 : 15.0)
            speechTextLabel?.textColor = UIColor.white
            speechTextLabel?.numberOfLines = 0;
            speechTextLabel?.layer.shadowColor = UIColor.black.cgColor
            speechTextLabel?.layer.shadowOffset = CGSize(width: 1.0, height: 1.0);
            speechTextLabel?.layer.shadowOpacity = 0.9;
            speechTextLabel?.layer.shadowRadius = 1.0;
            speechTextLabel?.layer.shouldRasterize = true;
            speechTextLabel?.layer.rasterizationScale = UIScreen.main.scale
            speechTextLabel?.lineBreakMode = .byWordWrapping
            contentOverlayView?.addSubview(speechTextLabel!)
            
            // Position
            var constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-(20)-[l]-(20)-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["l" : speechTextLabel!])
            contentOverlayView?.addConstraints(constraints)
            if UI_USER_INTERFACE_IDIOM() == .pad {
                constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-(70)-[l]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["l" : speechTextLabel!])
            }
            else{
                constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-(45)-[l]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["l" : speechTextLabel!])
            }
            contentOverlayView?.addConstraints(constraints)
            
            speechTextLabelHeightConstraint = NSLayoutConstraint(item: speechTextLabel!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1.0, constant: 30.0)
            contentOverlayView?.addConstraint(speechTextLabelHeightConstraint!)
            
            return
            
        }
        
    }
}
