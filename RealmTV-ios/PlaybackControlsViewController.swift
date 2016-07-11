//
//  PlaybackControlsViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 09/07/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import UIKit

protocol PlaybackControlsViewControllerDelegate: class {
    func updateSlide(attributes: [String: Int])
    func toggleTranscript(followsVideoProgress: Bool)
    func adjustPlayback(speed: Float)
}

class PlaybackControlsViewController: UIViewController {
    weak var delegate: PlaybackControlsViewControllerDelegate?
    @IBOutlet weak var slidePositionSegmentedControl: UISegmentedControl!
    @IBOutlet weak var slideSizeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var transcriptShouldFollowSwitch: UISwitch!
    
    @IBAction func slideControlValueChanged(_ sender: AnyObject) {
        delegate?.updateSlide(attributes: ["slide-position": slidePositionSegmentedControl.selectedSegmentIndex, "slide-size": slideSizeSegmentedControl.selectedSegmentIndex])
    }
    
    @IBAction func transcriptShouldFollowSwitchToggled(_ sender: UISwitch) {
        delegate?.toggleTranscript(followsVideoProgress: sender.isOn)
    }
    
    @IBAction func playBackSpeedSliderValueChanged(_ sender: UISlider) {
        delegate?.adjustPlayback(speed: sender.value)
    }
}
