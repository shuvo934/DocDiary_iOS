import 'dart:typed_data';
import 'dynamic_prescription_preview_models.dart';

/// Direct port of PrescriptionPreviewHtmlBuilder.java: HTML/CSS is unchanged.
class NativeDynamicPreviewHtml {
  static const String defaultPrimaryColor = "#087D49";
  static const String defaultSecondaryColor = "#123B68";

  static String build(
    DynamicPrescriptionPreviewData data, {
    DateTime? printedAt,
  }) {
    String primaryColor = normalizeColor(
      data.facility.primaryColor,
      defaultPrimaryColor,
    );
    String secondaryColor = normalizeColor(
      data.facility.secondaryColor,
      defaultSecondaryColor,
    );

    String primaryLight = mixWithWhite(primaryColor, 0.90);
    String primaryLightPat = mixWithWhite(primaryColor, 0.97);
    String primaryBorder = mixWithWhite(primaryColor, 0.70);

    NativePreviewHtmlBuffer html = NativePreviewHtmlBuffer();

    html.append("<!DOCTYPE html>");
    html.append("<html>");
    html.append("<head>");
    html.append("<meta charset='UTF-8'>");
    html.append(
      "<meta name='viewport' content='width=device-width,initial-scale=1.0'>",
    );

    appendStyles(
      html,
      primaryColor,
      secondaryColor,
      primaryLight,
      primaryBorder,
      primaryLightPat,
    );

    html.append("</head>");
    html.append("<body>");
    html.append("<div class='sheet'>");

    appendHeader(html, data);

    appendPatientSummary(html, data);

    appendVitals(html, data.vitals);

    appendMainContent(html, data);

    appendReferenceAndSignature(html, data);

    appendFooter(html, data.facility, printedAt ?? DateTime.now());

    html.append("</div>");
    html.append("</body>");
    html.append("</html>");

    return html.toString();
  }

