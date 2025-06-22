//
//  ContentView.swift
//  VibroCoach Watch App
//
//  Created by Andrei Boiko on 22.06.2025.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @StateObject private var watchManager = WatchManager()
    
    var body: some View {
        VStack {
            Image(systemName: "applewatch")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("VibroCoach")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            Text(watchManager.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            if watchManager.lastVibrateTime != nil {
                Text("Last vibration:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(watchManager.formattedLastVibrateTime)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
}

class WatchManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var statusMessage = "Waiting for connection..."
    @Published var lastVibrateTime: Date?
    
    var formattedLastVibrateTime: String {
        guard let lastVibrateTime = lastVibrateTime else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: lastVibrateTime)
    }
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            statusMessage = "WatchConnectivity not supported"
        }
    }
    
    private func performVibration() {
        // Выполняем тактильную обратную связь на Apple Watch
        WKInterfaceDevice.current().play(.notification)
        
        DispatchQueue.main.async {
            self.lastVibrateTime = Date()
            self.statusMessage = "Vibration performed ✓"
        }
        
        // Сбрасываем статус через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusMessage = "Ready"
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.statusMessage = "Ready"
            case .inactive:
                self.statusMessage = "Session inactive"
            case .notActivated:
                self.statusMessage = "Session not activated"
            @unknown default:
                self.statusMessage = "Unknown state"
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let action = message["action"] as? String, action == "vibrate" {
            performVibration()
            replyHandler(["status": "success"])
        } else {
            replyHandler(["status": "unknown_action"])
        }
    }
}

#Preview {
    ContentView()
}
