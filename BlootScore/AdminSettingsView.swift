import SwiftUI
import UniformTypeIdentifiers
import UIKit

// شاشة إعدادات الأصوات — متاحة لكل المستخدمين.
// - كل مستخدم يقدر يسجّل نسخته المحلية ويستعيد الافتراضي متى شاء.
// - الأدمن يقدر يفعّل "وضع الأدمن" ويرفع الصوت كافتراضي لكل المستخدمين.
struct AdminSettingsView: View {
    @StateObject private var store = VoiceStore.shared
    @StateObject private var fb = FirebaseREST.shared
    @StateObject private var recorder = VoiceRecorder()

    @State private var activeRecordKey: String? = nil
    @State private var pickingForKey: String? = nil
    @State private var showPicker = false
    @State private var busyKey: String? = nil
    @State private var errorMsg: String? = nil
    @State private var adminMode = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if !fb.isReady {
                    loading("جارٍ الاتصال...")
                } else if store.isLoading && store.defaults.isEmpty {
                    loading("جارٍ تحميل الإعدادات...")
                } else {
                    settingsList
                }
            }
            .navigationTitle("إعدادات الأصوات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { dismiss() }
                }
            }
            .task {
                if !fb.isReady { await fb.start() }
                await store.loadAll()
            }
            .alert("خطأ", isPresented: .constant(errorMsg != nil), actions: {
                Button("حسناً") { errorMsg = nil }
            }, message: {
                Text(errorMsg ?? "")
            })
            .onChange(of: recorder.errorMessage) { newVal in
                if let v = newVal, !v.isEmpty {
                    errorMsg = v
                    recorder.errorMessage = nil
                    activeRecordKey = nil
                }
            }
            .sheet(isPresented: $showPicker) {
                DocPicker(types: [UTType.audio]) { url in
                    if let key = pickingForKey,
                       let state = VoiceState.allCases.first(where: { $0.key == key }) {
                        Task { await saveUploaded(state: state, url: url) }
                    }
                    pickingForKey = nil
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: Views
    private func loading(_ msg: String) -> some View {
        VStack(spacing: 12) { ProgressView(); Text(msg).foregroundColor(.secondary) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsList: some View {
        List {
            if store.isAdmin {
                Section(header: Text("وضع الأدمن")) {
                    Toggle(isOn: $adminMode) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("تعديل الأصوات الافتراضية")
                                .font(.headline)
                            Text(adminMode
                                 ? "أي تسجيل جديد يُرفع كافتراضي لكل المستخدمين"
                                 : "التسجيل يُحفظ محلياً على هذا الجهاز فقط")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else if store.adminNotClaimed {
                Section {
                    Button {
                        Task {
                            do { try await store.claimAdmin() }
                            catch { errorMsg = "فشل تعيين الأدمن: \(error.localizedDescription)" }
                        }
                    } label: {
                        Label("تعيين هذا الجهاز كأدمن (أول مرة فقط)",
                              systemImage: "person.badge.key")
                    }
                }
            }

            Section(header: Text("الحالات"),
                    footer: Text("التسجيل الجديد يستبدل الصوت الافتراضي على جهازك فقط. استخدم \"استعادة الافتراضي\" للرجوع للصوت الأصلي.")) {
                ForEach(VoiceState.allCases) { state in
                    row(for: state)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(for state: VoiceState) -> some View {
        let source = store.source(state)
        let enabled = store.effectiveEnabled(state)
        let isRecordingThis = recorder.isRecording && activeRecordKey == state.key
        let isBusy = busyKey == state.key
        let hasLocal = store.hasLocalOverride(state)

        return VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Toggle(isOn: Binding(
                    get: { enabled },
                    set: { newVal in Task { await toggle(state, newVal) } }
                )) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(state.title).font(.headline)
                        sourceBadge(source)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    if isRecordingThis {
                        if let url = recorder.stop() {
                            Task { await saveRecorded(state: state, url: url) }
                        }
                        activeRecordKey = nil
                    } else {
                        activeRecordKey = state.key
                        recorder.start()
                    }
                } label: {
                    Label(isRecordingThis ? "إيقاف" : "تسجيل",
                          systemImage: isRecordingThis ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(isRecordingThis ? .red : .blue)
                .disabled(isBusy || (recorder.isRecording && !isRecordingThis))

                Button {
                    pickingForKey = state.key
                    showPicker = true
                } label: {
                    Label("ملف", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy || recorder.isRecording)

                Button {
                    store.play(state)
                } label: {
                    Image(systemName: "play.circle.fill").font(.title3)
                }
                .disabled(source == .none || isBusy)

                if hasLocal {
                    Button {
                        store.restoreDefault(state)
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                    .disabled(isBusy)
                }

                if isBusy { ProgressView().scaleEffect(0.8) }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func sourceBadge(_ source: VoiceSource) -> some View {
        HStack(spacing: 4) {
            switch source {
            case .custom:
                Circle().fill(Color.blue).frame(width: 8, height: 8)
                Text("مخصّص (محلي)").font(.caption).foregroundColor(.blue)
            case .defaultAdmin:
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("الافتراضي").font(.caption).foregroundColor(.secondary)
            case .none:
                Circle().fill(Color.gray.opacity(0.4)).frame(width: 8, height: 8)
                Text("لا يوجد صوت").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: Actions
    private func toggle(_ state: VoiceState, _ on: Bool) async {
        if adminMode && store.isAdmin {
            busyKey = state.key
            defer { busyKey = nil }
            do { try await store.setDefaultEnabled(state, on) }
            catch { errorMsg = error.localizedDescription }
        } else {
            store.setLocalEnabled(state, on)
        }
    }

    private func saveRecorded(state: VoiceState, url: URL) async {
        busyKey = state.key
        defer { busyKey = nil }
        do {
            if adminMode && store.isAdmin {
                try await store.uploadAsDefault(state, fileURL: url)
                try store.saveLocalOverride(state, from: url) // الأدمن يشوف نسخته محلياً بعد
            } else {
                try store.saveLocalOverride(state, from: url)
            }
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func saveUploaded(state: VoiceState, url: URL) async {
        busyKey = state.key
        defer { busyKey = nil }
        do {
            if adminMode && store.isAdmin {
                try await store.uploadAsDefault(state, fileURL: url)
            }
            try store.saveLocalOverride(state, from: url)
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

// MARK: - Document Picker wrapper
struct DocPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coord { Coord(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        p.delegate = context.coordinator
        p.allowsMultipleSelection = false
        return p
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coord: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let u = urls.first { onPick(u) }
        }
    }
}
