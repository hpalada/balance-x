import cors from "cors";
import dotenv from "dotenv";
import express from "express";
import { createClient } from "@supabase/supabase-js";

dotenv.config();

const {
    GEMINI_API_KEY,
    GOOGLE_API_KEY,
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    PORT = "3000",
} = process.env;

const apiKey = GEMINI_API_KEY || GOOGLE_API_KEY;

if (!apiKey) {
    throw new Error("Missing GEMINI_API_KEY");
}

if (!SUPABASE_URL) {
    throw new Error("Missing SUPABASE_URL");
}

if (!SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error("Missing SUPABASE_SERVICE_ROLE_KEY");
}

const app = express();
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
        persistSession: false,
        autoRefreshToken: false,
    },
});
const geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

app.use(cors());
app.use(express.json({ limit: "2mb" }));

app.get("/health", (_req, res) => {
    res.status(200).json({ ok: true });
});

app.post("/scan-receipt", async (req, res) => {
    try {
        const { imageUrl, company_id: companyId } = req.body ?? {};

        const validationError = validateRequest(imageUrl, companyId);
        if (validationError) {
            return res.status(400).json({ error: validationError });
        }

        const extraction = await extractReceiptWithOpenAI(imageUrl);
        const normalized = normalizeReceiptExtraction(extraction);

        const transaction = await insertTransaction({
            companyId,
            amount: normalized.amount,
            vendor: normalized.vendor,
            date: normalized.date,
        });

        const receipt = await insertReceipt({
            transactionId: transaction.id,
            imageUrl,
            amount: normalized.amount,
            vendor: normalized.vendor,
            date: normalized.date,
        });

        return res.status(201).json({
            vendor: normalized.vendor,
            amount: normalized.amount,
            date: normalized.date,
            transactionId: transaction.id,
            receiptId: receipt.id,
        });
    } catch (error) {
        console.error("[POST /scan-receipt]", error);

        if (error instanceof AppError) {
            return res.status(error.statusCode).json({ error: error.message });
        }

        return res.status(500).json({ error: "Internal server error" });
    }
});

app.listen(Number(PORT), "0.0.0.0", () => {
    console.log(`Receipt API listening on http://0.0.0.0:${PORT}`);
});

function validateRequest(imageUrl, companyId) {
    if (!imageUrl || typeof imageUrl !== "string") {
        return "imageUrl is required and must be a string.";
    }

    if (!companyId || typeof companyId !== "string") {
        return "company_id is required and must be a UUID string.";
    }

    if (!isValidHttpUrl(imageUrl)) {
        return "imageUrl must be a valid http or https URL.";
    }

    if (!isUuid(companyId)) {
        return "company_id must be a valid UUID.";
    }

    return null;
}

async function extractReceiptWithOpenAI(imageUrl) {
    const { mimeType, base64Data } = await fetchImageAsBase64(imageUrl);
    const response = await fetch(geminiEndpoint, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
            contents: [
                {
                    parts: [
                        {
                            text: [
                                "Extract:",
                                "- vendor name",
                                "- total amount",
                                "- date",
                                "",
                                "Return ONLY JSON:",
                                "{",
                                '  "vendor": "",',
                                '  "amount": 0,',
                                '  "date": "YYYY-MM-DD"',
                                "}",
                            ].join("\n"),
                        },
                        {
                            inline_data: {
                                mime_type: mimeType,
                                data: base64Data,
                            },
                        },
                    ],
                },
            ],
            generationConfig: {
                temperature: 0.1,
                responseMimeType: "application/json",
            },
        }),
    });

    if (!response.ok) {
        throw new AppError(502, `Gemini request failed with status ${response.status}.`);
    }

    const payload = await response.json();
    const rawText = extractText(payload)?.trim();
    if (!rawText) {
        throw new AppError(502, "Gemini returned an empty response.");
    }

    let parsed;
    try {
        parsed = JSON.parse(rawText);
    } catch {
        throw new AppError(502, "Gemini returned invalid JSON.");
    }

    return parsed;
}

function normalizeReceiptExtraction(payload) {
    const vendor = typeof payload?.vendor === "string" ? payload.vendor.trim() : "";
    const amount = Number(payload?.amount);
    const date = typeof payload?.date === "string" ? payload.date.trim() : "";

    if (!vendor) {
        throw new AppError(422, "Missing vendor in OCR response.");
    }

    if (!Number.isFinite(amount) || amount <= 0) {
        throw new AppError(422, "Missing or invalid amount in OCR response.");
    }

    if (!isIsoDate(date)) {
        throw new AppError(422, "Missing or invalid date in OCR response. Expected YYYY-MM-DD.");
    }

    return {
        vendor,
        amount,
        date,
    };
}

async function insertTransaction({ companyId, amount, vendor, date }) {
    const { data, error } = await supabase
        .from("transactions")
        .insert({
            company_id: companyId,
            type: "expense",
            amount,
            vendor,
            category: "Uncategorized",
            date,
        })
        .select("id, company_id, type, amount, vendor, category, date, created_at")
        .single();

    if (error) {
        throw new AppError(500, `Failed to insert transaction: ${error.message}`);
    }

    return data;
}

async function insertReceipt({ transactionId, imageUrl, amount, vendor, date }) {
    const { data, error } = await supabase
        .from("receipts")
        .insert({
            transaction_id: transactionId,
            image_url: imageUrl,
            vendor,
            amount,
            date,
        })
        .select("id, transaction_id, image_url, vendor, amount, date, created_at")
        .single();

    if (error) {
        throw new AppError(500, `Failed to insert receipt: ${error.message}`);
    }

    return data;
}

function isValidHttpUrl(value) {
    try {
        const url = new URL(value);
        return url.protocol === "http:" || url.protocol === "https:";
    } catch {
        return false;
    }
}

function isUuid(value) {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function isIsoDate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return false;
    }

    const parsed = new Date(`${value}T00:00:00.000Z`);
    return !Number.isNaN(parsed.getTime());
}

async function fetchImageAsBase64(imageUrl) {
    const response = await fetch(imageUrl);
    if (!response.ok) {
        throw new AppError(502, `Failed to download image. Status ${response.status}.`);
    }

    const mimeType = response.headers.get("content-type") || "image/jpeg";
    const arrayBuffer = await response.arrayBuffer();
    return {
        mimeType,
        base64Data: Buffer.from(arrayBuffer).toString("base64"),
    };
}

function extractText(payload) {
    const parts = payload?.candidates?.[0]?.content?.parts;
    if (!Array.isArray(parts)) {
        return null;
    }

    const textPart = parts.find((part) => typeof part?.text === "string");
    return typeof textPart?.text === "string" ? textPart.text : null;
}

class AppError extends Error {
    constructor(statusCode, message) {
        super(message);
        this.statusCode = statusCode;
    }
}
