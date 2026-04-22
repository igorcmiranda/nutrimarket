import SwiftUI
import WebKit

struct StripeWebView: View {
    let url: URL
    let plan: SubscriptionPlan
    let onSuccess: (SubscriptionPlan, String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            StripeWebViewRepresentable(
                url: url,
                plan: plan,
                onSuccess: onSuccess
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Pagamento seguro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { onDismiss() }
                }
            }
        }
    }
}

struct StripeWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let plan: SubscriptionPlan
    let onSuccess: (SubscriptionPlan, String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "stripeHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(plan: plan, onSuccess: onSuccess)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let plan: SubscriptionPlan
        let onSuccess: (SubscriptionPlan, String) -> Void
        private var successDetected = false

        init(plan: SubscriptionPlan, onSuccess: @escaping (SubscriptionPlan, String) -> Void) {
            self.plan = plan
            self.onSuccess = onSuccess
        }

        // Chamado quando o WebView termina de carregar qualquer página
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let currentURL = webView.url?.absoluteString ?? ""
            // // print("✅ Stripe página carregada: \(currentURL)")

            checkForSuccess(url: currentURL, webView: webView)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let urlString = navigationAction.request.url?.absoluteString ?? ""
            // // print("🔗 Stripe navegando para: \(urlString)")
            checkForSuccess(url: urlString, webView: nil)
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            let urlString = navigationResponse.response.url?.absoluteString ?? ""
            // // print("📄 Stripe resposta de: \(urlString)")
            checkForSuccess(url: urlString, webView: nil)
            decisionHandler(.allow)
        }

        func checkForSuccess(url: String, webView: WKWebView?) {
            guard !successDetected else { return }

            let successIndicators = [
                "success",
                "confirmation",
                "thank-you",
                "thankyou",
                "order-confirmed",
                "payment-success",
                "checkout/success",
                "obrigado",
                "complete"
            ]

            let urlLower = url.lowercased()
            if successIndicators.contains(where: { urlLower.contains($0) }) {
                successDetected = true
                // // print("🎉 Sucesso detectado na URL: \(url)")
                let sessionID = extractSessionID(from: url) ?? UUID().uuidString
                DispatchQueue.main.async {
                    self.onSuccess(self.plan, sessionID)
                }
                return
            }

            // Verifica o título da página para detectar sucesso
            webView?.evaluateJavaScript("document.title") { result, _ in
                if let title = result as? String {
                    // // print("📋 Título da página: \(title)")
                    let titleLower = title.lowercased()
                    let titleSuccessIndicators = ["success", "confirmed", "thank", "obrigado", "confirmado", "aprovado"]
                    if titleSuccessIndicators.contains(where: { titleLower.contains($0) }) && !self.successDetected {
                        self.successDetected = true
                        // // print("🎉 Sucesso detectado no título: \(title)")
                        DispatchQueue.main.async {
                            self.onSuccess(self.plan, UUID().uuidString)
                        }
                    }
                }
            }

            // Verifica o conteúdo da página
            webView?.evaluateJavaScript("document.body.innerText") { result, _ in
                if let text = result as? String {
                    let textLower = text.lowercased()
                    let contentSuccessIndicators = [
                        "payment successful",
                        "pagamento aprovado",
                        "assinatura confirmada",
                        "subscription confirmed",
                        "your subscription",
                        "you're subscribed",
                        "thank you for subscribing"
                    ]
                    if contentSuccessIndicators.contains(where: { textLower.contains($0) }) && !self.successDetected {
                        self.successDetected = true
                        // // print("🎉 Sucesso detectado no conteúdo da página")
                        DispatchQueue.main.async {
                            self.onSuccess(self.plan, UUID().uuidString)
                        }
                    }
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            // // print("📨 Mensagem JS: \(message.body)")
        }

        func extractSessionID(from url: String) -> String? {
            guard let components = URLComponents(string: url) else { return nil }
            return components.queryItems?.first(where: {
                $0.name == "session_id" || $0.name == "payment_intent" || $0.name == "subscription_id"
            })?.value
        }
    }
}
