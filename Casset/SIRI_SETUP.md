# Siri Integration Setup Guide

## What I've Added

I've created `AudiobookIntents.swift` with App Intents that enable Siri voice control and Shortcuts integration for your audiobook app.

### Intents Created

1. **PlayAudiobookIntent** - Play or resume audiobook
2. **PauseAudiobookIntent** - Pause playback
3. **ResumeAudiobookIntent** - Resume playback (dedicated command)
4. **SkipForwardIntent** - Skip forward (with optional custom seconds)
5. **SkipBackwardIntent** - Skip backward (with optional custom seconds)

### How It Works

- Each intent posts a notification that `AudioPlayerManager` listens for
- The audio manager then performs the requested action
- All intents work in the background (app doesn't need to be open)
- Intents are registered via `AudiobookShortcuts` provider

## Setup Instructions

### Step 1: Add the Siri Capability

1. Open your project in Xcode
2. Select your app target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add **"Siri"**

That's it! No extra configuration needed with the modern AppIntents framework.

### Step 2: (Optional) Test in Shortcuts App

Before testing with Siri, verify the intents are working:

1. Open the **Shortcuts** app on your device
2. Tap **+** to create a new shortcut
3. Search for your app name
4. You should see actions like:
   - Resume Audiobook
   - Pause Audiobook  
   - Skip Forward
   - Skip Back

If you see these, your intents are registered correctly!

## Using Siri Commands

Once set up, you can use these voice commands:

### Play/Resume Commands
- "Resume my audiobook in [App Name]"
- "Continue my audiobook in [App Name]"
- "Play my audiobook in [App Name]"

### Pause Commands
- "Pause my audiobook in [App Name]"
- "Stop my audiobook in [App Name]"

### Skip Forward
- "Skip forward in [App Name]"
- "Skip ahead in my audiobook"

### Skip Backward  
- "Skip back in [App Name]"
- "Go back in my audiobook"

**Replace [App Name] with your actual app name.**

## Testing Tips

### First Time Setup
1. Run your app from Xcode
2. Play an audiobook for a few seconds
3. Wait 2-3 minutes for iOS to index the intents
4. Try a simple command: "Hey Siri, pause my audiobook in [App Name]"

### If Siri Doesn't Respond
- Wait longer - intent indexing can take up to 5 minutes
- Restart your device
- Open the Shortcuts app to verify intents are visible
- Check that you spelled/pronounced your app name correctly
- Look in Console.app for AppIntents errors

### Debugging
You can check if notifications are being received:
1. Set a breakpoint in `setupSiriIntentHandlers()` in AudioPlayerManager
2. Trigger a Siri command
3. See if the notification handler fires

## Creating Custom Shortcuts

Users can create powerful custom shortcuts:

### Example: "Bedtime Audiobook"
1. Open Shortcuts app
2. Create new shortcut called "Bedtime Audiobook"
3. Add action: "Resume Audiobook" (from your app)
4. Add action: "Set Sleep Timer" (if you add a sleep timer intent)
5. Add action: "Turn on Do Not Disturb"
6. Now saying "Hey Siri, bedtime audiobook" does all three!

### Example: Home Screen Widget
1. Create a shortcut with "Resume Audiobook"
2. Add to Home Screen
3. Tap the icon to instantly resume without opening the app

## Advanced Features You Can Add

### More Intent Parameters
```swift
@Parameter(title: "Book")
var book: BookEntity?  // Let users choose which book
```

### Intent Return Values
```swift
func perform() async throws -> some IntentResult & ReturnsValue<String> {
    return .result(value: "Now playing: \(bookTitle)")
}
```

### Suggested Shortcuts
iOS can suggest your shortcuts based on:
- Time of day
- Location  
- Headphone connection
- User routines

Add this to your intents for smart suggestions!

### Visual Snippets
Show playback info in the Siri UI with snippets and custom views.

## Troubleshooting

**"I couldn't find that in [App Name]"**
- The intent might not have the right discoverability settings
- Make sure `isDiscoverable = true` on your intents
- Try using the exact phrase from `AppShortcut.phrases`

**Siri opens the app instead of running in background**
- Check that `openAppWhenRun = false` on your intents
- This is already set in the code I provided

**Nothing happens when I use Siri**
- Check Console.app for crashes or errors
- Verify notifications are being posted (add print statements)
- Make sure `setupSiriIntentHandlers()` is being called
- Check that your AudioPlayerManager has a player loaded

**Works in Shortcuts but not Siri**
- This is usually a phrase matching issue
- Try the exact phrases defined in `AppShortcut.phrases`
- iOS learns your pronunciation over time

## What's Next?

Consider adding these intents:

- **SetSleepTimerIntent** - "Set audiobook timer for 30 minutes"
- **AddBookmarkIntent** - "Bookmark this in [App Name]"
- **JumpToChapterIntent** - "Go to chapter 3"
- **ChangeSpeedIntent** - "Speed up my audiobook"

The possibilities are endless! 🎉
