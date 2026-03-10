//
//  AudioPlayerManager.swift
//  Casset
//
//  Created by JJ vollum on 3/7/26.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Observation

@Observable
class AudioPlayerManager: NSObject {
    var currentBook: Book?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    var chapters: [Chapter] = []

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }

    // MARK: - Remote Command Center

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.play(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward(); return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward(); return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let book = currentBook else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: book.title,
            MPMediaItemPropertyArtist: book.author,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0
        ]
        if let data = book.coverImageData, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Load & Control

    func load(book: Book, library: LibraryManager) {
        // Save position for previous book
        if var prev = currentBook {
            prev.currentPosition = currentTime
            library.updateBook(prev)
        }

        // Remove old observers
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }

        currentBook = book
        playbackRate = book.playbackRate
        chapters = book.chapters
        duration = book.duration

        let playerItem = AVPlayerItem(url: book.fileURL)
        player = AVPlayer(playerItem: playerItem)

        if book.currentPosition > 0 {
            let time = CMTime(seconds: book.currentPosition, preferredTimescale: 1000)
            player?.seek(to: time)
            currentTime = book.currentPosition
        } else {
            currentTime = 0
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            self.updateNowPlayingInfo()
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnd(library: library)
        }

        updateNowPlayingInfo()
    }

    private func handlePlaybackEnd(library: LibraryManager) {
        isPlaying = false
        currentTime = 0
        player?.seek(to: .zero)
        if var book = currentBook {
            book.currentPosition = 0
            library.updateBook(book)
        }
        updateNowPlayingInfo()
    }

    func play() {
        player?.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 1000)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func skipForward(seconds: Double = 30) {
        seek(to: currentTime + seconds)
    }

    func skipBackward(seconds: Double = 15) {
        seek(to: currentTime - seconds)
    }

    func setRate(_ rate: Float, library: LibraryManager) {
        playbackRate = rate
        if isPlaying { player?.rate = rate }
        if var book = currentBook {
            book.playbackRate = rate
            library.updateBook(book)
        }
        updateNowPlayingInfo()
    }

    func savePosition(to library: LibraryManager) {
        if var book = currentBook {
            book.currentPosition = currentTime
            library.updateBook(book)
        }
    }

    func currentChapter() -> Chapter? {
        chapters.last { $0.startTime <= currentTime }
    }
}