  static void appendStyles(
    NativePreviewHtmlBuffer html,
    String primary,
    String secondary,
    String light,
    String border,
    String lightPat,
  ) {
    html.append("<style>");

    html.append("@page{");
    html.append("size:A4;");
    html.append("margin:0;");
    html.append("}");

    html.append("*{");
    html.append("box-sizing:border-box;");
    html.append("}");

    html.append("html,body{");
    html.append("margin:0;");
    html.append("padding:0;");
    html.append("}");

    html.append("body{");
    html.append("background:#E9EEF3;");
    html.append("color:#263244;");
    html.append("font-family:Arial,'Noto Sans Bengali',sans-serif;");
    html.append("-webkit-print-color-adjust:exact;");
    html.append("print-color-adjust:exact;");
    html.append("}");

    html.append(".sheet{");
    html.append("width:210mm;");
    html.append("min-height:297mm;");
    html.append("margin:12px auto;");
    html.append("padding:10mm 10mm 0;");
    html.append("background:#FFFFFF;");
    html.append("box-shadow:0 3px 16px rgba(16,24,40,.16);");
    html.append("display:flex;");
    html.append("flex-direction:column;");
    html.append("}");

    html.append(".facility-header{");
    html.append("display:flex;");
    html.append("align-items:center;");
    html.append("justify-content:center;");
    html.append("gap:16px;");
    html.append("padding:0 5px 12px;");
    html.append("}");

    html.append(".facility-logo{");
    html.append("width:82px;");
    html.append("height:68px;");
    html.append("object-fit:contain;");
    html.append("flex:0 0 82px;");
    html.append("}");

    html.append(".logo-fallback{");
    html.append("width:68px;");
    html.append("height:68px;");
    html.append("border-radius:50%;");
    html.append("display:flex;");
    html.append("align-items:center;");
    html.append("justify-content:center;");
    html.append("background:").append(primary).append(";");
    html.append("color:#FFFFFF;");
    html.append("font-size:25px;");
    html.append("font-weight:800;");
    html.append("flex:0 0 68px;");
    html.append("}");

    html.append(".facility-info{");
    html.append("min-width:0;");
    html.append("flex:1;");
    html.append("}");

    html.append(".facility-name{");
    html.append("margin:0;");
    html.append("color:").append(secondary).append(";");
    html.append("font-size:21px;");
    html.append("font-family:Arial,'Noto Sans Bengali',sans-serif;");
    html.append("font-weight:900;");
    html.append("letter-spacing:1px;");
    html.append("line-height:1.25;");
    html.append("}");

    html.append(".facility-details,.facility-contact{");
    html.append("margin-top:4px;");
    html.append("color:#667085;");
    html.append("font-size:10px;");
    html.append("line-height:1.45;");
    html.append("white-space:pre-line;");
    html.append("}");

    html.append(".prescription-title{");
    html.append("text-align:center;");
    html.append("color:").append(secondary).append(";");
    html.append("font-size:16px;");
    html.append("font-weight:900;");
    html.append("letter-spacing:.5px;");
    html.append("padding:2px 0 10px;");
    html.append("}");

    html.append(".department-bar{");
    html.append("padding:8px 12px;");
    html.append("border-radius:6px;");
    html.append("background:").append(primary).append(";");
    html.append("color:#FFFFFF;");
    html.append("text-align:center;");
    html.append("font-size:14px;");
    html.append("font-weight:900;");
    html.append("letter-spacing:.45px;");
    html.append("}");

    html.append(".patient-card{");
    html.append("margin-top:10px;");
    html.append("border:1px solid ").append(border).append(";");
    html.append("border-radius:9px;");
    html.append("background:").append(lightPat).append(";");
    html.append("overflow:hidden;");
    html.append("break-inside:avoid;");
    html.append("page-break-inside:avoid;");
    html.append("}");

    html.append(".patient-grid{");
    html.append("display:grid;");
    html.append("grid-template-columns:repeat(3,1fr);");
    html.append("padding:4px 8px 7px;");
    html.append("}");

    html.append(".patient-grid-new{");
    html.append("display:grid;");
    html.append("grid-template-columns:1fr 1.1fr 0.9fr;");
    html.append("padding:4px 5px 7px;");
    html.append("}");

    html.append(".patient-item{");
    html.append("min-height:45px;");
    html.append("padding:9px 8px;");
    html.append("}");

    html.append(".patient-item-new{");
    html.append("min-height:10px;");
    html.append("align-items:center;");
    html.append("padding:3px 3px;");
    html.append("}");

    html.append(".meta-label{");
    html.append("display:block;");
    html.append("color:#667085;");
    html.append("font-size:7.5px;");
    html.append("font-weight:800;");
    html.append("text-transform:uppercase;");
    html.append("letter-spacing:.35px;");
    html.append("}");

    html.append(".meta-label-new{");
    html.append("color:#667085;");
    html.append("font-size:7.5px;");
    html.append("font-weight:800;");
    html.append("text-transform:uppercase;");
    html.append("letter-spacing:.35px;");
    html.append("}");

    html.append(".meta-value{");
    html.append("display:block;");
    html.append("margin-top:4px;");
    html.append("color:#202B3C;");
    html.append("font-size:11px;");
    html.append("font-weight:800;");
    html.append("line-height:1.35;");
    html.append("overflow-wrap:anywhere;");
    html.append("}");

    html.append(".meta-value-new{");
    html.append("color:#202B3C;");
    html.append("font-size:11px;");
    html.append("font-weight:800;");
    html.append("line-height:1.35;");
    html.append("overflow-wrap:anywhere;");
    html.append("}");

    html.append(".vitals{");
    html.append("display:flex;");
    html.append("margin-top:8px;");
    html.append("border:1px solid ").append(border).append(";");
    html.append("border-radius:7px;");
    html.append("background:").append(light).append(";");
    html.append("overflow:hidden;");
    html.append("break-inside:avoid;");
    html.append("page-break-inside:avoid;");
    html.append("}");

    html.append(".vital{");
    html.append("min-width:0;");
    html.append("padding:7px 4px;");
    html.append("text-align:center;");
    html.append("flex:1;");
    html.append("border-right:1px solid ").append(border).append(";");
    html.append("}");

    html.append(".vital:last-child{");
    html.append("border-right:0;");
    html.append("}");

    html.append(".vital-label{");
    html.append("display:block;");
    html.append("color:#667085;");
    html.append("font-size:7px;");
    html.append("font-weight:800;");
    html.append("text-transform:uppercase;");
    html.append("}");

    html.append(".vital-value{");
    html.append("display:block;");
    html.append("margin-top:3px;");
    html.append("color:").append(secondary).append(";");
    html.append("font-size:9.5px;");
    html.append("font-weight:900;");
    html.append("white-space:nowrap;");
    html.append("}");

    html.append(".columns{");
    html.append("display:grid;");
    html.append("grid-template-columns:minmax(0,1fr) minmax(0,1fr);");
    html.append("gap:20px;");
    html.append("margin-top:8px;");
    html.append("align-items:start;");
    html.append("}");

    html.append(".columns.single{");
    html.append("grid-template-columns:1fr;");
    html.append("}");

    html.append(".column{");
    html.append("min-width:0;");
    html.append("}");

    html.append(".rx-title{");
    html.append("margin:-2px 0 5px;");
    html.append("color:").append(secondary).append(";");
    html.append("font-family:Arial,Georgia,serif;");
    html.append("font-size:31px;");
    html.append("font-weight:900;");
    html.append("line-height:1;");
    html.append("}");

    html.append(".section{");
    html.append("margin-bottom:10px;");
    html.append("}");

    html.append(".section-title{");
    html.append("padding:4px 9px;");
    html.append("border-radius:5px;");
    html.append("background:").append(light).append(";");
    html.append("color:").append(primary).append(";");
    html.append("font-size:12px;");
    html.append("font-weight:900;");
    html.append("letter-spacing:.2px;");
    html.append("text-transform:uppercase;");
    html.append("break-after:avoid;");
    html.append("page-break-after:avoid;");
    html.append("}");

    html.append(".section-item{");
    html.append("display:flex;");
    html.append("gap:7px;");
    html.append("margin:4px 1px 0;");
    html.append("font-size:11px;");
    html.append("line-height:1.38;");
    html.append("break-inside:avoid;");
    html.append("page-break-inside:avoid;");
    html.append("}");

    html.append(".bullet{");
    html.append("width:4px;");
    html.append("height:4px;");
    html.append("margin-top:5px;");
    html.append("border-radius:50%;");
    html.append("background:").append(primary).append(";");
    html.append("flex:0 0 4px;");
    html.append("}");

    html.append(".item-body{");
    html.append("min-width:0;");
    html.append("flex:1;");
    html.append("overflow-wrap:anywhere;");
    html.append("}");

    html.append(".item-note{");
    html.append("margin-top:2px;");
    html.append("color:#667085;");
    html.append("font-size:8.5px;");
    html.append("font-style:italic;");
    html.append("}");

    html.append(".item-note-new{");
    html.append("color:#667085;");
    html.append("font-size:8.5px;");
    html.append("font-style:italic;");
    html.append("}");

    html.append(".medicine-card-new{");
    html.append("display:flex;");
    html.append("align-items:flex-start;");
    html.append("gap:5px;");
    html.append("margin:0;");
    html.append("padding:4px 0;");
    html.append("border:0;");
    html.append("border-bottom:1px solid #EAECF0;");
    html.append("border-radius:0;");
    html.append("break-inside:avoid;");
    html.append("page-break-inside:avoid;");
    html.append("}");

    html.append(".medicine-card-new:last-child{");
    html.append("border-bottom:0;");
    html.append("padding-bottom:1px;");
    html.append("}");

    html.append(".medicine-serial-new{");
    html.append("flex:0 0 15px;");
    html.append("color:").append(primary).append(";");
    html.append("font-size:9.5px;");
    html.append("font-weight:900;");
    html.append("line-height:1.3;");
    html.append("}");

    html.append(".medicine-content-new{");
    html.append("min-width:0;");
    html.append("flex:1;");
    html.append("}");

    html.append(".medicine-name-new{");
    html.append("color:").append(secondary).append(";");
    html.append("font-size:10px;");
    html.append("font-weight:900;");
    html.append("line-height:1.3;");
    html.append("}");

    html.append(".medicine-meta-new{");
    html.append("margin-top:1px;");
    html.append("color:#667085;");
    html.append("font-size:8.3px;");
    html.append("line-height:1.3;");
    html.append("}");

    html.append(".medicine-meta-new span+span:before{");
    html.append("content:'  |  ';");
    html.append("color:#98A2B3;");
    html.append("}");

    html.append(".medicine-duration-new{");
    html.append("color:").append(primary).append(";");
    html.append("font-weight:800;");
    html.append("}");

    html.append(".medicine-notes-new{");
    html.append("color:#667085;");
    html.append("font-style:italic;");
    html.append("}");

    html.append(".medicine-card{");
    html.append("margin:8px 0 9px;");
    html.append("padding:9px 10px;");
    html.append("border:1px solid ").append(border).append(";");
    html.append("border-radius:7px;");
    html.append("break-inside:avoid;");
    html.append("page-break-inside:avoid;");
    html.append("}");

    html.append(".medicine-name{");
    html.append("color:").append(secondary).append(";");
    html.append("font-size:10.5px;");
    html.append("font-weight:900;");
    html.append("line-height:1.35;");
    html.append("}");

    html.append(".medicine-meta{");
    html.append("margin-top:4px;");
    html.append("color:#667085;");
    html.append("font-size:8.7px;");
    html.append("line-height:1.45;");
    html.append("}");

    html.append(".medicine-meta span+span:before{");
    html.append("content:'  |  ';");
    html.append("color:#98A2B3;");
    html.append("}");

    html.append(".medicine-bottom{");
    html.append("display:flex;");
    html.append("justify-content:space-between;");
    html.append("gap:10px;");
    html.append("margin-top:5px;");
    html.append("font-size:8.7px;");
    html.append("line-height:1.35;");
    html.append("}");

    html.append(".medicine-duration{");
    html.append("color:").append(primary).append(";");
    html.append("font-weight:900;");
    html.append("}");

    html.append(".medicine-notes{");
    html.append("color:#667085;");
    html.append("text-align:right;");
    html.append("font-style:italic;");
    html.append("}");

    html.append(".special-alert{");
    html.append("margin-top:8px;");
    html.append("padding:9px 10px;");
    html.append("border:1px solid #F5A623;");
    html.append("border-radius:7px;");
    html.append("background:#FFF8EA;");
    html.append("break-inside:avoid;");
    html.append("page-break-inside:avoid;");
    html.append("}");

    html.append(".alert-title{");
    html.append("color:#B54708;");
    html.append("font-size:9px;");
    html.append("font-weight:900;");
    html.append("text-transform:uppercase;");
    html.append("}");

    html.append(".alert-item{");
    html.append("margin-top:5px;");
    html.append("color:#263244;");
    html.append("font-size:9px;");
    html.append("line-height:1.4;");
    html.append("}");

    html.append(".bottom-info{");
    html.append("display:grid;");
    html.append("grid-template-columns:minmax(0,1.35fr) minmax(220px,.65fr);");
    html.append("gap:22px;");
    html.append("margin-top:auto;");
    html.append("padding:16px 0 22px;");
    html.append("border-top:1px solid ").append(border).append(";");
    html.append("break-inside:avoid;");
    html.append("page-break-inside:avoid;");
    html.append("}");

    html.append(".reference-title{");
    html.append("color:").append(secondary).append(";");
    html.append("font-size:9.5px;");
    html.append("font-weight:900;");
    html.append("text-transform:uppercase;");
    html.append("}");

    html.append(".reference-value{");
    html.append("margin-top:5px;");
    html.append("color:#667085;");
    html.append("font-size:9px;");
    html.append("line-height:1.5;");
    html.append("white-space:pre-line;");
    html.append("overflow-wrap:anywhere;");
    html.append("}");

    html.append(".reference-extra-value{");
    html.append("margin-top:1px;");
    html.append("color:#667085;");
    html.append("font-size:9px;");
    html.append("line-height:1.5;");
    html.append("white-space:pre-line;");
    html.append("overflow-wrap:anywhere;");
    html.append("}");

    html.append(".signature{");
    html.append("padding-top:8px;");
    html.append("border-top:1px solid ").append(secondary).append(";");
    html.append("text-align:right;");
    html.append("}");

    html.append(".signature-name{");
    html.append("color:").append(secondary).append(";");
    html.append("font-size:10px;");
    html.append("font-weight:900;");
    html.append("}");

    html.append(".signature-detail{");
    html.append("margin-top:3px;");
    html.append("color:#667085;");
    html.append("font-size:8.5px;");
    html.append("line-height:1.4;");
    html.append("}");

    html.append(".footer{");
    html.append("margin:0 -10mm;");
    html.append("padding:8px 10mm 9px;");
    html.append("background:").append(primary).append(";");
    html.append("color:#FFFFFF;");
    html.append("text-align:center;");
    html.append("font-size:8.5px;");
    html.append("line-height:1.55;");
    html.append("}");

    html.append("@media print{");

    html.append("body{");
    html.append("background:#FFFFFF;");
    html.append("}");

    html.append(".sheet{");
    html.append("width:210mm;");
    html.append("min-height:297mm;");
    html.append("margin:0;");
    html.append("padding:10mm 10mm 0;");
    html.append("box-shadow:none;");
    html.append("}");

    html.append("}");

    html.append("</style>");
  }

