import SwiftUI
import UIKit

/// View and manually correct the estimated measurements. Saving PATCHes the
/// avatar so the 3D preview updates to match.
struct MeasurementsView: View {
    @EnvironmentObject var session: AuthStore
    @State private var avatar: AvatarDTO?
    @State private var loading = true
    @State private var saving = false
    @State private var fields = Fields()
    @State private var saved = false

    struct Fields {
        var height = ""; var chest = ""; var waist = ""; var hip = ""; var inseam = ""
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else if avatar == nil {
                Text("No avatar yet — run a scan first.")
                    .foregroundStyle(.white.opacity(0.7)).padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Estimated from your scan, shown in \(Units.system.suffix). Tweak any value and save — your 3D avatar updates to match.")
                            .font(.footnote).foregroundStyle(.white.opacity(0.7))
                        group {
                            row("Height", unit: Units.system.suffix, text: $fields.height)
                            row("Chest", unit: Units.system.suffix, text: $fields.chest)
                            row("Waist", unit: Units.system.suffix, text: $fields.waist)
                            row("Hip", unit: Units.system.suffix, text: $fields.hip)
                            row("Inseam", unit: Units.system.suffix, text: $fields.inseam)
                        }
                        Button {
                            Task { await save() }
                        } label: {
                            if saving { ProgressView().tint(.white) }
                            else { Text(saved ? "Saved ✓" : "Save measurements") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12) { content() }.card()
    }

    private func row(_ label: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.white)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .foregroundStyle(.white)
            Text(unit).foregroundStyle(.white.opacity(0.5)).frame(width: 28, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func fmt(_ v: Double?) -> String { v == nil ? "" : Units.value(cm: v) }

    private func load() async {
        loading = true
        avatar = (try? await session.api.avatars())?.first
        if let m = avatar?.measurements {
            fields = Fields(height: fmt(m.heightCm), chest: fmt(m.chestCm),
                            waist: fmt(m.waistCm), hip: fmt(m.hipCm), inseam: fmt(m.inseamCm))
        }
        loading = false
    }

    private func save() async {
        guard let id = avatar?.id else { return }
        saving = true; saved = false; defer { saving = false }
        let patch = MeasurementPatch(
            heightCm: Units.toCm(fields.height), chestCm: Units.toCm(fields.chest),
            waistCm: Units.toCm(fields.waist), hipCm: Units.toCm(fields.hip),
            inseamCm: Units.toCm(fields.inseam))
        if let updated = try? await session.api.patchMeasurements(avatarId: id, patch) {
            avatar = updated
            saved = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
