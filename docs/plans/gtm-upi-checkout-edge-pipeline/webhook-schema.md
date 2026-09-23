# Razorpay Webhook & Edge Request/Response Schemas

This document defines the schema contracts for communication between the Flutter mobile client, Cloudflare Edge Worker, Razorpay, and the Convex backend.

---

## 1. Create Order Request & Response

### Endpoint: `POST /api/v1/checkout/create-order`

#### Request Payload (Client $\rightarrow$ Edge)
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
```json
{
  "status": "completed",
  "tier": "starter",
  "planExpiresAt": 1821686400,
  "licenseToken": "eyJhbGciOiJFZERTQSI...<signed_ed25519_jwt>"
}
```