  static void appendHeader(
    NativePreviewHtmlBuffer html,
    DynamicPrescriptionPreviewData data,
  ) {
    DynamicPreviewFacility facility = data.facility;

    String logoUri = getLogoDataUri(facility.logoBase64);

    html.append("<header class='facility-header'>");

    if (logoUri.isNotEmpty) {
      html
          .append("<img class='facility-logo' src='")
          .append(htmlEscape(logoUri))
          .append("' alt='Facility logo'>");
    } else {
      html.append("<div class='logo-fallback'>Rx</div>");
    }

    html.append("<div class='facility-info'>");

    html
        .append("<h1 class='facility-name'>")
        .append(
          htmlEscape(
            valueOrDefault(facility.name, "Patient Data Management System"),
          ),
        )
        .append("</h1>");

    if (facility.details.isNotEmpty) {
      html
          .append("<div class='facility-details'>")
          .append(htmlEscape(facility.details))
          .append("</div>");
    }

    String contact = buildFacilityContact(facility);

    if (contact.isNotEmpty) {
      html
          .append("<div class='facility-contact'>")
          .append(htmlEscape(contact))
          .append("</div>");
    }

    html.append("</div>");
    html.append("</header>");

    html
        .append("<div class='prescription-title'>")
        .append("REHABILITATION PRESCRIPTION")
        .append("</div>");

    html
        .append("<div class='department-bar'>")
        .append(htmlEscape(getDepartmentTitle(data.provider).toUpperCase()))
        .append("</div>");
  }

