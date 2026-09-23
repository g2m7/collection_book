/**
 * Reference Cloudflare Edge Worker (Bun Runtime Standard)
 * Handles Razorpay Order Creation and Webhook Verification.
 * 
 * Execution:
 *   bun run payment-worker-reference.ts
 */

interface Env {
  RAZORPAY_KEY_ID: string;
  RAZORPAY_KEY_SECRET: string;
  RAZORPAY_WEBHOOK_SECRET: string;
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

          // Dispatch mutation to Convex backend
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
            console.error("Convex mutation failed", await convexResponse.text());
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
