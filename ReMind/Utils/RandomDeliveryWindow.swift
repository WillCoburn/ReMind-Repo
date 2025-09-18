// ==========================
// File: Utils/RandomDeliveryWindow.swift
// ==========================
import Foundation


struct RandomDeliveryWindow {
/// Returns a random Date between 9:00 and 24:00 on a given day.
static func randomTime(on day: Date, calendar: Calendar = .current) -> Date? {
var start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
var end = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)
guard let s = start, let e = end else { return nil }
let interval = e.timeIntervalSince(s)
let r = TimeInterval.random(in: 0...interval)
return s.addingTimeInterval(r)
}
}