  static void appendPatientSummary(
    NativePreviewHtmlBuffer html,
    DynamicPrescriptionPreviewData data,
  ) {
    DynamicPreviewPatient patient = data.patient;

    html.append("<section class='patient-card'>");
    html.append("<div class='patient-grid-new'>");

    appendPatientItemHorizontal(
      html,
      "Prescription Date: ",
      data.prescriptionDate,
    );

    appendPatientItemHorizontal(html, "Prescription No: ", data.rvmCode);

    appendPatientItemHorizontal(html, "Patient Code: ", patient.patientCode);

    appendPatientItemHorizontal(html, "Patient Name: ", patient.patientName);

    appendPatientItemHorizontal(
      html,
      "Age / Gender: ",
      joinNonEmpty(patient.age, patient.gender, " / "),
    );

    appendPatientItemHorizontal(
      html,
      "Category / Type: ",
      buildCategoryType(data),
    );

    html.append("</div>");
    html.append("</section>");
  }

  static void appendPatientItem(
    NativePreviewHtmlBuffer html,
    String label,
    String value,
  ) {
    html.append("<div class='patient-item'>");
    html
        .append("<span class='meta-label'>")
        .append(htmlEscape(label))
        .append("</span>");

    html
        .append("<span class='meta-value'>")
        .append(htmlEscape(valueOrDefault(value, "-")))
        .append("</span>");

    html.append("</div>");
  }

