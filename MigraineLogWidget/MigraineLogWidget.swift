import WidgetKit
import SwiftUI

struct DiaryEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// The app reloads timelines whenever the diary changes. Between those, one
/// entry per midnight keeps "days headache-free" counting up on its own.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DiaryEntry {
        DiaryEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DiaryEntry) -> Void) {
        completion(DiaryEntry(date: Date(), snapshot: context.isPreview ? (WidgetSnapshot.load() ?? .sample) : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiaryEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = [DiaryEntry(date: Date(), snapshot: snapshot)] + midnights.map { DiaryEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// Days headache-free (or the attack in progress) at a glance; any tap opens the log form.
struct MigraineLogWidget: Widget {
    let kind = "MigraineLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
                .widgetURL(WidgetSnapshot.logURL)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Migraine Log")
        .description("Days headache-free and this month's headache days. Tap to log a headache.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct WidgetView: View {
    let entry: DiaryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            status
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                header
                Spacer(minLength: 0)
                status
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                if let s = entry.snapshot {
                    Text("This month").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(s.monthDays(on: entry.date))").font(.system(size: 30, weight: .light)).privacySensitive()
                        Text("headache days").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Label(entry.snapshot?.ongoingSince == nil ? "Log Headache" : "Update", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(light: 0x146B66, dark: 0x13756F)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
            Text("Migraine Log")
            Spacer(minLength: 0)
            Image(systemName: "plus.circle.fill").font(.title3)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(Color.brand)
    }

    @ViewBuilder
    private var status: some View {
        if let s = entry.snapshot, let since = s.ongoingSince {
            VStack(alignment: .leading, spacing: 2) {
                Text("Headache since").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(since, style: .time).font(.system(size: 28, weight: .light)).privacySensitive()
                Text(since, style: .relative).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        } else if let s = entry.snapshot, let days = s.headacheFreeDays(on: entry.date) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(days)").font(.system(size: 44, weight: .ultraLight)).privacySensitive()
                Text(days == 1 ? "day headache-free" : "days headache-free")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing logged yet").font(.headline)
                Text("Tap to log a headache").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Lock Screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Migraine Log", systemImage: "brain.head.profile").font(.caption2.weight(.semibold))
            if let s = entry.snapshot, let since = s.ongoingSince {
                Text("Headache since").font(.caption2)
                Text(since, style: .time).font(.system(size: 20, weight: .semibold)).privacySensitive()
            } else if let days = entry.snapshot?.headacheFreeDays(on: entry.date) {
                Text("\(days) \(days == 1 ? "day" : "days")").font(.system(size: 22, weight: .semibold)).privacySensitive()
                Text("headache-free").font(.caption2)
            } else {
                Text("Tap to log a headache").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.snapshot?.ongoingSince != nil {
                Image(systemName: "timer").font(.title3.weight(.semibold))
            } else if let days = entry.snapshot?.headacheFreeDays(on: entry.date) {
                VStack(spacing: -2) {
                    Text("\(days)").font(.system(size: 20, weight: .semibold)).privacySensitive()
                    Text("days").font(.system(size: 9, weight: .medium))
                }
            } else {
                Image(systemName: "plus").font(.title2.weight(.bold))
            }
        }
    }
}

@main
struct MigraineLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        MigraineLogWidget()
    }
}
