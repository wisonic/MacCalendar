//
//  AppDelegate.swift
//  MacCalendar
//
//  Created by ruihelin on 2025/9/28.
//

import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject,NSApplicationDelegate, NSWindowDelegate {
    static var shared:AppDelegate?
    
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsWindow: NSWindow?
    var eventEditWindow:NSWindow?
    var calendarManager = CalendarManager()
    
    private var resizeWorkItem:DispatchWorkItem?
    private var calendarIcon = CalendarIcon()
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusItemClicked)
            button.target = self
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.characters == "," {
                self?.showSettingsWindow()
                return nil
            }
            return event
        }
        
        calendarIcon.$displayOutput
            .receive(on: DispatchQueue.main)
            .sink { [weak self] output in
                guard let button = self?.statusItem.button else { return }
                
                if output == "" {
                    button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
                    button.title = ""
                } else {
                    // --- 核心修改：生成带框的数字图标 ---
                    let dayString = output // 这里的 output 应该是当前的日期数字
                    button.image = self?.createCalendarIcon(day: dayString)
                    button.title = "" // 清空文字，只显示图片
                }
            }
            .store(in: &cancellables)
        
        popover = NSPopover()
        popover.appearance = NSAppearance(named: .aqua)
        popover.behavior = .transient
        
        NotificationCenter.default.addObserver(self, selector: #selector(closePopover), name: NSApplication.didResignActiveNotification, object: nil)
    }
    
    @objc func statusItemClicked(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "设置", action: #selector(showSettingsWindow), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                calendarManager.resetToToday()
                
                let hostingController = FocusableHostingController(rootView: ContentView()
                    .environmentObject(calendarManager)
                    .onPreferenceChange(SizeKey.self){ size in
                        guard size != .zero else { return }
                        
                        self.resizeWorkItem?.cancel()
                        
                        let workItem = DispatchWorkItem{
                            // 防止 popover 已经关闭了
                            guard self.popover.isShown else { return }
                            self.popover.contentSize = size
                        }
                        
                        self.resizeWorkItem = workItem
                        // 延迟80ms执行
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
                    }
                )
                
                popover.contentViewController = hostingController
                
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.async {
                    self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
    
    @objc func closePopover() {
        popover.performClose(nil)
    }
    
    @objc func showSettingsWindow() {
        if settingsWindow == nil {
            let settingsView = SettingsView().environmentObject(calendarManager)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: settingsView)
            settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    func openEventEditWindow(event: CalendarEvent) {
        if let existingWindow = eventEditWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = EventEditView(event: event).environmentObject(calendarManager)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.delegate = self
        window.title = "编辑事件"
        window.center()
        window.isReleasedWhenClosed = false
        
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        
        self.eventEditWindow = window
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == settingsWindow {
                settingsWindow = nil
            }
            if window == eventEditWindow {
                eventEditWindow = nil
            }
        }
    }
    
    func createCalendarIcon(day: String) -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 1. 基础配置
        let iconColor = NSColor.labelColor
        iconColor.set()
        
        // 稍微调整 rect 宽度为 17.5，让图标在状态栏显得更饱满一点
        let rect = NSRect(x: 1.25, y: 2, width: 17.5, height: 16)
        let cornerRadius: CGFloat = 2.5
        
        // 2. 绘制并填充上方页眉 (高度调整为 3.5)
        let headerHeight: CGFloat = 3.5
        let headerRect = NSRect(x: rect.origin.x,
                                y: rect.origin.y + rect.size.height - headerHeight,
                                width: rect.size.width,
                                height: headerHeight)
        
        let fullPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        NSGraphicsContext.current?.saveGraphicsState()
        let clipPath = NSBezierPath(rect: headerRect)
        clipPath.addClip()
        fullPath.fill() // 填充页眉块
        
        // --- 镂空圆点 (铰链) ---
        // 因页眉变窄，圆点直径由 1.8 缩小至 1.4 以防过于局促
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let dotSize: CGFloat = 1.4
        let dotY = headerRect.origin.y + (headerRect.size.height - dotSize) / 2
        
        // 左侧圆点
        let leftDotRect = NSRect(x: rect.origin.x + 4, y: dotY, width: dotSize, height: dotSize)
        NSBezierPath(ovalIn: leftDotRect).fill()
        
        // 右侧圆点
        let rightDotRect = NSRect(x: rect.origin.x + rect.size.width - 4 - dotSize, y: dotY, width: dotSize, height: dotSize)
        NSBezierPath(ovalIn: rightDotRect).fill()
        
        NSGraphicsContext.current?.restoreGraphicsState()
        
        // 3. 绘制整体外框线
        iconColor.set()
        fullPath.lineWidth = 1.1 // 线条稍微细一点，更精致
        fullPath.stroke()
        
        // 4. 绘制中间横隔线
        let linePath = NSBezierPath()
        let lineY = rect.origin.y + rect.size.height - headerHeight
        linePath.move(to: NSPoint(x: rect.origin.x, y: lineY))
        linePath.line(to: NSPoint(x: rect.origin.x + rect.size.width, y: lineY))
        linePath.lineWidth = 0.8 // 隔线稍微淡一点
        linePath.stroke()
        
        // 5. 绘制日期数字
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: iconColor
        ]
        
        let stringSize = day.size(withAttributes: attributes)
        // 重新计算下方剩余空间的居中位置
        let bodyHeight = rect.size.height - headerHeight
        let stringY = rect.origin.y + (bodyHeight - stringSize.height) / 2 - 0.2 // 微调偏移
        
        let stringRect = NSRect(
            x: rect.origin.x + (rect.size.width - stringSize.width) / 2,
            y: stringY,
            width: stringSize.width,
            height: stringSize.height
        )
        
        day.draw(in: stringRect, withAttributes: attributes)
        
        image.unlockFocus()
        image.isTemplate = true
        
        return image
    }
}