  static void appendPatientItemHorizontal(
    NativePreviewHtmlBuffer html,
    String label,
    String value,
  ) {
    html.append("<div class='patient-item-new'>");
    html
        .append("<span class='meta-label-new'>")
        .append(htmlEscape(label))
        .append("</span>");

    html
        .append("<span class='meta-value-new'>")
        .append(htmlEscape(valueOrDefault(value, "-")))
        .append("</span>");

    html.append("</div>");
  }

  static void appendVitals(
    NativePreviewHtmlBuffer html,
    DynamicPreviewVitals vitals,
  ) {
    if (vitals.isEmpty) {
      return;
    }

    html.append("<section class='vitals'>");

    appendVital(html, "BP", buildBloodPressure(vitals), "");

    appendVital(html, "Pulse", vitals.pulse, "bpm");

    appendVital(html, "Resp.", vitals.respiration, "/min");

    appendVital(html, "Temp.", vitals.temperature, "°F");

    appendVital(html, "SpO2", vitals.spo2, "%");

    appendVital(html, "Height", vitals.height, "cm");

    appendVital(html, "Weight", vitals.weight, "kg");

    appendVital(html, "BMI", vitals.bmi, "kg/m²");

    html.append("</section>");
  }

  static void appendVital(
    NativePreviewHtmlBuffer html,
    String label,
    String value,
    String unit,
  ) {
    if (value.isEmpty) {
      value = "-";
    }

    html.append("<div class='vital'>");

    html
        .append("<span class='vital-label'>")
        .append(htmlEscape(label))
        .append("</span>");

    html.append("<span class='vital-value'>").append(htmlEscape(value));

    if (unit.isNotEmpty) {
      if (!(value == "-")) {
        html.append(" ").append(htmlEscape(unit));
      }
    }

    html.append("</span>");
    html.append("</div>");
  }

  static void appendMainContent(
    NativePreviewHtmlBuffer html,
    DynamicPrescriptionPreviewData data,
  ) {
    bool leftPresent = hasLeftContent(data);
    bool rightPresent = hasRightContent(data);

    if (!leftPresent && !rightPresent) {
      return;
    }

    html.append("<main class='columns");

    if (!leftPresent || !rightPresent) {
      html.append(" single");
    }

    html.append("'>");

    if (leftPresent) {
      appendLeftColumn(html, data);
    }

    if (rightPresent) {
      appendRightColumn(html, data);
    }

    html.append("</main>");
  }

