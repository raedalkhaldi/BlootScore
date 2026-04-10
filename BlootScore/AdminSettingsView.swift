import SwiftUI
import UniformTypeIdentifiers

struct AdminSettingsView: View {
    @StateObject private var store = VoiceStore.shared
    @StateObject private var fb = FirebaseREST.shared
    @StateObject private var recorder = VoiceRecorder()

    @State private var activeRecordKey: String? = nil
    @State private var pickingForKey: String? = nil
    @State private var showPicker = false
    @State private var busyKey: String? = nil
    @State private var errorMsg: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if !fb.isReady {
                    loading("جارٍ الاتصال بالخدمة...")
                } else if store.isLoading && store.clips.isEmpty {
                    loading("جارٍ تحميل الإعدادات...")
                } else if store.adminNotClaimed {
                    claimAdminView
                } else if !store.isAdmin {
                    notAdminView
                } else {
                    adminList
                }
            }
            .navigationTitle("إدارة الأصوات")
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
            .sheet(isPresented: $showPicker) {
                DocPicker(types: [UTType.audio]) { url in
                    if let key = pickingForKey,
                       let state = VoiceState(rawValue: keyToRaw(key)) {
                        Task { await upload(state: state, url: url) }
                    }
                    pickingForKey = nil
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: Subviews
    private func loading(_ msg: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(msg).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var claimAdminView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("لم يتم تعيين أدمن بعد")
                .font(.title2).bold()
            Text("اضغط على الزر للمطالبة بحقوق الأدمن لهذا الجهاز.\nلن يستطيع أحد آخر التعديل بعدها.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Button {
                Task {
                    do { try await store.claimAdmin() }
                    catch { errorMsg = "فشل تسجيل الأدمن: \(error.localizedDescription)" }
                }
            } label: {
                Text("تعيين هذا الجهاز كأدمن")
                    .bold()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notAdminView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 60)).foregroundColor(.secondary)
            Text("هذه الشاشة للأدمن فقط").font(.title2).bold()
            Text("UID الخاص بك:\n\(fb.uid ?? "—")")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var adminList: some View {
        List {
            ForEach(VoiceState.allCases) { state in
                row(for: state)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(for state: VoiceState) -> some View {
        let clip = store.clips[state.key] ?? VoiceClip(enabled: true, hasAudio: false, updatedAt: nil)
        let isRecordingThis = recorder.isRecording && activeRecordKey == state.key
        let isBusy = busyKey == state.key

        return VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Toggle(isOn: Binding(
                    get: { clip.enabled },
                    set: { newVal in Task { await toggle(state, newVal) } }
                )) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(state.title).font(.headline)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(clip.hasAudio ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                            Text(clip.hasAudio ? "صوت مرفوع" : "لا يوجد صوت")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                // Record
                Button {
                    if isRecordingThis {
                        if let url = recorder.stop() {
                            Task { await upload(state: state, url: url) }
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

                // Upload from files
                Button {
                    pickingForKey = state.key
                    showPicker = true
                } label: {
                    Label("ملف", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy || recorder.isRecording)

                // Play
                Button {
                    store.play(state)
                } label: {
                    Image(systemName: "play.circle.fill").font(.title3)
                }
                .disabled(!clip.hasAudio || isBusy)

                // Delete
                Button(role: .destructive) {
                    Task { await deleteClip(state) }
                } label: {
                    Image(systemName: "trash").font(.subheadline)
                }
                .disabled(!clip.hasAudio || isBusy)

                if isBusy { ProgressView().scaleEffect(0.8) }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: Actions
    private func toggle(_ state: VoiceState, _ on: Bool) async {
        busyKey = state.key
        defer { busyKey = nil }
        do { try await store.setEnabled(state, on) }
        catch { errorMsg = error.localizedDescription }
    }

    private func upload(state: VoiceState, url: URL) async {
        busyKey = state.key
        defer { busyKey = nil }
        do { try await store.uploadVoice(state, fileURL: url) }
        catch { errorMsg = error.localizedDescription }
    }

    private func deleteClip(_ state: VoiceState) async {
        busyKey = state.key
        defer { busyKey = nil }
        do { try await store.deleteVoice(state) }
        catch { errorMsg = error.localizedDescription }
    }

    private func keyToRaw(_ key: String) -> String {
        // Our enum raw values differ from keys; look up by key
        VoiceState.allCases.first(where: { $0.key == key })?.rawValue ?? key
    }
}

// MARK: - Document Picker wrapper
import UIKit
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
