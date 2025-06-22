//
//  ContentView.swift
//  VibroCoach
//
//  Created by Andrei Boiko on 22.06.2025.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @StateObject private var watchConnector = WatchConnector()
    
    var body: some View {
        VStack {
            Spacer()
            
            Button(action: {
                watchConnector.sendVibrateCommand()
            }) {
                VStack {
                    Image(systemName: "applewatch")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("VIBRATE")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: 200, height: 200)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
            }
            .scaleEffect(watchConnector.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: watchConnector.isPressed)
            .onTapGesture {
                watchConnector.isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    watchConnector.isPressed = false
                }
            }
            
            Spacer()
            
            Text(watchConnector.connectionStatus)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding()
    }
}

class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    @Published var connectionStatus = "Connecting to Apple Watch..."
    @Published var isPressed = false
    
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
            connectionStatus = "WatchConnectivity not supported"
        }
    }
    
    func sendVibrateCommand() {
        guard WCSession.default.isReachable else {
            connectionStatus = "Apple Watch not reachable"
            return
        }
        
        let message = ["action": "vibrate"]
        WCSession.default.sendMessage(message, replyHandler: { response in
            DispatchQueue.main.async {
                self.connectionStatus = "Command sent ✓"
            }
        }) { error in
            DispatchQueue.main.async {
                self.connectionStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                if session.isWatchAppInstalled {
                    self.connectionStatus = "Apple Watch connected ✓"
                } else {
                    self.connectionStatus = "Install app on Apple Watch"
                }
            case .inactive:
                self.connectionStatus = "Session inactive"
            case .notActivated:
                self.connectionStatus = "Session not activated"
            @unknown default:
                self.connectionStatus = "Unknown state"
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionStatus = "Session became inactive"
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionStatus = "Session deactivated"
        }
    }
}

#Preview {
    ContentView()
}
