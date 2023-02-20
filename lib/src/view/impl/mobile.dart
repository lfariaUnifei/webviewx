import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webviewx/src/controller/impl/mobile.dart';
import 'package:webviewx/src/controller/interface.dart' as ctrl_interface;
import 'package:webviewx/src/utils/utils.dart';
import 'package:webviewx/src/view/interface.dart' as view_interface;

/// Mobile implementation
class WebViewX extends StatefulWidget implements view_interface.WebViewX {
  /// Initial content
  @override
  final String initialContent;

  /// Initial source type. Must match [initialContent]'s type.
  ///
  /// Example:
  /// If you set [initialContent] to '<p>hi</p>', then you should
  /// also set the [initialSourceType] accordingly, that is [SourceType.html].
  @override
  final SourceType initialSourceType;

  /// User-agent
  /// On web, this is only used when using [SourceType.urlBypass]
  @override
  final String? userAgent;

  /// Widget width
  @override
  final double width;

  /// Widget height
  @override
  final double height;

  /// Callback which returns a reference to the [WebViewXController]
  /// being created.
  @override
  final Function(ctrl_interface.WebViewXController controller)?
      onWebViewCreated;

  /// A set of [EmbeddedJsContent].
  ///
  /// You can define JS functions, which will be embedded into
  /// the HTML source (won't do anything on URL) and you can later call them
  /// using the controller.
  ///
  /// For more info, see [EmbeddedJsContent].
  @override
  final Set<EmbeddedJsContent> jsContent;

  /// A set of [DartCallback].
  ///
  /// You can define Dart functions, which can be called from the JS side.
  ///
  /// For more info, see [DartCallback].
  @override
  final Set<DartCallback> dartCallBacks;

  /// Boolean value to specify if should ignore all gestures that touch the webview.
  ///
  /// You can change this later from the controller.
  @override
  final bool ignoreAllGestures;

  /// Boolean value to specify if Javascript execution should be allowed inside the webview
  @override
  final JavascriptMode javascriptMode;

  /// This defines if media content(audio - video) should
  /// auto play when entering the page.
  @override
  final AutoMediaPlaybackPolicy initialMediaPlaybackPolicy;

  /// Callback for when the page starts loading.
  @override
  final void Function(String src)? onPageStarted;

  /// Callback for when the page has finished loading (i.e. is shown on screen).
  @override
  final void Function(String src)? onPageFinished;

  /// Callback to decide whether to allow navigation to the incoming url
  @override
  final NavigationDelegate? navigationDelegate;

  /// Callback for when something goes wrong in while page or resources load.
  @override
  final void Function(WebResourceError error)? onWebResourceError;

  /// Parameters specific to the web version.
  /// This may eventually be merged with [mobileSpecificParams],
  /// if all features become cross platform.
  @override
  final WebSpecificParams webSpecificParams;

  /// Parameters specific to the web version.
  /// This may eventually be merged with [webSpecificParams],
  /// if all features become cross platform.
  @override
  final MobileSpecificParams mobileSpecificParams;

  /// Constructor
  const WebViewX({
    Key? key,
    this.initialContent = 'about:blank',
    this.initialSourceType = SourceType.url,
    this.userAgent,
    required this.width,
    required this.height,
    this.onWebViewCreated,
    this.jsContent = const {},
    this.dartCallBacks = const {},
    this.ignoreAllGestures = false,
    this.javascriptMode = JavascriptMode.unrestricted,
    this.initialMediaPlaybackPolicy =
        AutoMediaPlaybackPolicy.requireUserActionForAllMediaTypes,
    this.onPageStarted,
    this.onPageFinished,
    this.navigationDelegate,
    this.onWebResourceError,
    this.webSpecificParams = const WebSpecificParams(),
    this.mobileSpecificParams = const MobileSpecificParams(),
  }) : super(key: key);

  @override
  WebViewXState createState() => WebViewXState();
}

class WebViewXState extends State<WebViewX> {
  late wf.WebViewController originalWebViewController;
  late WebViewXController webViewXController;

  late bool _ignoreAllGestures;

  @override
  void initState() {
    super.initState();

    _ignoreAllGestures = widget.ignoreAllGestures;
    webViewXController = _createWebViewXController();
    originalWebViewController = _createOriginalController();
  }

  // Creates a WebViewXController and adds the listener
  WebViewXController _createWebViewXController() {
    return WebViewXController(
      initialContent: widget.initialContent,
      initialSourceType: widget.initialSourceType,
      ignoreAllGestures: _ignoreAllGestures,
    )
      ..addListener(_handleChange)
      ..addIgnoreGesturesListener(_handleIgnoreGesturesChange);
  }

