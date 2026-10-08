/**
 * Murakabe — topluluk mesaj bildirimlerini (reports) sahibine e-postayla iletir.
 *
 * Tetikleyici: communities/{communityId}/reports/{reportId} oluşturulduğunda.
 * Gönderim: Gmail SMTP + uygulama şifresi (App Password).
 *
 * Ayarlar (kodda e-posta/şifre YOK, deploy sırasında girilir):
 *   REPORT_MAIL_USER  → gönderen Gmail adresi        (param, .env.<proje> dosyasında)
 *   REPORT_MAIL_TO    → bildirimlerin gideceği adres  (param)
 *   REPORT_MAIL_PASS  → Gmail uygulama şifresi        (Secret Manager)
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

const MAIL_USER = defineString("REPORT_MAIL_USER");
const MAIL_TO = defineString("REPORT_MAIL_TO");
const MAIL_PASS = defineSecret("REPORT_MAIL_PASS");

function escapeHtml(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** E-posta içeriğini üretir (saf fonksiyon — test edilebilir). */
function buildMail(report, communityName, communityId, reportId) {
  const name = report.reportedName || "Bilinmeyen kullanıcı";
  const reason = report.reason || "-";
  const text = report.messageText || "";
  const when = report.createdAt && report.createdAt.toDate
    ? report.createdAt.toDate().toLocaleString("tr-TR", { timeZone: "Europe/Istanbul" })
    : new Date().toLocaleString("tr-TR", { timeZone: "Europe/Istanbul" });

  const subject = `[Murakabe] Mesaj bildirimi: ${reason} (${communityName})`
    .replace(/[\r\n]+/g, " ")
    .slice(0, 180);

  const plain =
    `Toplulukta bir mesaj bildirildi.\n\n` +
    `Topluluk: ${communityName} (${communityId})\n` +
    `Sebep: ${reason}\n` +
    `Bildirilen kişi: ${name} (UID: ${report.reportedUid || "-"})\n` +
    `Bildiren UID: ${report.reporterUid || "-"}\n` +
    `Zaman: ${when}\n\n` +
    `Mesaj:\n${text}\n\n` +
    `Bildirim kimliği: ${reportId}\n` +
    `İşlem: Uygulamada topluluk yönetim paneli → Bildirimler sekmesi.`;

  const html =
    `<div style="font-family:Arial,sans-serif;font-size:14px;color:#17223A;max-width:560px">` +
    `<h2 style="margin:0 0 12px;font-size:18px">Toplulukta bir mesaj bildirildi</h2>` +
    `<table style="border-collapse:collapse;margin-bottom:14px">` +
    `<tr><td style="padding:3px 12px 3px 0;color:#6B7689">Topluluk</td><td><b>${escapeHtml(communityName)}</b></td></tr>` +
    `<tr><td style="padding:3px 12px 3px 0;color:#6B7689">Sebep</td><td><b style="color:#A23D2B">${escapeHtml(reason)}</b></td></tr>` +
    `<tr><td style="padding:3px 12px 3px 0;color:#6B7689">Bildirilen kişi</td><td>${escapeHtml(name)} <span style="color:#6B7689">(${escapeHtml(report.reportedUid)})</span></td></tr>` +
    `<tr><td style="padding:3px 12px 3px 0;color:#6B7689">Bildiren</td><td style="color:#6B7689">${escapeHtml(report.reporterUid)}</td></tr>` +
    `<tr><td style="padding:3px 12px 3px 0;color:#6B7689">Zaman</td><td>${escapeHtml(when)}</td></tr>` +
    `</table>` +
    `<div style="background:#F4F7F6;border-left:3px solid #A23D2B;padding:10px 14px;white-space:pre-wrap">${escapeHtml(text)}</div>` +
    `<p style="color:#6B7689;font-size:12px;margin-top:16px">İşlem yapmak için: uygulamada topluluk yönetim paneli → Bildirimler sekmesi.<br>` +
    `Topluluk: ${escapeHtml(communityId)} · Bildirim: ${escapeHtml(reportId)}</p></div>`;

  return { subject, text: plain, html };
}

exports.onMessageReported = onDocumentCreated(
  {
    document: "communities/{communityId}/reports/{reportId}",
    region: "europe-west3", // Firestore veritabanıyla aynı bölge
    secrets: [MAIL_PASS],
    maxInstances: 2,
    retry: false,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const report = snap.data() || {};
    const { communityId, reportId } = event.params;

    let communityName = communityId;
    try {
      const c = await admin.firestore().collection("communities").doc(communityId).get();
      communityName = (c.exists && c.get("name")) || communityId;
    } catch (e) {
      logger.warn("Topluluk adı okunamadı", e);
    }

    const mail = buildMail(report, communityName, communityId, reportId);
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: { user: MAIL_USER.value(), pass: MAIL_PASS.value() },
    });

    try {
      await transporter.sendMail({
        from: `"Murakabe Bildirim" <${MAIL_USER.value()}>`,
        to: MAIL_TO.value(),
        subject: mail.subject,
        text: mail.text,
        html: mail.html,
      });
      logger.info("Bildirim e-postası gönderildi", { communityId, reportId });
    } catch (e) {
      logger.error("Bildirim e-postası gönderilemedi", e);
    }
  }
);

exports._buildMail = buildMail; // yalnızca test için
