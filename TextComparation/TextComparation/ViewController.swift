//
//  ViewController.swift
//  TextComparation
//
//  Created by LongTa on 6/19/18.
//  Copyright © 2018 LongTa. All rights reserved.
//

import UIKit
import MediaPlayer
import AVKit
import Speech

private struct AssociatedKeys {
    static var MicroButtonTitleListeningKey = "Press me to listen your voice!"
    static var MicroButtonTitleStopKey = "Stop"
}

class ViewController: UIViewController {

    let moviePlayer = AVPlayerViewController()
    var microButton:UIButton?
    var isRecording:Bool?
    var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSpeaker()
        isRecording = false
    }
    
    //MARK:- Actions
    @IBAction func watchMovie(_ sender: UIButton) {
        
        // Video file
        let videoFile = Bundle.main.path(forResource: "Deadpool-2-The-Trailer", ofType: "mp4")
        
        // Subtitle file
        let subtitleFile = Bundle.main.path(forResource: "Deadpool-2-The-Trailer", ofType: "srt")
        let subtitleURL = URL(fileURLWithPath: subtitleFile!)
        
        // Movie player
        moviePlayer.player = AVPlayer(url: URL(fileURLWithPath: videoFile!))
        present(moviePlayer, animated: true, completion: nil)
//        moviePlayer.showsPlaybackControls = false
        
        // Add subtitles
        moviePlayer.addSubtitles().open(file: subtitleURL, shouldCreateIndex: true)
        moviePlayer.addSubtitles().open(file: subtitleURL, encoding: .utf8, shouldCreateIndex: true)
//        moviePlayer.addMicro()
        addSpeechButton()
        moviePlayer.addSpeechText()
        
        // Change text properties
        moviePlayer.subtitleLabel?.textColor = UIColor.white
        moviePlayer.speechTextLabel?.textColor = UIColor.red
        
        // Play
        moviePlayer.player?.play()
    }
    
    func setupAudioSpeaker(){
        audioEngine = AVAudioEngine()
        isRecording = true
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))  //1
        speechRecognizer?.delegate = self as? SFSpeechRecognizerDelegate  //3
        
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
            
            self.microButton?.isEnabled = isButtonEnabled
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func addSpeechButton(){
        microButton = UIButton(type: UIButtonType.custom)
        microButton?.backgroundColor = UIColor.white
        microButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: UI_USER_INTERFACE_IDIOM() == .pad ? 30.0 : 15.0)
        microButton?.setTitle(AssociatedKeys.MicroButtonTitleListeningKey, for: .normal)
        microButton?.setTitleColor(UIColor.black, for: .normal)
        moviePlayer.contentOverlayView?.addSubview(microButton!)
        moviePlayer.contentOverlayView?.bringSubview(toFront: microButton!)
        
        microButton?.translatesAutoresizingMaskIntoConstraints = false
        let verticalConstraint = NSLayoutConstraint(item: microButton, attribute: NSLayoutAttribute.top, relatedBy: NSLayoutRelation.equal, toItem: moviePlayer.contentOverlayView, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 20)
        moviePlayer.contentOverlayView?.addConstraint(verticalConstraint)
        let horizontalConstraint = NSLayoutConstraint(item: microButton, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: moviePlayer.contentOverlayView, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0)
        moviePlayer.contentOverlayView?.addConstraint(horizontalConstraint)
        return
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches{
            let location = touch.location(in: moviePlayer.contentOverlayView)
            if (microButton?.frame.contains(location))!{
                respeak()
            }
        }
    }
    
    func respeak(){
        if (isRecording == false) {
            startRecording()
            print("******START******")
        } else {
            print("******STOP******")
            stopRecording()
        }
        isRecording = !isRecording!
        print(moviePlayer.player?.status.rawValue);
    }
    
    func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        let baseString = self.moviePlayer .getSubtileAtTime(time: self.moviePlayer.player?.currentTime().seconds ?? 0)
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine?.inputNode else {
            fatalError("Audio engine has no input node")
        }
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                
                self.moviePlayer.speechTextLabel?.text = result?.bestTranscription.formattedString
                self.compareBaseAndRecord(baseString: baseString ?? "", recordString: self.moviePlayer.speechTextLabel?.text ?? "")
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine?.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine?.prepare()
        
        do {
            try audioEngine?.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        moviePlayer.speechTextLabel?.text = ""
        microButton?.setTitle(AssociatedKeys.MicroButtonTitleStopKey, for: .normal)
        moviePlayer.player?.pause()
    }
    
    func stopRecording(){
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.inputNode.reset()
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        microButton?.setTitle(AssociatedKeys.MicroButtonTitleListeningKey, for: .normal)
        moviePlayer.speechTextLabel?.text = "Speak follow the subtitle below!"
        moviePlayer.player?.play()
    }
    
    func compareBaseAndRecord(baseString: String, recordString: String){
        let newBaseString = self.removePunctuation(text: baseString)
        let newRecordString = self.removePunctuation(text: recordString)
        NSLog("*******Subtitle: %@", baseString)
        NSLog("*******Speeched: %@", recordString)

        let arraySubtitleCharacter:[String] = newBaseString.components(separatedBy: " ")
        let arrayRecordedCharacter:[String] = newRecordString.components(separatedBy: " ")
        
        let attributed = NSMutableAttributedString(string: recordString)
        for index in 0..<(arrayRecordedCharacter.count){
            let recordedChar = arrayRecordedCharacter[index]
            if let subChar:String = arraySubtitleCharacter[index]{
                if recordedChar == subChar{
                    let range = (recordString as NSString).range(of: recordedChar)
                    attributed.addAttribute(NSAttributedStringKey.backgroundColor, value: UIColor.blue, range: range)
                }
            }
        }
        moviePlayer.speechTextLabel?.attributedText = attributed
    }
    
    func removePunctuation(text: String)->String{
        var newBaseString = text
        //remove break line symbol
        newBaseString = newBaseString.replacingOccurrences(of: "\n", with: " ")
        newBaseString = newBaseString.replacingOccurrences(of: "\\", with: "")
        //remove punctuations
        newBaseString = newBaseString.withoutSpecialCharacters
        return newBaseString
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        microButton?.isEnabled = available
    }
}
extension String {
    var withoutSpecialCharacters: String {
        return self.components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: "")
    }
}
