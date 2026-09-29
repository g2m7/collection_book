/**
 * Reference Cloudflare Edge Worker (Bun Runtime Standard)
 * Handles Razorpay Order Creation and Webhook Verification.
 *
 * Execution:
 *   bun run payment-worker-reference.ts
 *
 * NON-NORMATIVE — BLOCKED BY GATE 1 (added by the cloud-authoritative SaaS pivot):
 *   This is a PROVISIONAL design reference, not deployed code, not an implementation
 *   contract, and not selectable against a real backend. The edge gateway and the
 *   Razorpay HMAC webhook seam remain valid and provider-neutral.
 *
 *   The `CONVEX_URL` / `CONVEX_ADMIN_KEY` bindings, the `organizations:upgradePlan
 *   FromPayment` mutation, and every "Convex" name below are NON-NORMATIVE
 *   PLACEHOLDERS: no backend vendor is selected or approved. That decision is Gate 1 of
 *   docs/plans/cloud-authoritative-offline-first-saas/plan.md (§11) and it is still
 *   open. Do not implement this, do not copy these vendor-specific bindings into
 *   services/cbk-edge, and do not treat the mutation path below as an API contract.
 *
 *   Do not close the gap by inventing a generic or vendor-neutral "mutate the plan"
 *   endpoint here. Until the vendor is selected, the post-payment plan-state write is
 *   undefined on purpose; re-derive it from the recorded Gate 1 decision.
 *
 *   The hardcoded tier prices below are also undecided placeholders: the commercial
 *   gate (Gate 13, §11) decides any price, and no price, tier, or "free" wording may
 *   reach customer-facing copy before then.
 */

interface Env {
  RAZORPAY_KEY_ID: string;
  RAZORPAY_KEY_SECRET: string;
  RAZORPAY_WEBHOOK_SECRET: string;
  // NON-NORMATIVE placeholders: the backend vendor is unselected (Gate 1). These
  // binding names are not a selection and not a contract.
  CONVEX_URL: string;
  CONVEX_ADMIN_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Health check
    if (url.pathname === "/health") {
      return new Response(JSON.stringify({ status: "healthy", runtime: "bun" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 1. Create UPI Order Endpoint
    if (request.method === "POST" && url.pathname === "/api/v1/checkout/create-order") {
      try {
        const body = (await request.json()) as {
          orgId: string;
          phone: string;
          tier: "starter" | "pro";
          billingCycle: "monthly" | "annual";
        };

        const amountInPaise =
          body.tier === "starter"
            ? body.billingCycle === "annual"
              ? 149900
              : 19900
            : body.billingCycle === "annual"
            ? 249900
            : 34900;

        const authHeader = "Basic " + btoa(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`);
        const rzpResponse = await fetch("https://api.razorpay.com/v1/orders", {
          method: "POST",
          headers: {
            Authorization: authHeader,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            amount: amountInPaise,
            currency: "INR",
            receipt: `rcpt_${Date.now()}`,
            notes: {
              orgId: body.orgId,
              phone: body.phone,
              tier: body.tier,
              billingCycle: body.billingCycle,
            },
          }),
        });

        if (!rzpResponse.ok) {
          const err = await rzpResponse.text();
          return new Response(JSON.stringify({ error: "Failed to create order", details: err }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
          });
        }

        const orderData = (await rzpResponse.json()) as { id: string; amount: number; currency: string };

        // Construct UPI intent string
        const note = `${body.tier.toUpperCase()}_${body.billingCycle.toUpperCase()}`;
        const upiUri = `upi://pay?pa=collectionbook@icici&pn=CollectionBook&am=${(orderData.amount / 100).toFixed(
          2
        )}&cu=INR&tn=${note}&tr=${orderData.id}`;

        return new Response(
          JSON.stringify({
            success: true,
            orderId: orderData.id,
            amountInPaise: orderData.amount,
            currency: orderData.currency,
            razorpayKey: env.RAZORPAY_KEY_ID,
            upiIntentUri: upiUri,
          }),
          { headers: { "Content-Type": "application/json" } }
        );
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        return new Response(JSON.stringify({ error: message }), { status: 400 });
      }
    }

    // 2. Razorpay Webhook Endpoint
    if (request.method === "POST" && url.pathname === "/api/v1/checkout/webhook") {
      try {
        const signature = request.headers.get("x-razorpay-signature");
        if (!signature) {
          return new Response("Missing signature", { status: 400 });
        }

        const rawBody = await request.text();

        // Verify HMAC SHA-256 Signature using Web Crypto
        const encoder = new TextEncoder();
        const keyData = encoder.encode(env.RAZORPAY_WEBHOOK_SECRET);
        const cryptoKey = await crypto.subtle.importKey(
          "raw",
          keyData,
          { name: "HMAC", hash: "SHA-256" },
          false,
          ["sign"]
        );

        const signatureBuffer = await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(rawBody));
        const expectedSignature = Array.from(new Uint8Array(signatureBuffer))
          .map((b) => b.toString(16).padStart(2, "0"))
          .join("");

        if (signature !== expectedSignature) {
          return new Response("Invalid signature", { status: 403 });
        }

        const event = JSON.parse(rawBody);

        if (event.event === "payment.captured") {
          const payment = event.payload.payment.entity;
          const notes = payment.notes;

          // BLOCKED BY GATE 1 — the backend vendor is unselected, so the shape of the
          // post-payment plan-state write is undefined. The mutation call below is a
          // NON-NORMATIVE Convex placeholder, not an API contract: do not implement it,
          // and do not generalize it into a vendor-neutral endpoint. Re-derive it from
          // the recorded Gate 1 decision. Entitlements themselves are server-side and
          // are bound at the commercial gate (Gate 13).
          const convexResponse = await fetch(`${env.CONVEX_URL}/api/mutation`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${env.CONVEX_ADMIN_KEY}`,
            },
            body: JSON.stringify({
              path: "organizations:upgradePlanFromPayment",
              args: {
                orgId: notes.orgId,
                paymentId: payment.id,
                orderId: payment.order_id,
                amount: payment.amount,
                tier: notes.tier,
                billingCycle: notes.billingCycle,
              },
            }),
          });

          if (!convexResponse.ok) {
            console.error("Plan-state update failed", await convexResponse.text());
          }
        }

        return new Response(JSON.stringify({ status: "acknowledged" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        return new Response(JSON.stringify({ error: message }), { status: 500 });
      }
    }

    return new Response("Not Found", { status: 404 });
  },
};
