import AppKit
import PliSystem

/// Developer tools: the angle simulator, and sleep and wake without closing the lid.
/// Shown with `PLI_LID_SIMULATOR=1` (simulated lid) or `PLI_DEBUG=1` (real lid).
@MainActor
final class DebugMenu: NSObject, NSMenuDelegate {
    let menu = NSMenu(title: "Debug")
    private unowned let model: AppModel
    private let simulator: SimulatedLidSensor?
    private let slider = NSSlider(value: 110, minValue: 0, maxValue: 135, target: nil, action: nil)
    private let angleLabel = NSTextField(labelWithString: "")

    init(model: AppModel, simulator: SimulatedLidSensor?) {
        self.model = model
        self.simulator = simulator
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let simulator {
            menu.addItem(header("Simulated Lid"))
            menu.addItem(sliderItem(angle: simulator.currentAngle))
            for (index, script) in LidScript.library.enumerated() {
                let item = NSMenuItem(title: script.name, action: #selector(play(_:)), keyEquivalent: "")
                item.tag = index
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(.separator())
            menu.addItem(action("Sleep, Then Wake Locked", #selector(sleepThenWakeLocked)))
            menu.addItem(action("Sleep, Then Wake Unlocked", #selector(sleepThenWakeUnlocked)))
            menu.addItem(.separator())
        }
        menu.addItem(action("Test Capture", #selector(testCapture)))
        if let report = model.lastCaptureReport {
            let item = NSMenuItem(title: report, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    private func sliderItem(angle: Double) -> NSMenuItem {
        slider.doubleValue = angle
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved(_:))
        slider.frame = NSRect(x: 18, y: 6, width: 170, height: 20)
        angleLabel.stringValue = "\(Int(angle.rounded()))°"
        angleLabel.frame = NSRect(x: 194, y: 6, width: 44, height: 20)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 246, height: 32))
        container.addSubview(slider)
        container.addSubview(angleLabel)
        let item = NSMenuItem()
        item.view = container
        return item
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        simulator?.set(angle: sender.doubleValue)
        angleLabel.stringValue = "\(Int(sender.doubleValue.rounded()))°"
    }

    @objc private func play(_ sender: NSMenuItem) {
        guard LidScript.library.indices.contains(sender.tag) else { return }
        simulator?.play(LidScript.library[sender.tag])
    }

    @objc private func sleepThenWakeLocked() { model.simulateSleepAndWake(locked: true) }
    @objc private func sleepThenWakeUnlocked() { model.simulateSleepAndWake(locked: false) }
    @objc private func testCapture() { model.testCapture() }
}
