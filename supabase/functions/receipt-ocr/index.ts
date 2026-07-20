// Supabase Edge Function: receipt-ocr
// Called by accounting.html when staff attach a receipt photo while adding an expense.
// Sends the photo to Claude (vision) and asks for a structured line-item breakdown
// (item name / quantity / unit price / category guess per line), which the frontend
// uses to prefill the expense-items form. Staff always review/edit before saving —
// this function only ever proposes a prefill, it never writes to the database itself.
//
// Requires a logged-in staff session (Supabase email/password) — see the
// auth.getUser() check below. The anon key alone is not enough to call this
// (it costs real money per call against the Anthropic API).

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const EXPENSE_CATEGORY_KEYS = [
  "equipment_depreciation",
  "decor_depreciation",
  "utilities",
  "internet",
  "pos_subscription",
  "advertising",
  "consumables_overhead",
  "owner_labor",
  "raw_materials",
  "packaging",
  "cleaning_supplies",
  "maintenance_repair",
  "other",
];

const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
    if (authError || !user) {
      return jsonResponse({ ok: false, error: "staff login required" }, 401);
    }

    const { image_base64, media_type } = await req.json();
    if (!image_base64 || !media_type) {
      return jsonResponse({ ok: false, error: "missing image_base64 or media_type" }, 400);
    }

    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!anthropicKey) {
      console.error("ANTHROPIC_API_KEY not set");
      return jsonResponse({ ok: false, error: "OCR ยังไม่พร้อมใช้งาน (ไม่มี API key) กรุณากรอกเอง" });
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);

    let anthropicRes: Response;
    try {
      anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        signal: controller.signal,
        headers: {
          "x-api-key": anthropicKey,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: ANTHROPIC_MODEL,
          max_tokens: 1536,
          tool_choice: { type: "tool", name: "extract_receipt" },
          tools: [
            {
              name: "extract_receipt",
              description:
                "Extract a line-item breakdown from a Thai shop receipt photo for a small coffee shop's expense tracking.",
              input_schema: {
                type: "object",
                properties: {
                  vendor_guess: {
                    type: ["string", "null"],
                    description: "Store/vendor name printed on the receipt, if visible",
                  },
                  expense_date: {
                    type: ["string", "null"],
                    description: "Date on the receipt as ISO YYYY-MM-DD, if visible. Convert Thai Buddhist Era years (พ.ศ.) to Gregorian (ค.ศ.) by subtracting 543.",
                  },
                  confidence: {
                    type: "string",
                    enum: ["high", "medium", "low"],
                    description: "Overall confidence that the extracted items and prices are accurate",
                  },
                  items: {
                    type: "array",
                    description: "One entry per distinct line item on the receipt. Empty array if the receipt is unreadable.",
                    items: {
                      type: "object",
                      properties: {
                        item_name: { type: "string" },
                        quantity: { type: "number" },
                        unit_price: { type: "number", description: "Price per unit in THB, not the line total" },
                        category_guess: { type: "string", enum: EXPENSE_CATEGORY_KEYS },
                      },
                      required: ["item_name", "quantity", "unit_price", "category_guess"],
                    },
                  },
                },
                required: ["items", "confidence"],
              },
            },
          ],
          messages: [
            {
              role: "user",
              content: [
                { type: "image", source: { type: "base64", media_type, data: image_base64 } },
                {
                  type: "text",
                  text:
                    "This is a receipt from a purchase for a small Thai coffee shop (Buddy Brew). " +
                    "Extract every line item you can read (item name, quantity, unit price) and guess the " +
                    "best matching expense category per item. If unit price isn't printed but a line total is, " +
                    "divide by quantity to get unit price. If you truly cannot read the receipt, return an empty " +
                    "items array with confidence 'low'.",
                },
              ],
            },
          ],
        }),
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!anthropicRes.ok) {
      const errText = await anthropicRes.text();
      console.error("Anthropic API error:", anthropicRes.status, errText);
      return jsonResponse({ ok: false, error: "OCR service error, please enter manually" });
    }

    const anthropicJson = await anthropicRes.json();
    const toolUse = (anthropicJson.content ?? []).find((b: { type: string }) => b.type === "tool_use");
    if (!toolUse) {
      console.error("no tool_use block in Anthropic response:", JSON.stringify(anthropicJson));
      return jsonResponse({ ok: true, items: [], confidence: "low", warning: "อ่านใบเสร็จไม่ชัด กรุณากรอกเอง" });
    }

    const extracted = toolUse.input ?? {};
    return jsonResponse({
      ok: true,
      vendor_guess: extracted.vendor_guess ?? null,
      expense_date: extracted.expense_date ?? null,
      confidence: extracted.confidence ?? "low",
      items: Array.isArray(extracted.items) ? extracted.items : [],
      warning: (extracted.items ?? []).length === 0 ? "อ่านใบเสร็จไม่ชัด กรุณากรอกเอง" : null,
    });
  } catch (err) {
    console.error("unhandled error:", err);
    return jsonResponse({ ok: false, error: "OCR service error, please enter manually" });
  }
});
