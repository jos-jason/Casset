# Background Audio Setup Guide

## What I've Changed in the Code

I've updated `AudioPlayerManager.swift` to support background audio playback. Here's what was added:

### 1. **Audio Session Configuration** (`setupAudioSession()`)
- Sets the audio session category to `.playback` - this tells iOS the app plays audio
- Uses `.spokenAudio` mode - optimized for audiobooks and podcasts
- Activates the session so it persists when the app goes to background

### 2. **Remote Control Integration** (`setupRemoteTransportControls()`)
- Hooks into iOS's `MPRemoteCommandCenter`
- Enables Lock Screen and Control Center playback controls
- Supports: Play, Pause, Skip Forward, Skip Backward, and Scrubbing
- Uses your app's existing skip duration setting

### 3. **Now Playing Info** (`updateNowPlayingInfo()`)
- Updates the Lock Screen with:
  - Book title
  - Cover artwork
  - Current playback position
  - Total duration
  - Chapter information
  - Playback speed
- This makes your audiobook visible in Control Center and on the Lock Screen

## What You Need to Do in Xcode

### **Enable Background Audio Capability**

This is the crucial step that you must do manually:

1. Open your project in Xcode
2. Click on your project in the Project Navigator (top file)
3. Select your app target (under "TARGETS")
4. Click the "Signing & Capabilities" tab at the top
5. Click the "+ Capability" button
6. Search for and add "Background Modes"
7. In the new "Background Modes" section, check the box for:
   - ✅ **Audio, AirPlay, and Picture in Picture**

**This step is required** - without this capability, iOS will pause your audio when the screen locks or the app goes to the background.

## How It Works

### Audio Session
The audio session tells iOS what kind of audio your app plays. By setting it to `.playback` category with `.spokenAudio` mode:
- Your audio continues when the screen locks
- Your audio continues when the user switches apps
- The system knows to pause your audio for phone calls
- The system applies appropriate audio ducking for notifications

### Remote Commands
When you lock your device or pull down Control Center, you'll see playback controls. These controls send commands to your app through `MPRemoteCommandCenter`. The code now:
- Listens for these commands
- Calls the appropriate methods (play, pause, skip, etc.)
- Returns success/failure status to the system

### Now Playing Info
This is the metadata that appears on:
- Lock Screen
- Control Center
- CarPlay
- AirPods controls
- Apple Watch

The code updates this info whenever:
- A book loads
- Playback starts/stops
- The user skips or seeks
- Chapters change

## Testing

Once you've enabled the capability:

1. **Run your app** on a real device (background audio is limited in Simulator)
2. **Start playing an audiobook**
3. **Lock your device** - the audio should keep playing
4. **Wake the device** - you should see playback controls on the Lock Screen
5. **Swipe down Control Center** - you should see your audiobook with artwork
6. **Use the Lock Screen controls** - they should control your app's playback

## Troubleshooting

**Audio stops when I lock the device:**
- Make sure you enabled the "Audio, AirPlay, and Picture in Picture" background mode
- Check that you're testing on a real device (not Simulator)
- Verify the capability is checked in your target's Signing & Capabilities

**No controls appear on Lock Screen:**
- Make sure you started playback before locking
- Check that `updateNowPlayingInfo()` is being called (you should see the artwork)

**Controls don't work:**
- Check the console for any errors about command targets
- Verify `setupRemoteTransportControls()` is called during initialization

## Advanced: What Could Be Added Later

- **Interruption Handling**: Resume playback after phone calls
- **Route Change Handling**: Pause when headphones are unplugged
- **Background Task**: Save playback position periodically
- **Siri Integration**: "Hey Siri, play my audiobook"

For now, basic background playback should work perfectly!
