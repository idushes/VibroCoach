//
//  ContentView.swift
//  VibroCoach
//
//  Created by Andrei Boiko on 22.06.2025.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var isPressed = false
    @State private var connectionStatus = "Tap the button to test"
    
    var body: some View {
        ZStack {
            // Фон приложения
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Заголовок
                Text("VibroCoach")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Основная кнопка
                Button(action: {
                    buttonPressed()
                }) {
                    VStack(spacing: 10) {
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
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            isPressed = true
                        }
                        .onEnded { _ in
                            isPressed = false
                        }
                )
                
                Spacer()
                
                // Статус
                Text(connectionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            setupWatchConnection()
        }
    }
    
    private func buttonPressed() {
        connectionStatus = "Button pressed! Setting up watch connection..."
        
        // Добавляем небольшую задержку для демонстрации
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sendVibrateCommand()
        }
    }
    
    private func setupWatchConnection() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = WatchConnector.shared
            session.activate()
            connectionStatus = "Setting up Apple Watch connection..."
        } else {
            connectionStatus = "WatchConnectivity not supported on this device"
        }
    }
    
    private func sendVibrateCommand() {
        guard WCSession.default.isReachable else {
            connectionStatus = "Apple Watch not reachable"
            return
        }
        
        let message = ["action": "vibrate"]
        WCSession.default.sendMessage(message, replyHandler: { response in
            DispatchQueue.main.async {
                self.connectionStatus = "Vibration command sent ✓"
            }
        }) { error in
            DispatchQueue.main.async {
                self.connectionStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
}

class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()
    
    private override init() {
        super.init()
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            // Можно добавить логику обновления UI здесь
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Handle session deactivation
    }
}

#Preview {
    ContentView()
}
