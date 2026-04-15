# Siri Setup Checklist ✅

## Required Files (All Created ✅)

- [x] `AudiobookIntents.swift` - Contains all Siri intents
- [x] `AudioPlayerManager.swift` - Updated with Siri notification handlers
- [x] `CassetApp.swift` - Updated with `import AppIntents`

## What You DON'T Need

❌ **No "Siri" capability required** - This was deprecated in recent iOS versions
❌ **No Intents Extension** - The old way of doing things
❌ **No Info.plist entries** - AppIntents handles everything automatically

## How to Verify It's Working

### Method 1: Check in Shortcuts App (Quickest)

1. Build and run your app
2. Open the **Shortcuts** app on your device
3. Tap **+** to create a new shortcut
4. In the search bar, type your app's name
5. You should see these actions appear:
   - **Play Audiobook** (NEW! Select specific books)
   - Resume Audiobook
   - Pause Audiobook
   - Skip Forward
   - Skip Back

**If you see these, Siri is working!** 🎉

### Method 1b: Test Book Selection (NEW!)

1. In Shortcuts, add the **"Play Audiobook"** action
2. Tap on "Book"
3. You should see:
   - Your recently played books listed
   - A search bar to find books
4. Select a book
5. Run the shortcut - it should play that book!

**This is the feature that lets you pin books to your home screen!**

### Method 2: Use Siri Directly

1. Build and run your app
2. Play an audiobook for a few seconds
3. Lock your phone or go home
4. Wait 2-3 minutes for iOS to index the intents (first time only)
5. Say: **"Hey Siri, pause my audiobook in [Your App Name]"**
6. It should pause!

### Method 3: Check System Settings

1. Go to **Settings** → **Siri & Search**
2. Scroll down to find your app
3. Tap on it
4. You should see "Shortcuts" listed

## Common Issues

### "I don't see my app in Shortcuts"
**Solution:** 
- Make sure you've built and run the app at least once
- Wait a few minutes for iOS to index
- Try force-quitting and reopening the Shortcuts app
- Restart your device if needed

### "Siri says 'I couldn't find that'"
**Solution:**
- Make sure you're saying the exact app name
- Wait 5 minutes for indexing
- Try using it from Shortcuts first to "wake up" the intents
- Check that your app is actually running or has run recently

### Build Errors
**Solution:**
- Make sure `AudiobookIntents.swift` is in your Xcode project (not just the folder)
- Check that it's included in your target's "Compile Sources"
- Right-click the file in Xcode → Show File Inspector → make sure target is checked

## Testing Without Siri

If you just want to verify the code works, you can manually trigger the intents:

```swift
// Add this to a button for testing
NotificationCenter.default.post(name: NSNotification.Name("PauseAudiobookFromSiri"), object: nil)
```

This will trigger the same code path as Siri would.

## What Happens Behind the Scenes

1. When your app launches, iOS scans for `AppShortcutsProvider` types
2. It finds `AudiobookShortcuts` in `AudiobookIntents.swift`
3. It reads the `appShortcuts` property
4. It registers all the intents and phrases
5. These become available to Siri and Shortcuts

All of this is **automatic** - you don't need to do anything!

## Next Steps

Once you verify it's working:

1. Test all the commands (play, pause, skip forward, skip back)
2. **Test selecting a specific book in the "Play Audiobook" action** (NEW!)
3. **Add a book shortcut to your home screen** (see `HOME_SCREEN_SHORTCUTS.md`)
4. Try creating a custom shortcut in Shortcuts app
5. Consider adding more intents (sleep timer, bookmarks, etc.)

## Still Having Issues?

Check the Xcode console when you trigger a Siri command. You should see the notification being posted and handled. If you don't see anything, there might be an issue with the setup.

You can also add print statements to `setupSiriIntentHandlers()` to verify it's being called:

```swift
private func setupSiriIntentHandlers() {
    print("🎤 Setting up Siri intent handlers...")
    // ... rest of code
}
```

Then when you run the app, you should see "🎤 Setting up Siri intent handlers..." in the console.
