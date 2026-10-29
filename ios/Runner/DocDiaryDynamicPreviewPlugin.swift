import Flutter
import UIKit
import WebKit

/// iOS rendering/export bridge for the unchanged native prescription HTML.
final class DocDiaryDynamicPreviewPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(DynamicPreviewFactory(messenger: registrar.messenger()),
                       withId: "docdiary/dynamic_preview")
  }
}

private final class DynamicPreviewFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    if #available(iOS 14.0, *) {
      return DynamicPreviewView(frame: frame, id: viewId, messenger: messenger)
    }
    return UnavailablePreviewView(frame: frame, id: viewId, messenger: messenger)
  }
}

private final class UnavailablePreviewView: NSObject, FlutterPlatformView {
  let surface: UIView
  let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
    surface = UIView(frame: frame)
    channel = FlutterMethodChannel(name: "docdiary/dynamic_preview/\(id)", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { _, result in
      result(FlutterError(code: "unsupported", message: "Prescription preview requires iOS 14 or later.", details: nil))
    }
  }
  func view() -> UIView { surface }
  deinit { channel.setMethodCallHandler(nil) }
}

private final class DynamicPreviewContainer: UIView {
  weak var webView: WKWebView?
  var onResize: (() -> Void)?
  private var previousWidth: CGFloat = 0
  override func layoutSubviews() {
    super.layoutSubviews()
    webView?.frame = bounds
    if bounds.width > 0 && previousWidth != bounds.width {
      previousWidth = bounds.width
      onResize?()
    }
  }
}

