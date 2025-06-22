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
                VStack(spacing: 4) {
                    Text("Last vibration:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(watchManager.formattedLastVibrateTime)
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text("Count: \(watchManager.vibrationCount)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
}

class WatchManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var statusMessage = "Waiting for connection..."
    @Published var lastVibrateTime: Date?
    @Published var vibrationCount = 0
    
    private var session: WCSession?
    
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
        guard WCSession.isSupported() else {
            statusMessage = "WatchConnectivity not supported"
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    private func performVibration() {
        // Выполняем тактильную обратную связь на Apple Watch
        WKInterfaceDevice.current().play(.notification)
        
        DispatchQueue.main.async {
            self.lastVibrateTime = Date()
            self.vibrationCount += 1
            self.statusMessage = "Vibration performed ✓ (\(self.vibrationCount))"
        }
        
        // Сбрасываем статус через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.statusMessage = "Ready for next vibration"
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.statusMessage = "Connected - Ready"
            case .inactive:
                self.statusMessage = "Session inactive"
            case .notActivated:
                self.statusMessage = "Session not activated"
            @unknown default:
                self.statusMessage = "Unknown state"
            }
        }
    }
    
    // Для активного приложения (немедленная доставка)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Watch received immediate message: \(message)")
        
        if let action = message["action"] as? String, action == "vibrate" {
            performVibration()
            
            // Отправляем подтверждение с дополнительной информацией
            let response: [String: Any] = [
                "status": "success",
                "timestamp": Date().timeIntervalSince1970,
                "vibrationCount": vibrationCount,
                "delivery": "immediate"
            ]
            replyHandler(response)
        } else {
            replyHandler(["status": "unknown_action"])
        }
    }
    
    // Для фонового режима (надежная доставка)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("Watch received background message: \(userInfo)")
        
        if let action = userInfo["action"] as? String, action == "vibrate" {
            DispatchQueue.main.async {
                self.performVibration()
                
                // Обновляем статус для фонового сообщения
                self.statusMessage = "Background vibration ✓ (\(self.vibrationCount))"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.statusMessage = "Ready for next vibration"
                }
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            if session.isReachable {
                self.statusMessage = "iPhone connected"
            } else {
                self.statusMessage = "iPhone disconnected"
            }
        }
    }
}

#Preview {
    ContentView()
}
