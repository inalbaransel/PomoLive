import SwiftUI
import UIKit

/// Full-screen, OLED-black focus mode for a phone propped up on the desk. Shows a large clock or the
/// room at night, keeps the screen awake, follows the phone into landscape even though the app is
/// portrait-only, and nudges its content every minute so nothing burns into the panel.
/// Tap anywhere to reveal the controls; they fade away again on their own.
struct FocusModeView: View {
    let desk: DeskRecord
    let layout: LibraryLayout
    let desks: [String: DeskRecord]
    let clock: ServerClock
    let myUserId: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @AppStorage(Preferences.focusModeStyle) private var style = FocusModeStyle.clock
    @AppStorage(Preferences.clockFace) private var face = ClockFace.digital
    @AppStorage(Preferences.clockTint) private var tint = ClockTint.white
    @AppStorage(Preferences.clockShowsSeconds) private var showsSeconds = true
    @State private var showsControls = true
    @State private var hideTask: Task<Void, Never>?
    @State private var orientation = UIDevice.current.orientation
    @State private var burnInShift = CGSize.zero
    @State private var customizes = false
    @State private var showsPaywall = false

    private static let controlsVisibleFor = Duration.seconds(3)

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = orientation.isLandscape
            let size = isLandscape ? CGSize(width: proxy.size.height, height: proxy.size.width) : proxy.size
            content
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(orientation == .landscapeLeft ? 90 : orientation == .landscapeRight ? -90 : 0))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .animation(.spring(duration: 0.5, bounce: 0.1), value: orientation)
        }
        .background(.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .contentShape(.rect)
        // Simultaneous, so a tap still reaches the controls it lands on.
        .simultaneousGesture(TapGesture().onEnded { revealControls() })
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            revealControls()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let next = UIDevice.current.orientation
            if next.isPortrait || next.isLandscape, next != .portraitUpsideDown { orientation = next }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                withAnimation(.easeInOut(duration: 4)) {
                    burnInShift = CGSize(width: .random(in: -14...14), height: .random(in: -14...14))
                }
            }
        }
        .onChange(of: style) { old, new in
            guard new == .nightMap, !app.plus.isActive else { return }
            style = old
            showsPaywall = true
        }
        .plusPaywall(isPresented: $showsPaywall)
        .sheet(isPresented: $customizes) {
            FocusModeSettings(style: style, face: $face, tint: $tint, showsSeconds: $showsSeconds)
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch style {
            case .clock:
                clockFace
                    .offset(burnInShift)
            case .nightMap:
                NightMapView(layout: layout, desks: desks, myUserId: myUserId, tint: tint.color)
                    .padding(24)
                cornerClock
                    .offset(burnInShift)
            }
            controls
                .opacity(showsControls ? 1 : 0)
                .animation(.smooth(duration: 0.4), value: showsControls)
        }
        .transition(.opacity)
        .animation(.smooth(duration: 0.5), value: style)
    }

    /// Faces with a sweeping seconds hand redraw continuously; the digital one only once a second.
    private var clockFace: some View {
        TimelineView(.animation(minimumInterval: face == .digital || !showsSeconds ? 1 : 1.0 / 30)) { _ in
            let reading = ClockReading(timer: desk.timer, now: clock.now)
            Group {
                switch face {
                case .digital: DigitalFace(clock: reading, tint: tint.color, showsSeconds: showsSeconds)
                case .ring: RingFace(clock: reading, tint: tint.color, showsSeconds: showsSeconds)
                case .analog: AnalogFace(clock: reading, tint: tint.color, showsSeconds: showsSeconds)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// A small clock tucked into the bottom-right corner over the night map.
    private var cornerClock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let reading = ClockReading(timer: desk.timer, now: clock.now)
            VStack(alignment: .trailing, spacing: 2) {
                PhaseCaption(clock: reading, tint: tint.color)
                Text(verbatim: TimeText.string(reading))
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint.color)
                    .contentTransition(.numericText(countsDown: reading.isCountdown))
                    .animation(.smooth(duration: 0.4), value: reading.seconds)
                ProgressCapsule(progress: reading.progress, tint: tint.color)
                    .frame(width: 120)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 12) {
                Button("Kapat", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
                Picker("Görünüm", selection: $style) {
                    ForEach(FocusModeStyle.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Button("Özelleştir", systemImage: "paintpalette.fill") { customizes = true }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .tint(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, orientation.isLandscape ? 20 : 60)
        .allowsHitTesting(showsControls)
    }

    private func revealControls() {
        showsControls = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: Self.controlsVisibleFor)
            guard !Task.isCancelled, !customizes else { return }
            showsControls = false
        }
    }
}

/// Face, ink colour and seconds for the focus mode.
private struct FocusModeSettings: View {
    let style: FocusModeStyle
    @Binding var face: ClockFace
    @Binding var tint: ClockTint
    @Binding var showsSeconds: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                if style == .clock {
                    Section("Saat Stili") {
                        Picker("Saat Stili", selection: $face) {
                            ForEach(ClockFace.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                Section {
                    HStack(spacing: 14) {
                        ForEach(ClockTint.allCases) { option in
                            Button {
                                if option != .white, !app.plus.isActive { return showsPaywall = true }
                                tint = option
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if option == tint {
                                            Circle().stroke(.white, lineWidth: 3).padding(-5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(option.title))
                            .accessibilityAddTraits(option == tint ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                } header: {
                    HStack {
                        Text("Renk")
                        if !app.plus.isActive { PlusBadge() }
                    }
                } footer: {
                    Text("Gece Kırmızısı karanlıkta gözü en az yorar.")
                }
                Section {
                    Toggle("Saniyeleri Göster", isOn: $showsSeconds)
                } footer: {
                    Text("Kapatınca ekran daha az yenilenir ve pil daha uzun gider.")
                }
            }
            .navigationTitle("Odak Modu")
            .onChange(of: face) { old, new in
                guard new != .digital, !app.plus.isActive else { return }
                face = old
                showsPaywall = true
            }
            .plusPaywall(isPresented: $showsPaywall)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