  // Called when WebViewXController updates it's value
  void _handleChange() {
    final newModel = webViewXController.value;
    _reloadContent(newModel);
  }

  // Prepares the source depending if it is HTML or URL
  void _reloadContent(WebViewContent model) {
    if (model.sourceType == SourceType.html) {
      originalWebViewController.loadHtmlString(HtmlUtils.preprocessSource(
        model.source,
        jsContent: widget.jsContent,
        // Needed for mobile webview in order to URI-encode the HTML
        encodeHtml: false,
      ));
    }
    originalWebViewController.loadRequest(Uri.parse(model.source));
  }

  wf.WebViewController _createOriginalController() {
    // final initialMediaPlaybackPolicy = widget.initialMediaPlaybackPolicy ==
    //         AutoMediaPlaybackPolicy.alwaysAllow
    //     ? wf.AutoMediaPlaybackPolicy.always_allow
    //     : wf.AutoMediaPlaybackPolicy.require_user_action_for_all_media_types;

    final controller = wf.WebViewController();
    _loadContent(controller)
      ..setJavaScriptMode(
        widget.javascriptMode == JavascriptMode.unrestricted
            ? wf.JavaScriptMode.unrestricted
            : wf.JavaScriptMode.disabled,
      )
      ..setNavigationDelegate(
        wf.NavigationDelegate(
          onPageStarted: widget.onPageStarted,
          onPageFinished: widget.onPageFinished,
          onWebResourceError: onWebResourceError,
          onNavigationRequest: navigationRequest,
        ),
      )
      ..setUserAgent(widget.userAgent);
    for (final callback in widget.dartCallBacks) {
      controller.addJavaScriptChannel(
        callback.name,
        onMessageReceived: (msg) => callback.callBack(msg.message),
      );
    }

    return controller;
  }

  // Returns initial data
  wf.WebViewController _loadContent(wf.WebViewController controller) {
    if (widget.initialSourceType == SourceType.html) {
      return controller
        ..loadHtmlString(HtmlUtils.preprocessSource(
          widget.initialContent,
          jsContent: widget.jsContent,
          encodeHtml: false,
        ));
    }
    return controller..loadRequest(Uri.parse(widget.initialContent));
  }

  FutureOr<wf.NavigationDecision> navigationRequest(
    wf.NavigationRequest request,
  ) async {
    if (widget.navigationDelegate == null) {
      webViewXController.value =
          webViewXController.value.copyWith(source: request.url);
      return wf.NavigationDecision.navigate;
    }

    final delegate = await widget.navigationDelegate!.call(
      NavigationRequest(
        content:
            NavigationContent(request.url, webViewXController.value.sourceType),
        isForMainFrame: request.isMainFrame,
      ),
    );

    switch (delegate) {
      case NavigationDecision.navigate:
        // When clicking on an URL, the sourceType stays the same.
        // That's because you cannot move from URL to HTML just by clicking.
        // Also we don't take URL_BYPASS into consideration because it has no effect here in mobile
        webViewXController.value = webViewXController.value.copyWith(
          source: request.url,
        );
        return wf.NavigationDecision.navigate;
      case NavigationDecision.prevent:
        return wf.NavigationDecision.prevent;
    }
  }

  void onWebResourceError(wf.WebResourceError err) {
    widget.onWebResourceError?.call(
      WebResourceError(
        description: err.description,
        errorCode: err.errorCode,
        domain: '',
        errorType: WebResourceErrorType.values.singleWhere(
          (value) => value.toString() == err.errorType.toString(),
        ),
        failingUrl: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    webViewXController.connector = originalWebViewController;
    if (widget.onWebViewCreated != null) {
      widget.onWebViewCreated!(webViewXController);
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: IgnorePointer(
        ignoring: _ignoreAllGestures,
        child: wf.WebViewWidget(
          key: widget.key,
          controller: originalWebViewController,
          gestureRecognizers:
              widget.mobileSpecificParams.mobileGestureRecognizers ?? {},
        ),
      ),
    );
  }

  // Called when the ValueNotifier inside WebViewXController updates it's value
  void _handleIgnoreGesturesChange() {
    setState(() {
      _ignoreAllGestures = webViewXController.ignoresAllGestures;
    });
  }

  @override
  void dispose() {
    webViewXController.removeListener(_handleChange);
    webViewXController.removeIgnoreGesturesListener(
      _handleIgnoreGesturesChange,
    );
    super.dispose();
  }
}
