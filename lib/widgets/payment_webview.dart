import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final Function(String) onPaymentResult;
  final String planType;

  const PaymentWebView({
    Key? key,
    required this.paymentUrl,
    required this.onPaymentResult,
    required this.planType,
  }) : super(key: key);

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('🌐 Iniciando WebView para pago: ${widget.planType}');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('📄 Página iniciada: $url');
            _checkPaymentResult(url);
          },
          onPageFinished: (String url) {
            print('✅ Página cargada: $url');
            setState(() {
              _isLoading = false;
            });
            _checkPaymentResult(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🔄 Navegación solicitada: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentResult(String url) {
    print('🔍 Verificando URL: $url');
    
    // ✅ MEJORAR: Detección más robusta de URLs
    if (url.contains('/success') || url.contains('collection_status=approved')) {
      print('✅ Pago exitoso detectado');
      widget.onPaymentResult('success');
      Navigator.of(context).pop();
    } else if (url.contains('/failure') || url.contains('collection_status=rejected')) {
      print('❌ Pago fallido detectado');
      widget.onPaymentResult('failure');
      Navigator.of(context).pop();
    } else if (url.contains('/pending') || url.contains('collection_status=pending')) {
      print('⏳ Pago pendiente detectado');
      widget.onPaymentResult('pending');
      Navigator.of(context).pop();
    }
    // Agregar más patrones según sea necesario
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pago ${widget.planType == 'monthly' ? 'Mensual' : 'Anual'}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            print('❌ Usuario canceló el pago');
            widget.onPaymentResult('cancelled');
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando pasarela de pago...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}