  static void appendLeftColumn(
    NativePreviewHtmlBuffer html,
    DynamicPrescriptionPreviewData data,
  ) {
    html.append("<div class='column'>");

    appendSection(html, "Chief Complaints", data.complaints);

    appendSectionInjury(html, data.injuries);

    appendSection(html, "Diagnosis / Functional Problems", data.diagnosis);

    appendObjectives(html, data.objectiveInfo);

    appendSection(html, "Clinical Findings", data.clinicalFindings);

    appendSection(html, "Drug History", data.drugHistory);

    appendSection(html, "Tests / Investigation", data.investigations);

    appendSection(html, "Important Information", data.importantInfo);

    html.append("</div>");
  }

  static void appendRightColumn(
    NativePreviewHtmlBuffer html,
    DynamicPrescriptionPreviewData data,
  ) {
    html.append("<div class='column'>");

    html.append("<div class='rx-title'>Rx</div>");

    appendMedications(html, data.medications);

    appendSection(html, "Therapy Interventions", data.therapies);

    appendSection(html, "Goals / Treatment Plan", data.treatmentPlans);

    appendSection(html, "Advice", data.advice);

    appendSection(html, "Follow-up / Treatment Schedule", data.followups);

    appendSpecialAlerts(html, data.specialAlerts);

    html.append("</div>");
  }

  static void appendSection(
    NativePreviewHtmlBuffer html,
    String title,
    List<DynamicPreviewSectionItem> items,
  ) {
    if (items.isEmpty) {
      return;
    }

    html.append("<section class='section'>");

    html
        .append("<div class='section-title'>")
        .append(htmlEscape(title))
        .append("</div>");

    for (final item in items) {
      html.append("<div class='section-item'>");

      html.append("<span class='bullet'></span>");

      html.append("<div class='item-body'>").append(htmlEscape(item.text));

      if (item.hasNotes) {
        html
            .append("<span class='item-note-new'>")
            .append(" (")
            .append(htmlEscape(item.notes))
            .append(")")
            .append("</span>");
      }

      html.append("</div>");
      html.append("</div>");
    }

    html.append("</section>");
  }

  static void appendSectionInjury(
    NativePreviewHtmlBuffer html,
    List<DynamicPreviewSectionItem> items,
  ) {
    if (items.isEmpty) {
      return;
    }

    html.append("<section class='section'>");

    html
        .append("<div class='section-title'>")
        .append(htmlEscape("Injury"))
        .append("</div>");

    html.append("<div class='section-item'>");
    html.append("<span class='bullet'></span>");
    html.append("<div class='item-body'>");
    for (int i = 0; i < items.length; i++) {
      DynamicPreviewSectionItem item = items[i];
      html.append(htmlEscape(item.text));
      if (i != items.length - 1) {
        html.append(", ");
      }
    }
    html.append("</div>");
    html.append("</div>");
    html.append("</section>");
  }

  static void appendObjectives(
    NativePreviewHtmlBuffer html,
    List<DynamicPreviewObjectiveItem> items,
  ) {
    if (items.isEmpty) {
      return;
    }

    html.append("<section class='section'>");
    html.append("<div class='section-title'>Objective Assessment</div>");

    for (final item in items) {
      NativePreviewHtmlBuffer objectiveText = NativePreviewHtmlBuffer();

      objectiveText.append(item.objectiveName);

      if (item.hasObjectiveValue) {
        if (objectiveText.length > 0) {
          objectiveText.append(": ");
        }

        objectiveText.append(item.objectiveValue);
      }

      if (item.hasMuscleJoint) {
        if (objectiveText.length > 0) {
          objectiveText.append(" - ");
        }

        objectiveText.append(item.muscleJointName);
      }

      if (item.hasNotes) {
        if (objectiveText.length > 0) {
          objectiveText.append(" - ");
        }

        objectiveText.append(item.notes);
      }

      if (objectiveText.length > 0) {
        html.append("<div class='section-item'>");
        html.append("<span class='bullet'></span>");

        html
            .append("<div class='item-body'>")
            .append(htmlEscape(objectiveText.toString()))
            .append("</div>");

        html.append("</div>");
      }
    }

    html.append("</section>");
  }

