import Flutter
import UIKit
import PDFKit

/// ReportShow.java on iOS: original PDF, page navigation, pinch zoom and save.
final class DocDiaryReportPdfPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(ReportPdfFactory(messenger: registrar.messenger()), withId: "docdiary/report_pdf")
  }
}
private final class ReportPdfFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    ReportPdfView(frame: frame, id: viewId, messenger: messenger)
  }
}
private final class ReportPdfContainer: UIView {
  weak var pdf: PDFView?
  var resized: (() -> Void)?
  private var previousSize = CGSize.zero
  override func layoutSubviews() {
    super.layoutSubviews(); pdf?.frame = bounds
    if bounds.size != previousSize && bounds.width > 0 && bounds.height > 0 {
      previousSize = bounds.size; resized?()
    }
  }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil { setNeedsLayout(); resized?() }
  }
}
private final class ReportPdfView: NSObject, FlutterPlatformView,
  UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private let surface: ReportPdfContainer
  private let pdfView = PDFView()
  private let channel: FlutterMethodChannel
  private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("docdiary_report_" + UUID().uuidString, isDirectory: true)
  private var document: PDFDocument?
  private var data: Data?
  private var documentName = "Report"
  private var generation = 0
  private var disposed = false
  private var pendingReady: FlutterResult?
  private var pendingResponse = 0
  private var fitScale: CGFloat?
  private var pendingSave: FlutterResult?
  private var modal: UIDocumentPickerViewController?
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
    surface = ReportPdfContainer(frame: frame)
    channel = FlutterMethodChannel(name: "docdiary/report_pdf/\(id)", binaryMessenger: messenger)
    super.init()
    surface.backgroundColor = .white; pdfView.backgroundColor = .white
    // A single copied source page retains native Prev/Next navigation. PDFKit
    // handles PDF points, screen pixels, rotation, panning and pinch zoom itself.
    pdfView.displayMode = .singlePageContinuous; pdfView.displayDirection = .vertical
    pdfView.displayBox = .cropBox; pdfView.displaysPageBreaks = false
    pdfView.pageBreakMargins = .zero; pdfView.pageShadowsEnabled = false
    surface.addSubview(pdfView); surface.pdf = pdfView
    surface.resized = { [weak self] in self?.fitPage() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let owner = self, !owner.disposed else {
        result(FlutterError(code: "disposed", message: "The report viewer was closed.", details: nil)); return
      }
      owner.handle(call, result: result)
    }
    NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
  }
  func view() -> UIView { surface }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "load":
      cancelWork()
      guard let args = call.arguments as? [String: Any], let typed = args["bytes"] as? FlutterStandardTypedData,
            typed.data.count >= 5, typed.data.count <= 24 * 1024 * 1024,
            typed.data.prefix(5) == Data("%PDF-".utf8),
            let pdf = PDFDocument(data: typed.data), !pdf.isLocked, pdf.pageCount > 0, pdf.pageCount <= 2000 else {
        result(FlutterError(code: "invalid_pdf", message: "The server did not return a readable PDF.", details: nil)); return
      }
      data = typed.data; document = pdf
      let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
      documentName = String(((args["documentName"] as? String) ?? "Report").components(separatedBy: forbidden).joined(separator: "_").prefix(180))
      if documentName.isEmpty { documentName = "Report" }
      showPage(0, document: pdf, response: pdf.pageCount, result: result)
    case "page":
      guard pendingReady == nil, pendingSave == nil, let args = call.arguments as? [String: Any],
            let index = args["index"] as? Int, let pdf = document, index >= 0, index < pdf.pageCount else {
        result(FlutterError(code: "page", message: "The report page is unavailable.", details: nil)); return
      }
      showPage(index, document: pdf, response: index, result: result)
    case "zoom":
      guard pendingReady == nil, pendingSave == nil, fitScale != nil, pdfView.document != nil,
            let args = call.arguments as? [String: Any], let value = args["factor"] as? NSNumber,
            value.doubleValue.isFinite, value.doubleValue > 0, value.doubleValue <= 8 else {
        result(FlutterError(code: "zoom", message: "The report PDF is not ready to zoom.", details: nil)); return
      }
      pdfView.autoScales = false
      pdfView.scaleFactor = min(pdfView.maxScaleFactor, max(pdfView.minScaleFactor, pdfView.scaleFactor * CGFloat(value.doubleValue)))
      result(nil)
    case "save": save(result)
    case "suspend": cancelWork(); result(nil)
    case "dispose": dispose(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func showPage(_ index: Int, document: PDFDocument, response: Int, result: @escaping FlutterResult) {
    guard let page = document.page(at: index), let copy = page.copy() as? PDFPage else {
      result(FlutterError(code: "page", message: "The report page is unavailable.", details: nil)); return
    }
    let bounds = page.bounds(for: .cropBox)
    guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0,
          bounds.width <= 20000, bounds.height <= 20000 else {
      result(FlutterError(code: "page", message: "The report page size is invalid.", details: nil)); return
    }
    pendingReady = result; pendingResponse = response; fitScale = nil
    let displayDocument = PDFDocument(); displayDocument.insert(copy, at: 0)
    pdfView.autoScales = true; pdfView.document = displayDocument
    surface.setNeedsLayout(); surface.layoutIfNeeded(); fitPage()
    // A platform view may be created with zero bounds. Complete load only after
    // layout establishes a real fit; never publish a bitmap-scale=1 preview.
    let token = generation
    DispatchQueue.main.async { [weak self] in
      guard let owner = self, !owner.disposed, token == owner.generation, owner.pendingReady != nil else { return }
      owner.surface.setNeedsLayout(); owner.surface.layoutIfNeeded(); owner.fitPage()
    }
  }
  private func fitPage() {
    guard !disposed, pdfView.document != nil, pdfView.bounds.width > 0, pdfView.bounds.height > 0 else { return }
    let ratio = fitScale.map { max(1, pdfView.scaleFactor / $0) } ?? 1
    pdfView.layoutDocumentView()
    let fit = pdfView.scaleFactorForSizeToFit
    guard fit.isFinite, fit > 0 else { return }
    pdfView.autoScales = false
    // Reset limits before assigning a fit for a different page or viewport.
    pdfView.minScaleFactor = min(fit, pdfView.minScaleFactor)
    pdfView.maxScaleFactor = max(fit * 8, pdfView.maxScaleFactor)
    pdfView.minScaleFactor = fit; pdfView.maxScaleFactor = fit * 8
    pdfView.scaleFactor = min(fit * 8, fit * ratio); fitScale = fit
    let callback = pendingReady; pendingReady = nil; callback?(pendingResponse)
  }
  private func presenter() -> UIViewController? {
    var candidate: UIResponder? = surface
    while let next = candidate?.next {
      if let controller = next as? UIViewController {
        return controller.view.window == nil || controller.isBeingDismissed || controller.presentedViewController != nil ? nil : controller
      }
      candidate = next
    }
    return nil
  }
  private func save(_ result: @escaping FlutterResult) {
    guard pendingSave == nil, pendingReady == nil, fitScale != nil, let bytes = data, document != nil, let controller = presenter() else {
      result(FlutterError(code: "save", message: "The report PDF is not ready to save.", details: nil)); return
    }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let url = directory.appendingPathComponent(documentName + ".pdf")
      try bytes.write(to: url, options: [.atomic, .completeFileProtection])
      let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      picker.delegate = self; pendingSave = result; modal = picker
      controller.present(picker, animated: true); picker.presentationController?.delegate = self
    } catch { result(FlutterError(code: "save", message: "Unable to save the report PDF. Please try again.", details: nil)) }
  }
  private func completeSave(_ saved: Bool) {
    modal = nil; let callback = pendingSave; pendingSave = nil; callback?(saved)
    try? FileManager.default.removeItem(at: directory)
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completeSave(!urls.isEmpty) }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completeSave(false) }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { completeSave(false) }
  @objc private func background() { cancelWork() }
  private func cancelWork() {
    generation += 1; modal?.dismiss(animated: false); modal = nil
    let ready = pendingReady; pendingReady = nil
    let save = pendingSave; pendingSave = nil
    ready?(FlutterError(code: "cancelled", message: "The report viewer was suspended.", details: nil))
    save?(FlutterError(code: "cancelled", message: "The report save was cancelled.", details: nil))
    data = nil; document = nil; pdfView.document = nil; fitScale = nil
    try? FileManager.default.removeItem(at: directory)
  }
  private func dispose() {
    guard !disposed else { return }
    disposed = true; cancelWork(); surface.resized = nil
    channel.setMethodCallHandler(nil); NotificationCenter.default.removeObserver(self)
  }
  deinit { dispose() }
}
