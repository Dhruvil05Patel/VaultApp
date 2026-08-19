import SwiftUI
import WebKit

struct PasswordChangeBrowserView: View {

    let item: VaultItem
    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) private var dismiss

    @State private var newPassword: String
    @State private var currentURL: URL? = nil
    @State private var isLoading: Bool = true
    @State private var target: PasswordChangeService.ChangePasswordTarget? = nil
    @State private var showConfirmUpdate: Bool = false
    @State private var overlayVisible: Bool = true

    init(item: VaultItem) {
        self.item = item
        // Pre-generate a strong password for the change
        self._newPassword = State(initialValue: PasswordGenerator.generate())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            browserNavBar

            Divider()

            ZStack(alignment: .bottom) {
                // Web view
                if let target {
                    WebViewRepresentable(
                        url: target.url,
                        isLoading: $isLoading,
                        currentURL: $currentURL
                    )
                } else {
                    loadingPlaceholder
                }

                // Floating password overlay
                if overlayVisible {
                    ChangePasswordOverlay(
                        item: item,
                        newPassword: $newPassword,
                        onConfirm: { showConfirmUpdate = true },
                        onDismiss: { overlayVisible = false }
                    )
                    .padding(.bottom, 12)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Show overlay again button when hidden
                if !overlayVisible {
                    Button {
                        withAnimation { overlayVisible = true }
                    } label: {
                        Label("Show Password Helper", systemImage: "chevron.up.circle.fill")
                            .font(.callout)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                }
            }
        }
        .frame(minWidth: 780, minHeight: 600)
        .animation(.easeInOut, value: overlayVisible)
        .task { await resolveTarget() }
        .confirmationDialog(
            "Update Saved Password?",
            isPresented: $showConfirmUpdate,
            titleVisibility: .visible
        ) {
            Button("Update Vault") {
                updateVaultItem()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save \"\(newPassword)\" as the new password for \(item.title)?")
        }
    }

    // MARK: - Nav Bar

    @ViewBuilder
    private var browserNavBar: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView().controlSize(.small).frame(width: 16)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Text(currentURL?.host ?? target?.url.host ?? "Loading…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button("Done") { dismiss() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Finding change-password page…")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Logic

    private func resolveTarget() async {
        target = await PasswordChangeService.resolveTarget(for: item)
        if target == nil {
            // No URL on item — can't navigate
        }
    }

    private func updateVaultItem() {
        var updated = item
        updated.password = newPassword
        updated.lastPasswordChangedAt = Date()
        vaultManager.updateItem(updated)
    }
}

// MARK: - WKWebView Wrapper

struct WebViewRepresentable: NSViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool
    @Binding var currentURL: URL?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Enable JavaScript — required for modern web apps
        config.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        init(_ parent: WebViewRepresentable) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.currentURL = webView.url
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
