import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("playbackSpeed")       var playbackSpeed:       Double = 1.0
    @AppStorage("skipDuration")        var skipDuration:        Double = 30
    @AppStorage("showCoverOnCassette") var showCoverOnCassette: Bool   = true
    @AppStorage("showChapterTicker")   var showChapterTicker:   Bool   = true
    @AppStorage("cassetteMode")        var cassetteModeRaw:     String = CassetteMode.classic.rawValue
    @AppStorage("appAppearance")       var appAppearanceRaw:    String = AppAppearance.system.rawValue
    @AppStorage("colorIntensity")      var colorIntensity:      Double = 0.5
    
    @EnvironmentObject var playerManager: AudioPlayerManager

    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSleepMinutes: Int = 30

    let speeds:      [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0]
    let skipOptions: [Double] = [10, 15, 30, 45, 60]
    let sleepTimerOptions: [Int] = [5, 10, 15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Playback Speed", selection: $playbackSpeed) {
                        ForEach(speeds, id: \.self) { speed in
                            Text(speed == 1.0 ? "1×" : "\(speed, specifier: "%.2g")×")
                                .tag(speed)
                        }
                    }
                    Picker("Skip Duration", selection: $skipDuration) {
                        ForEach(skipOptions, id: \.self) { sec in
                            Text("\(Int(sec))s").tag(sec)
                        }
                    }
                } header: {
                    Text("Playback")
                }
                
                Section {
                    if playerManager.isSleepTimerActive {
                        HStack {
                            Text("Time Remaining")
                            Spacer()
                            Text(formatSleepTime(playerManager.sleepTimerRemaining))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                        }
                        
                        Button("Cancel Timer") {
                            playerManager.cancelSleepTimer()
                        }
                        .foregroundStyle(.red)
                    } else {
                        HStack {
                            Picker("Duration", selection: $selectedSleepMinutes) {
                                ForEach(sleepTimerOptions, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Button("Start") {
                                playerManager.setSleepTimer(minutes: selectedSleepMinutes)
                            }
                            .buttonStyle(.bordered)
                            .tint(.primary)
                        }
                    }
                } header: {
                    Text("Sleep Timer")
                } footer: {
                    if !playerManager.isSleepTimerActive {
                        Text("Playback will automatically pause when the timer expires.")
                    }
                }

                Section {
                    Picker("Cassette Style", selection: $cassetteModeRaw) {
                        ForEach(CassetteMode.allCases, id: \.rawValue) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Show Cover Art on Cassette", isOn: $showCoverOnCassette)
                    Toggle("Show Chapter Ticker",        isOn: $showChapterTicker)

                    Picker("Appearance", selection: $appAppearanceRaw) {
                        ForEach(AppAppearance.allCases, id: \.rawValue) { appearance in
                            Text(appearance.label).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cassette Color Intensity")
                        HStack {
                            Text("Darker")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $colorIntensity, in: 0...1)
                            Text("Brighter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Realistic mode shows animated tape sag that bounces on play, pause, and skip.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatSleepTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

