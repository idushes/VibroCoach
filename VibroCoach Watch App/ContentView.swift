//
//  ContentView.swift
//  VibroCoach Watch App
//
//  Created by Andrei Boiko on 22.06.2025.
//

import SwiftUI
import WatchConnectivity
import HealthKit

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
            
            VStack(spacing: 8) {
                Text(watchManager.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text(watchManager.healthKitStatus)
                    .font(.caption2)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                
                if watchManager.isWorkoutActive {
                    Text("Workout Session Active")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                }
            }
            
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
        .onAppear {
            watchManager.setupHealthKit()
        }
    }
}

class WatchManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var statusMessage = "Waiting for connection..."
    @Published var healthKitStatus = "Setting up HealthKit..."
    @Published var lastVibrateTime: Date?
    @Published var vibrationCount = 0
    @Published var isWorkoutActive = false
    
    private var session: WCSession?
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
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
    
    func setupHealthKit() {
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
                    self?.healthKitStatus = "HealthKit ready ✓"
                    self?.startWorkoutSession()
                } else {
                    self?.healthKitStatus = "HealthKit permissions denied"
                }
            }
        }
    }
    
    private func startWorkoutSession() {
        // Создаем конфигурацию для фитнес-сессии
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            // Создаем workout session
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            // Настраиваем данные для сбора
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            // Устанавливаем делегатов
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            // Начинаем сессию
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.isWorkoutActive = true
                        self?.healthKitStatus = "Background workout active ✓"
                    } else {
                        self?.healthKitStatus = "Failed to start workout"
                    }
                }
            }
            
        } catch {
            healthKitStatus = "Failed to create workout session"
        }
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
        // Выполняем более сильную тактильную обратную связь
        WKInterfaceDevice.current().play(.notification)
        
        // Дополнительная вибрация для лучшего эффекта
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WKInterfaceDevice.current().play(.click)
        }
        
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
                "delivery": "immediate",
                "workoutActive": isWorkoutActive
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

// MARK: - HKWorkoutSessionDelegate
extension WatchManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isWorkoutActive = true
                self.healthKitStatus = "Workout session running ✓"
            case .ended:
                self.isWorkoutActive = false
                self.healthKitStatus = "Workout session ended"
            case .paused:
                self.healthKitStatus = "Workout session paused"
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.healthKitStatus = "Workout session error"
            self.isWorkoutActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Данные собираются в фоне
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // События workout-сессии
    }
}

#Preview {
    ContentView()
}
