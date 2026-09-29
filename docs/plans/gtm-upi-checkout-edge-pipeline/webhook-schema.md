# Razorpay Webhook & Edge Request/Response Schemas

> ## NON-NORMATIVE — BLOCKED BY GATE 1
>
> **Status: provisional design draft, not an implemented contract, and not selectable
> against a real backend.** The backend vendor decision is **Gate 1** of
> [`../cloud-authoritative-offline-first-saas/plan.md`](../cloud-authoritative-offline-first-saas/plan.md)
> §11 and it is **still open**. The **"Convex backend"** participant, the `orgId` field,
> the `tier` values, the amount `149900`, and the `licenseToken` in the status response
> all rest on an **unselected** provider and an **undecided** offer. Treat every
> vendor-specific name here as a placeholder to be re-decided. Nothing in this document
> is implemented, and no consumer may treat it as a wire contract.
>
> **Do not replace the gap with an invented mutation endpoint.** The missing piece is
> the plan-state write after a captured payment, and that shape is undefined until the
> vendor is selected. This document deliberately does **not** define a generic or
> vendor-neutral replacement endpoint; Gate 1 records the decision that determines it.
>
> **What stays valid:** the edge gateway routes, the `x-razorpay-signature` HMAC-SHA256
> verification seam over the raw body, the Razorpay `payment.captured` payload shape, and
> the client polling fallback. Those are provider-neutral and may be designed and tested
> against a contract today.

This document defines the schema contracts for communication between the Flutter mobile client, Cloudflare Edge Worker, Razorpay, and the **backend ledger/plan-state service (provider OPEN, not selected; the Convex names below are non-normative placeholders)**.

---

## 1. Create Order Request & Response

### Endpoint: `POST /api/v1/checkout/create-order`

#### Request Payload (Client $\rightarrow$ Edge)

> **Provisional.** `orgId` presumes a server-side organization identity that the target
> does not have yet, and `tier`/`billingCycle` are undecided values. The amounts, tier
> names, and field set are re-derived after the backend and commercial decisions close.

```json
{
  "orgId": "org_9823412093",
  "phone": "+919876543210",
  "tier": "starter",
  "billingCycle": "annual",
  "deviceId": "d41d8cd98f00b204e9800998ecf8427e"
}
```

#### Response Payload (Edge $\rightarrow$ Client)

> **Provisional.** The amount, the `upiIntentUri` placeholder, and the exposed
> `razorpayKey` are illustrative and must be re-derived once the payment provider and the
> offer are decided (Gate 1 and Gate 13, §11).

```json
{
  "success": true,
  "orderId": "order_NX829103kLm",
  "amountInPaise": 149900,
  "currency": "INR",
  "razorpayKey": "rzp_live_abc123xyz",
  "upiIntentUri": "upi://pay?pa=collectionbook@icici&pn=CollectionBook&am=1499.00&cu=INR&tn=StarterPlan_Annual&tr=order_NX829103kLm"
}
```

---

## 2. Webhook Event Specification

### Endpoint: `POST /api/v1/checkout/webhook`
- **Header**: `x-razorpay-signature` (HMAC SHA-256 of raw request body using webhook secret).

#### Example Webhook Payload (`payment.captured`)
```json
{
  "entity": "event",
  "account_id": "acc_7812903",
  "event": "payment.captured",
  "contains": ["payment"],
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_O129849201",
        "amount": 149900,
        "currency": "INR",
        "status": "captured",
        "order_id": "order_NX829103kLm",
        "method": "upi",
        "vpa": "ramesh@oksbi",
        "email": "operator@collectionbook.in",
        "contact": "+919876543210",
        "notes": {
          "orgId": "org_9823412093",
          "tier": "starter",
          "billingCycle": "annual"
        },
        "created_at": 1790150400
      }
    }
  }
}
```

---

## 3. Order Status Polling (Client Fallback)

### Endpoint: `GET /api/v1/checkout/status?order_id=order_NX829103kLm`

#### Response Payload

> **Provisional, and partly superseded.** `tier` and `planExpiresAt` assume a
> server-derived plan, which is the target shape; `licenseToken` is the
> **superseded device-local token** and becomes a cached, expiring grant once
> entitlements are server-side (canonical §9.1).

```json
{
  "status": "completed",
  "tier": "starter",
  "planExpiresAt": 1821686400,
  "licenseToken": "eyJhbGciOiJFZERTQSI...<signed_ed25519_jwt>"
}
```
