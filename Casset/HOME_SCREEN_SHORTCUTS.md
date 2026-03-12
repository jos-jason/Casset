# Adding Audiobook Shortcuts to Home Screen 📱

This guide shows you how to pin your audiobooks to the home screen so you can resume playback with a single tap!

## What's New

I've updated the App Intents to support:
- ✅ **Playing specific audiobooks** from your library
- ✅ **Book selection** in the Shortcuts app
- ✅ **Recently played books** shown first
- ✅ **Search functionality** to find books by title or author
- ✅ **Home screen shortcuts** for instant playback

## How to Add a Book to Your Home Screen

### Method 1: Create a Shortcut for a Specific Book

1. Open the **Shortcuts** app
2. Tap **+** to create a new shortcut
3. Search for your app name
4. Select **"Play Audiobook"**
5. Tap "Book" and you'll see:
   - Your **recently played** books (up to 5)
   - A **search bar** to find other books
6. Select the book you want
7. Tap the shortcut name and rename it (e.g., "Dune")
8. Tap the ⓘ icon
9. Tap **"Add to Home Screen"**
10. Choose an icon color or add a custom glyph
11. Tap **Add**

Now you have a home screen icon that instantly plays that specific audiobook! 🎉

### Method 2: Using Siri

You can also use Siri to play specific books:

1. Say: **"Hey Siri, play [Book Title] in [App Name]"**
2. Siri will find and play that book

## What Happens When You Tap the Icon

When you tap a home screen shortcut:
1. The app receives the command in the background
2. It loads the selected audiobook
3. Playback starts automatically
4. You see Lock Screen controls immediately

**You don't even need to open the app!** Just tap and listen.

## Creating Shortcuts for Recently Played Books

The Shortcuts app will **automatically suggest** your most recently played audiobooks when you create a "Play Audiobook" action. This makes it super quick to pin your current reads!

## Advanced: Custom Shortcuts

You can combine the audiobook intents with other actions:

### Example: "Morning Audiobook"
1. Turn off Do Not Disturb
2. Set volume to 50%
3. Play [Your Book]
4. Open your coffee app timer

### Example: "Workout Audiobook"  
1. Start workout timer
2. Play [Your Book]
3. Set volume to 80%

### Example: "Bedtime Story"
1. Turn on Night Shift
2. Set volume to 30%
3. Play [Your Book]
4. Set sleep timer for 30 minutes (if you add that intent)

## How Books Are Sorted

When you open the book picker in Shortcuts, you'll see:

1. **Suggested** - Your 5 most recently played books
2. **Search** - Type to find any book by title or author
3. **All Books** - Browse your complete library (sorted by recent)

## Tips & Tricks

### Organize with Folders
Create a folder called "Audiobooks" on your home screen and put all your book shortcuts there!

### Use Different Icons
Give each book shortcut a different color or symbol to make them easy to distinguish at a glance.

### Create Collections
Make shortcuts for different moods:
- "Focus" → Your educational/non-fiction books
- "Relax" → Your fiction/entertainment books
- "Sleep" → Your sleep stories or calm narration

### Share Shortcuts
If someone else uses your app, you can share your shortcuts with them! Tap the share button in the Shortcuts app.

## Technical Details

### How It Works
1. The `BookEntity` represents audiobooks in your library
2. The `BookEntityQuery` reads from your app's UserDefaults storage
3. When you select a book, it creates a `PlayAudiobookIntent`
4. The intent posts a notification with the book's ID
5. The `AudioPlayerManager` receives it and starts playback

### Data Access
The shortcuts read your library from UserDefaults using the same storage key as your app (`"casset_library"`). This means:
- ✅ No extra permissions needed
- ✅ Works offline
- ✅ Always up-to-date with your library
- ✅ Respects your privacy (all local)

### What Gets Synced
If you use iCloud for Shortcuts sync, your audiobook shortcuts will sync across all your devices! However, the actual audiobook files need to be on each device.

## Troubleshooting

### "I don't see my books in the picker"
- Make sure you've added books to your library
- Try playing a book in the app first
- Force quit and reopen the Shortcuts app
- Check that you've selected the "Play Audiobook" action (not "Resume Audiobook")

### "The book doesn't play when I tap the shortcut"
- Make sure the book file is still accessible on your device
- Try playing it in the app first
- Check that background audio is enabled
- Look for errors in the Xcode console

### "Search doesn't find my book"
- Make sure you spelled it correctly
- Try searching by author instead
- The search is case-insensitive and matches partial titles

### "Recently played books aren't showing up"
- Play some books in the app first
- The list updates based on `lastInteracted` timestamp
- Force quit and reopen Shortcuts to refresh

## Voice Commands for Specific Books

You can also ask Siri to play specific books by name:

- "Hey Siri, play Dune in [App Name]"
- "Hey Siri, play The Hobbit in [App Name]"
- "Hey Siri, play my Harry Potter audiobook in [App Name]"

Siri will search your library and play the matching book!

## What's Next?

Future enhancements you could add:
- **Book artwork** in the Shortcuts picker (requires custom app intents UI)
- **Playback position** shown in shortcut details
- **Progress percentage** in the book entity
- **Series grouping** in the picker
- **Smart suggestions** based on time of day

Enjoy your one-tap audiobook access! 🎧✨