@available(iOS 14.0, *)
private final class DynamicPreviewView: NSObject, FlutterPlatformView, WKNavigationDelegate,
  UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate, UIPrintInteractionControllerDelegate {
  private let surface: DynamicPreviewContainer
  private let web: WKWebView
  private let channel: FlutterMethodChannel
  private var pdfWeb: WKWebView?
  private var html = ""
  private var documentName = "Prescription"
  private var layout: [String: Any]?
  private var pdfURL: URL?
  private var pending: FlutterResult?
  private var deadline: Timer?
  private var modal: UIViewController?
  private var printing: UIPrintInteractionController?
  private var disposed = false
  private var ready = false
  private var generation = 0
  private var fitted = false
  private let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("docdiary_rx_" + UUID().uuidString, isDirectory: true)

  // WebKit content blockers do not support regex alternation (the | operator).
  // Keep one literal prefix per rule. Inline data: logos and about:blank remain
  // available to the generated HTML. Preview and PDF use this same rule list.
  private static let offlineRuleListIdentifier = "DocDiaryPreviewOfflineV2"
  private static let offlineRulesJSON = #"""
  [
    {"trigger":{"url-filter":"^http:"},"action":{"type":"block"}},
    {"trigger":{"url-filter":"^https:"},"action":{"type":"block"}},
    {"trigger":{"url-filter":"^ftp:"},"action":{"type":"block"}},
    {"trigger":{"url-filter":"^file:"},"action":{"type":"block"}}
  ]
  """#

  private static func setupFailure(_ phase: String, error: Error?) -> String {
    guard let error = error else { return "\(phase). Please retry." }
    let diagnostic = error as NSError
    return "\(phase). Please retry. Error: \(diagnostic.domain)/\(diagnostic.code)."
  }

  private static func configuration() -> WKWebViewConfiguration {
    let value = WKWebViewConfiguration()
    value.websiteDataStore = .nonPersistent()
    value.defaultWebpagePreferences.allowsContentJavaScript = false
    value.defaultWebpagePreferences.preferredContentMode = .desktop
    value.preferences.javaScriptCanOpenWindowsAutomatically = false
    value.ignoresViewportScaleLimits = true
    return value
  }

  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
    surface = DynamicPreviewContainer(frame: frame)
    web = WKWebView(frame: surface.bounds, configuration: Self.configuration())
    channel = FlutterMethodChannel(name: "docdiary/dynamic_preview/\(id)", binaryMessenger: messenger)
    super.init()
    surface.backgroundColor = UIColor(red: 238/255, green: 242/255, blue: 245/255, alpha: 1)
    surface.clipsToBounds = true
    surface.webView = web
    surface.addSubview(web)
    web.navigationDelegate = self
    web.isOpaque = false
    web.backgroundColor = surface.backgroundColor
    web.scrollView.backgroundColor = surface.backgroundColor
    web.scrollView.bounces = false
    web.scrollView.contentInsetAdjustmentBehavior = .never
    surface.onResize = { [weak self] in self?.fitToWidth() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let owner = self, !owner.disposed else {
        result(FlutterError(code: "cancelled", message: "Prescription preview was closed.", details: nil)); return
      }
      owner.handle(call, result)
    }
    NotificationCenter.default.addObserver(self, selector: #selector(background),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }

  func view() -> UIView { surface }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "load":
      guard let arguments = call.arguments as? [String: Any],
            let source = arguments["html"] as? String, !source.isEmpty else {
        result(FlutterError(code: "html", message: "Prescription HTML is empty.", details: nil)); return
      }
      cancelWork()
      html = source
      let name = (arguments["documentName"] as? String ?? "Prescription")
        .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
      documentName = name.isEmpty ? "Prescription" : String(name.prefix(150))
      ready = false
      fitted = false
      let token = generation
      // Generated HTML uses inline CSS and data: logos. Block all remote
      // resources as well as navigation; no patient data leaves this renderer.
      WKContentRuleListStore.default().compileContentRuleList(
        forIdentifier: Self.offlineRuleListIdentifier,
        encodedContentRuleList: Self.offlineRulesJSON
      ) { [weak self] rule, error in
        guard let owner = self, owner.active(token) else { return }
        guard let rule = rule, error == nil else {
          owner.channel.invokeMethod("error", arguments: Self.setupFailure("Prescription preview setup failed", error: error)); return
        }
        owner.web.configuration.userContentController.add(rule)
        owner.web.loadHTMLString(source, baseURL: nil)
      }
      result(nil)
    case "measure": measure(result)
    case "download", "print", "share": export(call.method, arguments: call.arguments, result: result)
    case "suspend": cancelWork(); result(nil)
    case "dispose": dispose(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func active(_ token: Int) -> Bool {
    !disposed && token == generation && UIApplication.shared.applicationState != .background
  }
  private func begin(_ result: @escaping FlutterResult) -> Bool {
    guard ready, !disposed, UIApplication.shared.applicationState != .background else {
      result(FlutterError(code: "ready", message: "Prescription preview is not ready.", details: nil)); return false
    }
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "Prescription PDF is being prepared.", details: nil)); return false
    }
    pending = result
    deadline = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
      self?.fail("Prescription PDF took too long to prepare. Please try again.")
    }
    return true
  }
  private func complete(_ value: Any?) {
    deadline?.invalidate(); deadline = nil
    let callback = pending; pending = nil
    callback?(value)
  }
  private func fail(_ message: String) {
    pdfWeb?.stopLoading(); pdfWeb?.removeFromSuperview(); pdfWeb = nil
    layout = nil
    complete(FlutterError(code: "pdf", message: message, details: nil))
  }

  private func fitToWidth() {
    guard ready, !disposed, surface.bounds.width > 0 else { return }
    let token = generation
    web.evaluateJavaScript("Math.max(document.documentElement.scrollWidth,document.body.scrollWidth)",
      in: nil, in: .defaultClient) { [weak self] response in
      guard let owner = self, owner.active(token), case .success(let value) = response,
            let width = value as? NSNumber, width.doubleValue > 0 else { return }
      let fit = min(1, owner.surface.bounds.width / CGFloat(width.doubleValue))
      owner.web.scrollView.minimumZoomScale = fit
      owner.web.scrollView.maximumZoomScale = max(3, fit * 6)
      owner.web.scrollView.setZoomScale(fit, animated: false)
      if !owner.fitted { owner.web.scrollView.setContentOffset(.zero, animated: false) }
      owner.fitted = true
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let url = navigationAction.request.url
    decisionHandler(navigationAction.navigationType == .other &&
      (url == nil || url?.absoluteString == "about:blank") ? .allow : .cancel)
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if webView === web {
      guard !disposed else { return }
      ready = true
      fitToWidth()
      channel.invokeMethod("ready", arguments: nil)
    } else if webView === pdfWeb {
      let token = generation
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
        guard let owner = self, owner.active(token), owner.pending != nil else { return }
        webView.evaluateJavaScript(Self.layoutScript, in: nil, in: .defaultClient) { response in
          guard owner.active(token), owner.pending != nil else { return }
          do {
            let value = try response.get()
            guard let text = value as? String, let bytes = text.data(using: .utf8),
                  let measured = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
              owner.fail("Prescription page information was not returned."); return
            }
            if let message = measured["error"] as? String { owner.fail(message); return }
            owner.layout = measured
            owner.complete(measured)
          } catch { owner.fail("Prescription page layout could not be prepared.") }
        }
      }
    }
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    renderFailed(webView, error: error)
  }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    renderFailed(webView, error: error)
  }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { renderFailed(webView) }
  private func renderFailed(_ view: WKWebView, error: Error? = nil) {
    guard !disposed else { return }
    if view === web {
      ready = false
      channel.invokeMethod("error", arguments: Self.setupFailure("Prescription layout could not be prepared", error: error))
    } else { fail(Self.setupFailure("Prescription PDF layout could not be prepared", error: error)) }
  }

  private func measure(_ result: @escaping FlutterResult) {
    if let value = layout, pending == nil, ready { result(value); return }
    guard begin(result) else { return }
    let token = generation
    let configuration = Self.configuration()
    // Reuse the same remote-resource block list as the visible renderer.
    WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: Self.offlineRuleListIdentifier) { [weak self] rule, error in
      guard let owner = self, owner.active(token), owner.pending != nil else { return }
      guard let rule = rule, error == nil else { owner.fail(Self.setupFailure("Prescription PDF setup failed", error: error)); return }
      configuration.userContentController.add(rule)
      let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 794, height: 1124), configuration: configuration)
      view.navigationDelegate = owner
      view.scrollView.isScrollEnabled = false
      view.scrollView.contentInsetAdjustmentBehavior = .never
      view.isOpaque = true
      view.backgroundColor = .white
      owner.pdfWeb = view
      // Attached below the visible renderer so WebKit can render off-screen.
      owner.surface.insertSubview(view, at: 0)
      let source = owner.html
      let printable: String
      if let position = source.range(of: "</head>", options: [.caseInsensitive, .backwards]) {
        printable = String(source[..<position.lowerBound]) + Self.printStyle + String(source[position.lowerBound...])
      } else { printable = Self.printStyle + source }
      view.loadHTMLString(printable, baseURL: nil)
    }
  }

  private func export(_ action: String, arguments: Any?, result: @escaping FlutterResult) {
    guard begin(result) else { return }
    guard let request = arguments as? [String: Any], let measured = layout,
          let legacyPages = request["pages"] as? [[String: Int]],
          let contentTop = (measured["contentTop"] as? NSNumber)?.doubleValue,
          let contentBottom = (measured["contentBottom"] as? NSNumber)?.doubleValue,
          let footerTop = (measured["footerTop"] as? NSNumber)?.doubleValue,
          let footerBottom = (measured["footerBottom"] as? NSNumber)?.doubleValue,
          let documentHeight = (request["documentHeight"] as? NSNumber)?.doubleValue,
          contentTop > 0, footerBottom > footerTop, documentHeight.isFinite, documentHeight <= 600000 else {
      fail("Prescription page layout is invalid."); return
    }
    var pages: [[PDFRegion]] = []
    let available = Int((842.0 * 794.0 / 595.0 - contentTop.rounded() - (footerBottom.rounded() - footerTop.rounded())).rounded(.down))
    if let columnPages = request["columnPages"] as? [[[String: Any]]] {
      for page in columnPages {
        var regions: [PDFRegion] = []
        for row in page {
          guard let left = (row["left"] as? NSNumber)?.doubleValue, let right = (row["right"] as? NSNumber)?.doubleValue,
                let start = row["start"] as? Int, let end = row["end"] as? Int, let destination = row["destination"] as? Int,
                left.isFinite, right.isFinite, left >= 0, right <= 794, right > left,
                start >= Int(contentTop.rounded()), end <= Int(contentBottom.rounded()), end > start,
                destination >= Int(contentTop.rounded()), destination-Int(contentTop.rounded())+end-start <= available else {
            fail("Prescription column layout is invalid."); return
          }
          regions.append(PDFRegion(left: CGFloat(left), right: CGFloat(right), start: start, end: end, destination: CGFloat(destination)))
        }
        guard !regions.isEmpty else { fail("Prescription column layout is empty."); return }
        pages.append(regions)
      }
    } else {
      var next = Int(contentTop.rounded())
      for page in legacyPages {
        guard let start = page["start"], let end = page["end"], start == next,
              end > start, end-start <= available else { fail("Prescription page layout is invalid."); return }
        next = end
        pages.append([PDFRegion(left: 0, right: 794, start: start, end: end, destination: CGFloat(contentTop.rounded()))])
      }
      guard next == Int(contentBottom.rounded()) else { fail("Prescription page layout is invalid."); return }
    }
    guard !pages.isEmpty, pages.count <= 500, documentHeight >= footerBottom.rounded() else {
      fail("Prescription page layout is invalid."); return
    }
    if let url = pdfURL, FileManager.default.fileExists(atPath: url.path) {
      present(action, url: url); return
    }
    guard let view = pdfWeb else { fail("Prescription PDF layout was not found. Please try again."); return }
    let token = generation
    let configuration = WKPDFConfiguration()
    configuration.rect = CGRect(x: 0, y: 0, width: 794, height: documentHeight)
    view.createPDF(configuration: configuration) { [weak self] response in
      guard let owner = self, owner.active(token), owner.pending != nil else { return }
      do {
        let bytes = try response.get()
        let url = try owner.writeA4PDF(bytes, request: request, pages: pages)
        owner.pdfURL = url
        view.stopLoading(); view.removeFromSuperview(); owner.pdfWeb = nil
        owner.present(action, url: url)
      } catch { owner.fail("Prescription PDF could not be generated. Please try again.") }
    }
  }

  private struct PDFRegion {
    let left: CGFloat, right: CGFloat
    let start: Int, end: Int
    let destination: CGFloat
  }
  private func writeA4PDF(_ data: Data, request: [String: Any], pages: [[PDFRegion]]) throws -> URL {
    guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider),
          document.numberOfPages == 1, let source = document.page(at: 1),
          let top = request["contentTop"] as? Int, let footerTop = request["footerTop"] as? Int,
          let footerBottom = request["footerBottom"] as? Int, let height = request["documentHeight"] as? Int else {
      throw NSError(domain: "DocDiaryPDF", code: 1)
    }
    let scale = CGFloat(595.0/794.0)
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
    let bytes = renderer.pdfData { context in
      for (index, page) in pages.enumerated() {
        context.beginPage()
        let canvas = context.cgContext
        UIColor.white.setFill(); canvas.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
        func drawRegion(_ start: Int, _ end: Int, _ destination: CGFloat, _ left: CGFloat = 0, _ right: CGFloat = 794) {
          guard end > start else { return }
          canvas.saveGState()
          canvas.scaleBy(x: scale, y: scale)
          canvas.clip(to: CGRect(x: left, y: destination, width: right-left, height: CGFloat(end-start)))
          canvas.translateBy(x: 0, y: destination - CGFloat(start) + CGFloat(height))
          canvas.scaleBy(x: 1, y: -1)
          canvas.concatenate(source.getDrawingTransform(.mediaBox,
            rect: CGRect(x: 0, y: 0, width: 794, height: CGFloat(height)), rotate: 0, preserveAspectRatio: false))
          canvas.drawPDFPage(source)
          canvas.restoreGState()
        }
        drawRegion(0, top, 0)
        for region in page { drawRegion(region.start, region.end, region.destination, region.left, region.right) }
        drawRegion(footerTop, footerBottom, (842/scale - CGFloat(footerBottom-footerTop)).rounded())
        let label = "Page \(index+1) of \(pages.count)" as NSString
        let font = UIFont.boldSystemFont(ofSize: 6.5)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let width = label.size(withAttributes: attributes).width
        label.draw(at: CGPoint(x: 595-28-width, y: 842-10-font.ascender), withAttributes: attributes)
      }
    }
    guard !bytes.isEmpty else { throw NSError(domain: "DocDiaryPDF", code: 2) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(documentName + ".pdf")
    try bytes.write(to: url, options: [.atomic, .completeFileProtection])
    return url
  }

  private func presenter() -> UIViewController? {
    guard var controller = surface.window?.rootViewController else { return nil }
    while let presented = controller.presentedViewController { controller = presented }
    return controller
  }
  private func present(_ action: String, url: URL) {
    guard let controller = presenter(), active(generation) else { complete(false); return }
    deadline?.invalidate(); deadline = nil
    switch action {
    case "download":
      let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      picker.delegate = self
      modal = picker
      controller.present(picker, animated: true)
      picker.presentationController?.delegate = self
    case "share":
      let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      share.completionWithItemsHandler = { [weak self] _, completed, _, error in
        self?.modal = nil
        if error != nil { self?.complete(FlutterError(code: "share", message: "Unable to share the prescription PDF.", details: nil)) }
        else { self?.complete(completed) }
      }
      share.popoverPresentationController?.sourceView = surface
      share.popoverPresentationController?.sourceRect = CGRect(x: surface.bounds.midX, y: surface.bounds.maxY-1, width: 1, height: 1)
      modal = share
      controller.present(share, animated: true)
      share.presentationController?.delegate = self
    default:
      guard UIPrintInteractionController.isPrintingAvailable else {
        complete(FlutterError(code: "print", message: "Print service is not available.", details: nil)); return
      }
      let printUI = UIPrintInteractionController.shared
      let info = UIPrintInfo(dictionary: nil)
      info.jobName = documentName; info.outputType = .general; info.orientation = .portrait
      printUI.printInfo = info; printUI.printingItem = url; printUI.showsPageRange = true
      printUI.delegate = self
      printing = printUI
      let completion: UIPrintInteractionController.CompletionHandler = { [weak self] _, completed, error in
        self?.printing = nil
        if error != nil { self?.complete(FlutterError(code: "print", message: "Unable to print the prescription PDF.", details: nil)) }
        else { self?.complete(completed) }
      }
      let shown: Bool
      if UIDevice.current.userInterfaceIdiom == .pad {
        shown = printUI.present(from: CGRect(x: surface.bounds.midX, y: surface.bounds.maxY-1, width: 1, height: 1), in: surface, animated: true, completionHandler: completion)
      } else { shown = printUI.present(animated: true, completionHandler: completion) }
      if !shown { printing = nil; complete(FlutterError(code: "print", message: "Unable to start printing.", details: nil)) }
    }
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    modal = nil; complete(!urls.isEmpty)
  }
  func printInteractionController(_ printInteractionController: UIPrintInteractionController,
                                 choosePaper paperList: [UIPrintPaper]) -> UIPrintPaper {
    UIPrintPaper.bestPaper(forPageSize: CGSize(width: 595, height: 842), withPapersFrom: paperList)
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { modal = nil; complete(false) }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { modal = nil; complete(false) }
  @objc private func background() { cancelWork() }
  private func cancelWork() {
    generation += 1
    pdfWeb?.stopLoading(); pdfWeb?.removeFromSuperview(); pdfWeb = nil
    modal?.dismiss(animated: false); modal = nil
    printing?.dismiss(animated: false); printing = nil
    layout = nil
    if let url = pdfURL { try? FileManager.default.removeItem(at: url) }; pdfURL = nil
    complete(FlutterError(code: "cancelled", message: "Prescription action was cancelled.", details: nil))
  }
  private func dispose() {
    guard !disposed else { return }
    disposed = true
    cancelWork()
    ready = false
    web.stopLoading(); web.navigationDelegate = nil; web.removeFromSuperview()
    surface.onResize = nil
    html = ""
    try? FileManager.default.removeItem(at: directory)
    NotificationCenter.default.removeObserver(self)
    channel.setMethodCallHandler(nil)
  }
  deinit {
    NotificationCenter.default.removeObserver(self)
    deadline?.invalidate()
    channel.setMethodCallHandler(nil)
    try? FileManager.default.removeItem(at: directory)
  }
  private static let layoutScript = #"""
  (function(){function getRect(element){if(!element){return null;}var rect=element.getBoundingClientRect();return {top:rect.top+window.pageYOffset,bottom:rect.bottom+window.pageYOffset};}var footer=document.querySelector('.footer');if(footer){footer.innerHTML=footer.innerHTML.replace(/\s*\|\s*Page\s+\d+\s+of\s+\d+\s*$/i,'');}var patientCard=document.querySelector('.patient-card');var vitals=document.querySelector('.vitals');var columns=document.querySelector('.columns');var bottomInfo=document.querySelector('.bottom-info');var contentStart=patientCard||vitals||columns||bottomInfo;var contentStartRect=getRect(contentStart);var bottomInfoRect=getRect(bottomInfo);var footerRect=getRect(footer);if(!contentStartRect||!bottomInfoRect||!footerRect){return JSON.stringify({error:'Required prescription layout was not found.'});}var result={contentTop:contentStartRect.top,contentBottom:bottomInfoRect.top,footerTop:bottomInfoRect.top,footerBottom:footerRect.bottom,documentHeight:Math.max(document.body.scrollHeight,document.documentElement.scrollHeight,footerRect.bottom),ranges:[]};function addRange(element){var itemRect=getRect(element);if(itemRect&&itemRect.bottom>itemRect.top){result.ranges.push({top:itemRect.top,bottom:itemRect.bottom});}}var atomicItems=document.querySelectorAll('.patient-card,.vitals,.section-item,.medicine-card-new,.medicine-card,.special-alert');Array.prototype.forEach.call(atomicItems,function(element){addRange(element);});var sections=document.querySelectorAll('.section');Array.prototype.forEach.call(sections,function(section){var title=section.querySelector('.section-title');var firstItem=section.querySelector('.medicine-card-new,.medicine-card,.section-item');var titleRect=getRect(title);var firstItemRect=getRect(firstItem);if(titleRect&&firstItemRect&&firstItemRect.bottom>titleRect.top){result.ranges.push({top:titleRect.top,bottom:firstItemRect.bottom});}});var rxTitle=document.querySelector('.rx-title');if(rxTitle&&rxTitle.parentElement){var firstRxSection=rxTitle.parentElement.querySelector('.section');var firstRxItem=firstRxSection?firstRxSection.querySelector('.medicine-card-new,.medicine-card,.section-item'):null;var rxTitleRect=getRect(rxTitle);var firstRxItemRect=getRect(firstRxItem);if(rxTitleRect&&firstRxItemRect&&firstRxItemRect.bottom>rxTitleRect.top){result.ranges.push({top:rxTitleRect.top,bottom:firstRxItemRect.bottom});}}result.columns=[];Array.prototype.forEach.call(document.querySelectorAll('.columns > .column'),function(column){var rect=column.getBoundingClientRect();var items=column.querySelectorAll('.section-item,.medicine-card-new,.medicine-card,.special-alert');var ranges=[];function keep(element){var r=getRect(element);if(r&&r.bottom>r.top){ranges.push(r);}}Array.prototype.forEach.call(items,keep);Array.prototype.forEach.call(column.querySelectorAll('.section'),function(section){var title=getRect(section.querySelector('.section-title'));var first=getRect(section.querySelector('.medicine-card-new,.medicine-card,.section-item'));if(title&&first){ranges.push({top:title.top,bottom:first.bottom});}});var rx=getRect(column.querySelector('.rx-title'));var first=getRect(column.querySelector('.medicine-card-new,.medicine-card,.section-item'));if(rx&&first){ranges.push({top:rx.top,bottom:first.bottom});}var bottom=rect.top+window.pageYOffset;Array.prototype.forEach.call(column.children,function(child){var r=getRect(child);if(r){bottom=Math.max(bottom,r.bottom);}});result.columns.push({left:rect.left+window.pageXOffset,right:rect.right+window.pageXOffset,top:rect.top+window.pageYOffset,bottom:Math.min(bottom,result.contentBottom),ranges:ranges});});return JSON.stringify(result);})();
  """#
  private static let printStyle = #"""
  <style>html,body{margin:0!important;padding:0!important;width:210mm!important;background:#FFFFFF!important;overflow:visible!important;}.sheet{width:210mm!important;min-height:297mm!important;margin:0!important;box-shadow:none!important;}</style>
  """#
}
