//
//  SettingsView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(LibraryManager.self) private var library
    @AppStorage("defaultPlaybackSpeed") private var defaultPlaybackSpeed: Double = 1.0
    @AppStorage("skipForwardSeconds") private var skipForwardSeconds: Double = 30
    @AppStorage("skipBackwardSeconds") private var skipBackwardSeconds: Double = 15
    @AppStorage("colorSchemePreference") private var colorSchemePreference: Int = 0

    @State private var showClearFilesAlert = false
    @State private var showClearFilesSuccess = false

    private let speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0]
    private let skipOptions: [Double] = [10, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                // Playback
                Section("Playback") {
                    Picker("Default Speed", selection: $defaultPlaybackSpeed) {
                        ForEach(speeds, id: \.self) { speed in
                            Text(speedLabel(speed)).tag(speed)
                        }
                    }
                    Picker("Skip Forward", selection: $skipForwardSeconds) {
                        ForEach(skipOptions, id: \.self) { sec in
                            Text("\(Int(sec)) seconds").tag(sec)
                        }
                    }
                    Picker("Skip Backward", selection: $skipBackwardSeconds) {
                        ForEach(skipOptions, id: \.self) { sec in
                            Text("\(Int(sec)) seconds").tag(sec)
                        }
                    }
                }

                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $colorSchemePreference) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                // Storage
                Section("Storage") {
                    HStack {
                        Text("Used Space")
                        Spacer()
                        Text(library.formattedStorageUsed())
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        showClearFilesAlert = true
                    } label: {
                        Label("Clear Unused Files", systemImage: "trash")
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Clear Unused Files?", isPresented: $showClearFilesAlert) {
                Button("Clear", role: .destructive) {
                    library.clearUnusedFiles()
                    showClearFilesSuccess = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete audio files not associated with any book in your library.")
            }
            .alert("Done", isPresented: $showClearFilesSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Unused files have been removed.")
            }
            .preferredColorScheme(preferredScheme)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == 1.0 ? "1×" : String(format: "%.2g×", speed)
    }
}

#Preview {
    SettingsView()
        .environment(LibraryManager())
}
