import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import PDFDocument from "pdfkit";
import { createWriteStream, promises as fs } from "fs";
import { tmpdir } from "os";
import { join } from "path";

export interface ExportEntry {
  text: string;
  createdAt?: Date | null;
}

export interface GeneratePdfOptions {
  uid: string;
  entries: ExportEntry[];
  displayName?: string | null;
  phoneNumber?: string | null;
}

export interface GeneratePdfResult {
  storagePath: string;
  signedUrl: string;
}

function formatDate(date: Date | null | undefined) {
  if (!date) {
    return "Unknown date";
  }

  try {
    return new Intl.DateTimeFormat("en-US", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(date);
  } catch (err) {
    logger.warn("exportHistoryPdf.formatDate failed, falling back", err as Error);
    return date.toISOString();
  }
}

function resolveRecipientLabel(displayName?: string | null, phoneNumber?: string | null) {
  if (displayName && displayName.trim().length > 0) {
    return displayName.trim();
  }
  if (phoneNumber && phoneNumber.trim().length > 0) {
    return phoneNumber.trim();
  }
  return "ReMind user";
}

export async function generatePdf(options: GeneratePdfOptions): Promise<GeneratePdfResult> {
  const { uid, entries, displayName, phoneNumber } = options;
  if (!uid) {
    throw new Error("generatePdf requires a uid");
  }
  if (!Array.isArray(entries) || entries.length === 0) {
    throw new Error("generatePdf requires at least one entry");
  }

  const tmpPath = join(tmpdir(), `remind-export-${uid}-${Date.now()}.pdf`);
  const doc = new PDFDocument({ margin: 56, size: "LETTER" });
  const stream = createWriteStream(tmpPath);
  doc.pipe(stream);

  const recipientLabel = resolveRecipientLabel(displayName, phoneNumber);
  const generatedAt = new Date();

  // Title page
  doc.fontSize(28).fillColor("#000000").text("ReMind Export", { align: "center" });
  doc.moveDown();
  doc.fontSize(16).fillColor("#444444").text(recipientLabel, { align: "center" });
  doc.moveDown();
  doc.fontSize(12).text(`Generated on ${formatDate(generatedAt)}`, { align: "center" });

  if (entries.length > 3) {
    doc.moveDown(2);
    doc.fontSize(12).fillColor("#666666").text("Entries included", { align: "center" });
    doc.fontSize(10).moveDown();
    entries.slice(0, 10).forEach((entry, index) => {
      doc.text(`${index + 1}. ${entry.text.slice(0, 80)}${entry.text.length > 80 ? "…" : ""}`, {
        align: "left",
        indent: 24,
      });
    });
    if (entries.length > 10) {
      doc.text(`…and ${entries.length - 10} more entries`, { indent: 24 });
    }
  }

  doc.addPage();

  entries.forEach((entry, index) => {
    const timestamp = formatDate(entry.createdAt ?? null);

    doc.fontSize(12).fillColor("#1f2937").text(timestamp, { continued: false });
    doc.moveDown(0.5);
    doc.fontSize(14).fillColor("#111827").text(entry.text, {
      align: "left",
      lineGap: 4,
    });

    if (index < entries.length - 1) {
      doc.moveDown();
      const { page } = doc;
      const startX = page.margins.left;
      const endX = page.width - page.margins.right;
      const y = doc.y;
      doc.moveTo(startX, y).lineTo(endX, y).lineWidth(0.5).stroke("#d1d5db");
      doc.moveDown();
    }

    if (doc.y > doc.page.height - doc.page.margins.bottom - 80) {
      doc.addPage();
    }
  });

  const streamFinished = new Promise<void>((resolve, reject) => {
    stream.on("finish", () => resolve());
    stream.on("error", (error) => reject(error));
    doc.on("error", (error) => reject(error));
  });

  doc.end();

  await streamFinished;

  const storage = getStorage();
  const bucket = storage.bucket();
  const iso = new Date().toISOString().replace(/[:]/g, "-");
  const storagePath = `exports/${uid}/${iso}.pdf`;

  await bucket.upload(tmpPath, {
    destination: storagePath,
    metadata: {
      contentType: "application/pdf",
      cacheControl: "no-store",
    },
  });

  await fs.unlink(tmpPath).catch((error) => {
    logger.warn("Failed to remove temporary PDF", { error });
  });

  const file = bucket.file(storagePath);
  const expires = Date.now() + 24 * 60 * 60 * 1000;
  const [signedUrl] = await file.getSignedUrl({
    action: "read",
    expires,
    version: "v4",
  });

  return { storagePath, signedUrl };
}
