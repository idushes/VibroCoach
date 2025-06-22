//
//  ContentView.swift
//  VibroCoach
//
//  Created by Andrei Boiko on 22.06.2025.
//

import SwiftUI
import WatchConnectivity
import HealthKit

struct ContentView: View {
    @State private var isPressed = false
    @StateObject private var watchConnector = WatchConnector()
    
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
                .disabled(!watchConnector.isReady)
                .opacity(watchConnector.isReady ? 1.0 : 0.6)
                
                Spacer()
                
                // Статус
                VStack(spacing: 8) {
                    Text(watchConnector.connectionStatus)
                        .font(.caption)
                        .foregroundColor(watchConnector.isReady ? .secondary : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text(watchConnector.healthKitStatus)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !watchConnector.isReady {
                        Button("Reconnect") {
                            watchConnector.reconnect()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            watchConnector.requestHealthKitPermissions()
        }
    }
    
    private func buttonPressed() {
        watchConnector.sendVibrateCommand()
    }
}

class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    @Published var connectionStatus = "Connecting to Apple Watch..."
    @Published var healthKitStatus = "Requesting HealthKit permissions..."
    @Published var isReady = false
    
    private var session: WCSession?
    private let healthStore = HKHealthStore()
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitStatus = "HealthKit not available"
            return
        }
        
        // Запрашиваем разрешения для workout-сессий
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let typesToRead: Set<HKObjectType> = [workoutType, heartRateType]
        let typesToShare: Set<HKSampleType> = [workoutType]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.healthKitStatus = "HealthKit permissions granted ✓"
                } else {
                    self?.healthKitStatus = "HealthKit permissions denied"
                }
            }
        }
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            connectionStatus = "WatchConnectivity not supported"
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func reconnect() {
        connectionStatus = "Reconnecting..."
        isReady = false
        
        // Деактивируем текущую сессию если она есть
        if let session = session {
            session.delegate = nil
        }
        
        // Создаем новую сессию
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupWatchConnectivity()
        }
    }
    
    func sendVibrateCommand() {
        guard let session = session, session.activationState == .activated else {
            connectionStatus = "Session not ready"
            isReady = false
            return
        }
        
        connectionStatus = "Sending vibration command..."
        
        let message: [String: Any] = [
            "action": "vibrate",
            "timestamp": Date().timeIntervalSince1970,
            "healthKitEnabled": true
        ]
        
        // Пробуем отправить через sendMessage (для активного приложения)
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    self?.connectionStatus = "Vibration sent ✓"
                    // Сбрасываем статус через 2 секунды
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.updateConnectionStatus()
                    }
                }
            }) { [weak self] error in
                DispatchQueue.main.async {
                    // Если sendMessage не сработал, пробуем transferUserInfo
                    self?.sendViaTransferUserInfo(message: message)
                }
            }
        } else {
            // Если часы не достижимы, используем transferUserInfo
            sendViaTransferUserInfo(message: message)
        }
    }
    
    private func sendViaTransferUserInfo(message: [String: Any]) {
        guard let session = session else { return }
        
        connectionStatus = "Sending to background app..."
        
        // transferUserInfo доставляет сообщения даже когда приложение в фоне
        session.transferUserInfo(message)
        
        // Показываем статус отправки
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.connectionStatus = "Command queued for delivery ✓"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.updateConnectionStatus()
            }
        }
    }
    
    private func updateConnectionStatus() {
        guard let session = session else { return }
        
        if session.activationState == .activated {
            if session.isWatchAppInstalled {
                if session.isReachable {
                    connectionStatus = "Apple Watch ready ✓ (Active)"
                    isReady = true
                } else {
                    connectionStatus = "Apple Watch ready ✓ (Background)"
                    isReady = true
                }
            } else {
                connectionStatus = "Install app on Apple Watch"
                isReady = false
            }
        } else {
            connectionStatus = "Apple Watch not connected"
            isReady = false
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                self.updateConnectionStatus()
            case .inactive:
                self.connectionStatus = "Session inactive"
                self.isReady = false
            case .notActivated:
                self.connectionStatus = "Session not activated"
                self.isReady = false
            @unknown default:
                self.connectionStatus = "Unknown state"
                self.isReady = false
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionStatus = "Session became inactive"
            self.isReady = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionStatus = "Session deactivated"
            self.isReady = false
        }
        
        // Автоматически переподключаемся
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupWatchConnectivity()
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
}

#Preview {
    ContentView()
}
