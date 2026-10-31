import SwiftUI
import SwiftData
import QuickLook

/// Doctor PDF report (Pro): pick a period, optionally a name, preview and share.
struct ReportView: View {
    @Environment(PurchaseService.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Attack.start) private var attacks: [Attack]

    @State private var period = StatsPeriod.quarter
    @AppStorage("reportName") private var name = ""
    @State private var pdf: URL?
    @State private var showingPaywall = false

    private var selected: [Attack] {
        guard let interval = period.interval(now: Date()) else { return attacks }
        let now = Date()
        return attacks.filter { $0.value.interval(now: now).intersects(interval) || interval.contains($0.start) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SegmentedChips(options: StatsPeriod.allCases, selection: $period) { $0.rawValue }
                    LabeledContent("Attacks in this period", value: "\(selected.count)")
                } footer: {
                    Text("Your doctor gets headache and migraine days, medication days, suspected triggers, how each medicine worked, and a table of every attack. Neurologists usually ask for the last 3 months.")
                }
                Section {
                    TextField("Your name (optional)", text: $name)
                        .textContentType(.name)
                } footer: {
                    Text("Shown at the top of the report.")
                }
            }
            .navigationTitle("Doctor Report")
            .scrollContentBackground(.hidden)
            .background(AppColors.bgApp)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: create) {
                    HStack(spacing: 8) {
                        Text("Create PDF Report")
                        if !purchases.isPro { Image(systemName: "lock.fill") }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected.isEmpty)
                .padding()
                .background(.bar)
            }
            .quickLookPreview($pdf)
            .sheet(isPresented: $showingPaywall) { PaywallView(source: "report") }
        }
    }

    private func create() {
        guard !ProFeature.isLocked(.pdfReport, isPro: purchases.isPro) else {
            showingPaywall = true
            return
        }
        Analytics.track(.reportCreated, ["range": period.rawValue])
        pdf = PDFGenerator.generate(attacks: selected.map { ReportAttack($0) }, interval: period.interval(now: Date()), patientName: name)
    }
}
