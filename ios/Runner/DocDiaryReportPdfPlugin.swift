import Flutter
import UIKit

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
  weak var scroll: UIScrollView?
  var resized: (() -> Void)?
  private var previousSize = CGSize.zero
  override func layoutSubviews() {
    super.layoutSubviews(); scroll?.frame = bounds
    if bounds.size != previousSize && bounds.width > 0 && bounds.height > 0 {
      previousSize = bounds.size; resized?()
    }
  }
}
private final class ReportPdfView: NSObject, FlutterPlatformView, UIScrollViewDelegate,
  UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private let surface: ReportPdfContainer
  private let scroll = UIScrollView()
  private let image = UIImageView()
  private let channel: FlutterMethodChannel
  private let renderer = DispatchQueue(label: "com.docdiary.report-pdf-render")
  private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("docdiary_report_" + UUID().uuidString, isDirectory: true)
  private var document: CGPDFDocument?
  private var data: Data?
  private var documentName = "Report"
  private var generation = 0
  private var disposed = false
  private var pendingRender: FlutterResult?
  private var pendingSave: FlutterResult?
  private var modal: UIDocumentPickerViewController?
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
    surface = ReportPdfContainer(frame: frame)
    channel = FlutterMethodChannel(name: "docdiary/report_pdf/\(id)", binaryMessenger: messenger)
    super.init()
    surface.backgroundColor = .white; scroll.backgroundColor = .white
    scroll.delegate = self; scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 3
    scroll.showsHorizontalScrollIndicator = false; scroll.showsVerticalScrollIndicator = false
    scroll.contentInsetAdjustmentBehavior = .never; image.contentMode = .scaleAspectFit
    scroll.addSubview(image); surface.addSubview(scroll); surface.scroll = scroll
    surface.resized = { [weak self] in self?.fitImage() }
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
            typed.data.prefix(5) == Data("%PDF-".utf8), let provider = CGDataProvider(data: typed.data as CFData),
            let pdf = CGPDFDocument(provider), pdf.numberOfPages > 0, pdf.numberOfPages <= 2000 else {
        result(FlutterError(code: "invalid_pdf", message: "The server did not return a readable PDF.", details: nil)); return
      }
      data = typed.data; document = pdf
      let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
      documentName = String(((args["documentName"] as? String) ?? "Report").components(separatedBy: forbidden).joined(separator: "_").prefix(180))
      if documentName.isEmpty { documentName = "Report" }
      render(0, document: pdf, response: pdf.numberOfPages, result: result)
    case "page":
      guard pendingRender == nil, pendingSave == nil, let args = call.arguments as? [String: Any],
            let index = args["index"] as? Int, let pdf = document, index >= 0, index < pdf.numberOfPages else {
        result(FlutterError(code: "page", message: "The report page is unavailable.", details: nil)); return
      }
      render(index, document: pdf, response: index, result: result)
    case "save": save(result)
    case "suspend": cancelWork(); result(nil)
    case "dispose": dispose(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func render(_ index: Int, document: CGPDFDocument, response: Int, result: @escaping FlutterResult) {
    guard let page = document.page(at: index + 1) else {
      result(FlutterError(code: "page", message: "The report page is unavailable.", details: nil)); return
    }
    let bounds = page.getBoxRect(.cropBox)
    guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0,
          bounds.width <= 20000, bounds.height <= 20000 else {
      result(FlutterError(code: "page", message: "The report page size is invalid.", details: nil)); return
    }
    pendingRender = result; let token = generation
    let scale = min(3, sqrt(10_000_000 / (bounds.width * bounds.height)))
    let rotated = page.rotationAngle % 180 != 0
    let renderSize = CGSize(width: (rotated ? bounds.height : bounds.width) * scale, height: (rotated ? bounds.width : bounds.height) * scale)
    renderer.async { [weak self] in
      let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
      let bitmap = withExtendedLifetime(document) { UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
        UIColor.white.setFill(); context.cgContext.fill(CGRect(origin: .zero, size: renderSize))
        let canvas = context.cgContext
        canvas.translateBy(x: 0, y: renderSize.height); canvas.scaleBy(x: 1, y: -1)
        canvas.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: renderSize), rotate: 0, preserveAspectRatio: true))
        canvas.drawPDFPage(page)
      } }
      DispatchQueue.main.async {
        guard let owner = self, !owner.disposed, token == owner.generation else { return }
        owner.image.image = bitmap; owner.fitImage()
        let callback = owner.pendingRender; owner.pendingRender = nil; callback?(response)
      }
    }
  }
  private func fitImage() {
    guard let bitmap = image.image, scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
    scroll.zoomScale = 1
    let scale = min(scroll.bounds.width / bitmap.size.width, scroll.bounds.height / bitmap.size.height)
    image.frame = CGRect(origin: .zero, size: CGSize(width: bitmap.size.width * scale, height: bitmap.size.height * scale))
    scroll.contentSize = image.bounds.size; centerImage()
    scroll.contentOffset = CGPoint(x: -scroll.contentInset.left, y: -scroll.contentInset.top)
  }
  private func centerImage() {
    let horizontal = max(0, (scroll.bounds.width - scroll.contentSize.width) / 2)
    let vertical = max(0, (scroll.bounds.height - scroll.contentSize.height) / 2)
    scroll.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
  }
  func viewForZooming(in scrollView: UIScrollView) -> UIView? { image }
  func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }
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
    guard pendingSave == nil, pendingRender == nil, let bytes = data, document != nil, let controller = presenter() else {
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
    let render = pendingRender; pendingRender = nil
    let save = pendingSave; pendingSave = nil
    render?(FlutterError(code: "cancelled", message: "The report viewer was suspended.", details: nil))
    save?(FlutterError(code: "cancelled", message: "The report save was cancelled.", details: nil))
    data = nil; document = nil; image.image = nil
    try? FileManager.default.removeItem(at: directory)
  }
  private func dispose() {
    guard !disposed else { return }
    disposed = true; cancelWork(); surface.resized = nil; scroll.delegate = nil
    channel.setMethodCallHandler(nil); NotificationCenter.default.removeObserver(self)
  }
  deinit { dispose() }
}
