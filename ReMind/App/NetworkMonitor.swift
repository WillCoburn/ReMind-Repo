// ============================
// File: App/System/NetworkMonitor.swift
// ============================
import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var interfaceType: NWInterface.InterfaceType? = nil

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var retryTimer: Timer?
    private var restartWorkItem: DispatchWorkItem?
    private var consecutiveOfflineProbes = 0

    private init() {
        startMonitor()
        // Bootstrap immediately (Simulator can be lazy)
        DispatchQueue.main.async { [weak self] in
            self?.applyCurrentPath()
        }
    }

    // MARK: - Public “nudge” you can call on foreground
    func forceRefresh() {
        applyCurrentPath()
        if !isConnected {
            // start probing immediately if offline
            startRetrying()
        }
    }

    // MARK: - Monitor lifecycle
    private func startMonitor() {
        stopMonitor() // ensure clean
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            self?.handle(path: path)
        }
        m.start(queue: queue)
        monitor = m
        // Read once after start
        applyCurrentPath()
        // Cancel any planned restart when we start clean
        restartWorkItem?.cancel()
        restartWorkItem = nil
        consecutiveOfflineProbes = 0
        print("🌐 NWPathMonitor started")
    }

    private func stopMonitor() {
        monitor?.cancel()
        monitor = nil
        print("🌐 NWPathMonitor stopped")
    }

    // MARK: - Path handling
    private func handle(path: NWPath) {
        apply(path: path)

        if path.status == .satisfied {
            stopRetrying()
            consecutiveOfflineProbes = 0
            // If we had scheduled a restart, cancel it
            restartWorkItem?.cancel()
            restartWorkItem = nil
        } else {
            startRetrying()
            scheduleRestartIfNeeded()
        }
    }

    private func applyCurrentPath() {
        guard let m = monitor else { return }
        apply(path: m.currentPath)
    }

    private func apply(path: NWPath) {
        let connected = (path.status == .satisfied)
        let iface = path.availableInterfaces.first { path.usesInterfaceType($0.type) }?.type

        DispatchQueue.main.async {
            if self.isConnected != connected {
                print("🌐 Network status changed -> \(connected ? "ONLINE" : "OFFLINE")")
            }
            self.isConnected = connected
            self.interfaceType = iface
        }
    }

    // MARK: - Retry loop while offline (Simulator nudge)
    private func startRetrying() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.probeConnectivity()
        }
        if let t = retryTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func stopRetrying() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    /// If we remain offline for several probes, restart NWPathMonitor (works around stuck callbacks).
    private func scheduleRestartIfNeeded() {
        // If a restart is already scheduled, don't schedule another.
        guard restartWorkItem == nil else { return }

        // Schedule a restart in ~8 seconds (enough for a few probes).
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.isConnected {
                print("♻️ Restarting NWPathMonitor after extended offline period")
                self.startMonitor() // stop+start fresh
                // If still offline after restart, probing will continue.
            }
            self.restartWorkItem = nil
        }
        restartWorkItem = item
        queue.asyncAfter(deadline: .now() + 8, execute: item)
    }

    /// Lightweight HTTP probe that often kicks the stack to deliver a fresh NWPath.
    private func probeConnectivity() {
        // If we already think we're online, just apply currentPath and stop.
        if monitor?.currentPath.status == .satisfied {
            DispatchQueue.main.async { [weak self] in
                self?.applyCurrentPath()
                self?.stopRetrying()
                self?.consecutiveOfflineProbes = 0
            }
            return
        }

        guard let url = URL(string: "https://www.gstatic.com/generate_204") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 3

        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 3
        cfg.timeoutIntervalForResource = 3
        let session = URLSession(configuration: cfg)

        session.dataTask(with: req) { [weak self] _, resp, err in
            guard let self else { return }
            if err == nil, let http = resp as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                // We reached the internet — re-evaluate path & stop probing
                DispatchQueue.main.async {
                    self.applyCurrentPath()
                    if self.monitor?.currentPath.status == .satisfied {
                        self.stopRetrying()
                        self.consecutiveOfflineProbes = 0
                    }
                }
            } else {
                // Still offline
                self.consecutiveOfflineProbes += 1
                // If it's been a while, schedule (or keep) a restart
                self.scheduleRestartIfNeeded()
            }
        }.resume()
    }
}