  static void appendMedications(
    NativePreviewHtmlBuffer html,
    List<DynamicPreviewMedicationItem> items,
  ) {
    if (items.isEmpty) {
      return;
    }

    html.append("<section class='section'>");
    html.append("<div class='section-title'>Medication</div>");

    int medicineSerial = 1;

    for (final item in items) {
      html.append("<div class='medicine-card-new'>");

      html
          .append("<span class='medicine-serial-new'>")
          .append(medicineSerial)
          .append(".</span>");

      html.append("<div class='medicine-content-new'>");

      html
          .append("<div class='medicine-name-new'>")
          .append(htmlEscape(item.medicineName))
          .append("</div>");

      html.append("<div class='medicine-meta-new'>");

      appendMedicationMeta(html, item.doseName);

      appendMedicationMeta(html, item.timingName);

      appendMedicationMeta(html, item.routeName);

      if (item.hasDuration) {
        html
            .append("<span class='medicine-duration-new'>")
            .append(htmlEscape(item.duration))
            .append(" days")
            .append("</span>");
      }

      if (item.hasNotes) {
        html
            .append("<span class='medicine-notes-new'>")
            .append("Note: ")
            .append(htmlEscape(item.notes))
            .append("</span>");
      }

      html.append("</div>");
      html.append("</div>");
      html.append("</div>");

      medicineSerial++;
    }

    html.append("</section>");
  }

  static void appendMedicationMeta(NativePreviewHtmlBuffer html, String value) {
    if (value.isNotEmpty) {
      html.append("<span>").append(htmlEscape(value)).append("</span>");
    }
  }

  static void appendSpecialAlerts(
    NativePreviewHtmlBuffer html,
    List<DynamicPreviewSectionItem> items,
  ) {
    if (items.isEmpty) {
      return;
    }

    html.append("<section class='special-alert'>");
    html.append("<div class='alert-title'>Special Alert</div>");

    for (final item in items) {
      html.append("<div class='alert-item'>").append(htmlEscape(item.text));

      if (item.hasNotes) {
        html.append(" - ").append(htmlEscape(item.notes));
      }

      html.append("</div>");
    }

    html.append("</section>");
  }

  static void appendReferenceAndSignature(
    NativePreviewHtmlBuffer html,
    DynamicPrescriptionPreviewData data,
  ) {
    String patientReference = data.patient.reference;

    bool hasPatientReference = patientReference.isNotEmpty;

    bool hasPrescriptionReference = data.reference.isNotEmpty;

    bool hasPrescriptionNotes = data.notes.isNotEmpty;

    html.append("<section class='bottom-info'>");
    html.append("<div>");

    if (hasPatientReference ||
        hasPrescriptionReference ||
        hasPrescriptionNotes) {
      html
          .append("<div class='reference-title'>")
          .append("Reference / Notes")
          .append("</div>");

      if (hasPatientReference) {
        html.append("<div class='reference-value'>");
        html.append("Referred by: ").append(htmlEscape(patientReference));
        html.append("</div>");
      }

      if (hasPrescriptionReference) {
        html.append("<div class='reference-extra-value'>");
        html
            .append("Doctor/Therapist Reference: ")
            .append(htmlEscape(data.reference));
        html.append("</div>");
      }

      if (hasPrescriptionNotes) {
        html.append("<div class='reference-extra-value'>");
        html.append("Doctor/Therapist Notes: ").append(htmlEscape(data.notes));
        html.append("</div>");
      }
    }

    html.append("</div>");

    DynamicPreviewProvider provider = data.provider;

    html.append("<div class='signature'>");

    html
        .append("<div class='signature-name'>")
        .append(
          htmlEscape(
            valueOrDefault(provider.doctorName, "Prescribing Clinician"),
          ),
        )
        .append("</div>");

    if (provider.designation.isNotEmpty) {
      html
          .append("<div class='signature-detail'>")
          .append(htmlEscape(provider.designation))
          .append("</div>");
    }

    String workplace = joinNonEmpty(provider.unit, provider.department, ", ");

    if (workplace.isNotEmpty) {
      html
          .append("<div class='signature-detail'>")
          .append(htmlEscape(workplace))
          .append("</div>");
    }

    html.append("</div>");
    html.append("</section>");
  }

  static void appendFooter(
    NativePreviewHtmlBuffer html,
    DynamicPreviewFacility facility,
    DateTime printedAt,
  ) {
    List<String> facilityInformation = <String>[];

    addIfNotEmpty(facilityInformation, facility.details, "");
    addIfNotEmpty(facilityInformation, facility.phone, "Mobile: ");
    addIfNotEmpty(facilityInformation, facility.cell, "Phone: ");
    addIfNotEmpty(facilityInformation, facility.email, "Email: ");
    addIfNotEmpty(facilityInformation, facility.website, "Web: ");

    html.append("<footer class='footer'>");

    if (facilityInformation.isNotEmpty) {
      html.append(htmlEscape(join(facilityInformation, "  |  ")));

      html.append("<br>");
    }

    html.append("Digitally generated prescription");
    html.append("  |  Printed: ");
    html.append(htmlEscape(getPrintedTime(printedAt)));
    html.append("  |  Page 1 of 1");

    html.append("</footer>");
  }

  static bool hasLeftContent(DynamicPrescriptionPreviewData data) {
    return data.complaints.isNotEmpty ||
        data.injuries.isNotEmpty ||
        data.diagnosis.isNotEmpty ||
        data.objectiveInfo.isNotEmpty ||
        data.clinicalFindings.isNotEmpty ||
        data.drugHistory.isNotEmpty ||
        data.investigations.isNotEmpty ||
        data.importantInfo.isNotEmpty;
  }

  static bool hasRightContent(DynamicPrescriptionPreviewData data) {
    return data.medications.isNotEmpty ||
        data.therapies.isNotEmpty ||
        data.treatmentPlans.isNotEmpty ||
        data.advice.isNotEmpty ||
        data.followups.isNotEmpty ||
        data.specialAlerts.isNotEmpty;
  }

  static String buildCategoryType(DynamicPrescriptionPreviewData data) {
    List<String> values = <String>[];

    addIfNotEmpty(values, data.patient.category, "");

    String visitType = joinNonEmpty(
      data.patientType,
      data.prescriptionType,
      " - ",
    );

    addIfNotEmpty(values, visitType, "");

    return join(values, " | ");
  }

  static String getDepartmentTitle(DynamicPreviewProvider provider) {
    String unit;

    if (provider.department.isNotEmpty) {
      unit = provider.department;
    } else {
      unit = "Department of Rehabilitation Services";
    }

    return unit;
  }

  static String buildBloodPressure(DynamicPreviewVitals vitals) {
    String systolic = vitals.systolic;

    String diastolic = vitals.diastolic;

    if (systolic.isEmpty && diastolic.isEmpty) {
      return "";
    }

    if (systolic.isEmpty) {
      return "-/$diastolic";
    }

    if (diastolic.isEmpty) {
      return "$systolic/-";
    }

    return "$systolic/$diastolic";
  }

  static String buildFacilityContact(DynamicPreviewFacility facility) {
    List<String> values = <String>[];

    addIfNotEmpty(values, facility.phone, "Mobile: ");
    addIfNotEmpty(values, facility.cell, "Phone: ");
    addIfNotEmpty(values, facility.email, "Email: ");
    addIfNotEmpty(values, facility.website, "Web: ");

    return join(values, "  |  ");
  }

  static String getPrintedTime(DateTime time) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.day)} ${months[time.month - 1]} ${time.year}, ${two(time.hour % 12 == 0 ? 12 : time.hour % 12)}:${two(time.minute)} ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  static String getLogoDataUri(String logo) {
    final value = logo.replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty || value.startsWith('data:image/')) return value;
    final mime =
        value.startsWith('/9j/')
            ? 'image/jpeg'
            : value.startsWith('R0lGOD')
            ? 'image/gif'
            : value.startsWith('PHN2Zy')
            ? 'image/svg+xml'
            : 'image/png';
    return 'data:$mime;base64,$value';
  }

  static String normalizeColor(String value, String fallback) {
    final color = value.trim();
    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) return color;
    if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(color)) return '#$color';
    return fallback;
  }

  static String mixWithWhite(String color, double ratio) {
    // Java uses float arithmetic before Math.round.
    double f32(double n) => (Float32List(1)..[0] = n)[0];
    try {
      final r = f32(ratio);
      return '#${[1, 3, 5].map((offset) {
        final value = int.parse(color.substring(offset, offset + 2), radix: 16);
        return f32(value + f32((255 - value) * r)).round().toRadixString(16).padLeft(2, '0').toUpperCase();
      }).join()}';
    } catch (_) {
      return '#EAF6F0';
    }
  }

  static void addIfNotEmpty(List<String> values, String value, String prefix) {
    if (value.isNotEmpty) values.add(prefix + value);
  }

  static String join(List<String> values, String separator) =>
      values.join(separator);
  static String joinNonEmpty(String first, String second, String separator) =>
      first.isEmpty
          ? second
          : second.isEmpty
          ? first
          : first + separator + second;
  static String valueOrDefault(String value, String fallback) =>
      value.isEmpty ? fallback : value;
  static String htmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

// Java StringBuilder's chaining is retained to keep the native HTML port auditable.
class NativePreviewHtmlBuffer {
  final _value = StringBuffer();
  NativePreviewHtmlBuffer append(Object value) {
    _value.write(value);
    return this;
  }

  int get length => _value.length;
  @override
  String toString() => _value.toString();
}
