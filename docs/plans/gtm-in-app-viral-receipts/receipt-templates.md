# Vernacular WhatsApp Receipt Templates & Trojan Horse Specifications

This document defines the exact formatting templates, field variables, and localized phrase matrices for digital receipts sent through the native Android WhatsApp intent.

> **Shipped copy is authoritative in code.** The strings that actually reach a
> subscriber live in `lib/services/whatsapp_receipt_service.dart`; this file is
> the design reference. The referral footer in every language may only ask
> another operator to try the app. Collection Book has no subscriber cap, no
> free tier, and no paid plan, so a "free" or "up to N subscribers" promise in
> any locale is an unsupported claim and is rejected by
> `findUnsupportedClaims` in `packages/contracts`, scanned over this Dart file
> by `services/cbk-edge/test/receipt_claims.test.ts` and asserted per locale by
> `test/whatsapp_receipt_claims_test.dart`.

---

## 1. Dynamic Receipt Variables

| Variable | Description | Example |
| :--- | :--- | :--- |
| `{{ORG_NAME}}` | Cable / Broadband Business Name | `Ramesh Cable Network` |
| `{{CUST_NAME}}` | Customer Full Name | `Sanjay Verma` |
| `{{VC_NUMBER}}` | Viewing Card / ONT MAC / Box # | `0214889210` |
| `{{SERVICE}}` | Service Mode Label | `Cable TV` or `Fiber Internet` |
| `{{AREA}}` | Neighborhood / Lane Name | `Ward 4, Shiv Mandir Galli` |
| `{{MONTH}}` | Billing Month & Year | `September 2026` |
| `{{PAID_AMT}}` | Amount Collected This Session | `₹350` |
| `{{STATUS_LABEL}}`| Clean status indicator | `FULLY PAID` or `PARTIAL (DUE)` |
| `{{REMAINING_DUE}}`| Remaining balance after payment | `₹0` or `₹150` |
| `{{REF_URL}}` | Dynamic referral download link | `https://cbk.sarbaa.com/r/RAM882` |

---

## 2. Localized Templates (5 Regional Belts)

### 1. Hindi (Northern Belt - UP, MP, Bihar, Rajasthan, Delhi)
```text
🧾 *भुगतान रसीद | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *ग्राहक:* {{CUST_NAME}}
📺 *सेवा:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *क्षेत्र:* {{AREA}}
🗓️ *बिलिंग महीना:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *जमा राशि:* {{PAID_AMT}}
✅ *स्थिति:* {{STATUS_LABEL}}
⚠️ *बकाया राशि:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 समय पर भुगतान करने के लिए धन्यवाद!

📱 Managed via Collection Book App
👉 क्या आप केबल/WiFi ऑपरेटर हैं? किसी और ऑपरेटर को साझा करें, ग्राहकों की कोई सीमा नहीं:
{{REF_URL}}
```

### 2. Marathi (Western Belt - Maharashtra, Goa)
```text
🧾 *पावती | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *ग्राहक:* {{CUST_NAME}}
📺 *सेवा:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *गल्ली/भाग:* {{AREA}}
🗓️ *महिना:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *जमा केलेली रक्कम:* {{PAID_AMT}}
✅ *स्थिती:* {{STATUS_LABEL}}
⚠️ *उर्वरित बाकी:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 वेळेवर बिल भरल्याबद्दल धन्यवाद!

📱 Managed via Collection Book App
👉 आपण केबल/इंटरनेट ऑपरेटर आहात का? दुसऱ्या ऑपरेटरला पाठवा, ग्राहकांची मर्यादा नाही:
{{REF_URL}}
```

### 3. Bengali (Eastern Belt - West Bengal, Tripura)
```text
🧾 *পেমেন্ট রসিদ | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *গ্রাহক:* {{CUST_NAME}}
📺 *পরিষেবা:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *এলাকা:* {{AREA}}
🗓️ *বিলিং মাস:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *প্রদত্ত টাকা:* {{PAID_AMT}}
✅ *স্ট্যাটাস:* {{STATUS_LABEL}}
⚠️ *বকেয়া টাকা:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 সময়মতো বিল পরিশোধ করার জন্য ধন্যবাদ!

📱 Managed via Collection Book App
👉 আপনি কি কেবল বা ইন্টারনেট অপারেটর? অন্য অপারেটরকে শেয়ার করুন, গ্রাহক সংখ্যার কোনো সীমা নেই:
{{REF_URL}}
```

### 4. Tamil (Southern Belt - Tamil Nadu)
```text
🧾 *ரசீது | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *வாடிக்கையாளர்:* {{CUST_NAME}}
📺 *சேவை:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *பகுதி:* {{AREA}}
🗓️ *மாதம்:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *செலுத்திய தொகை:* {{PAID_AMT}}
✅ *நிலை:* {{STATUS_LABEL}}
⚠️ *மீதி பாக்கி:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 சரியான நேரத்தில் கட்டணம் செலுத்தியதற்கு நன்றி!

📱 Managed via Collection Book App
👉 நீங்கள் கேபிள்/வைஃபை ஆபரேட்டரா? மற்றொரு ஆபரேட்டருக்குப் பகிரவும், வாடிக்கையாளர் எண்ணிக்கைக்கு வரம்பு இல்லை:
{{REF_URL}}
```

### 5. English (Default / Pan-India)
```text
🧾 *PAYMENT RECEIPT | {{ORG_NAME}}*
━━━━━━━━━━━━━━━━━━━━━
👤 *Customer:* {{CUST_NAME}}
📺 *Service:* {{SERVICE}} (VC: {{VC_NUMBER}})
📍 *Area:* {{AREA}}
🗓️ *Billing Month:* {{MONTH}}
━━━━━━━━━━━━━━━━━━━━━
💵 *Amount Paid:* {{PAID_AMT}}
✅ *Status:* {{STATUS_LABEL}}
⚠️ *Remaining Due:* {{REMAINING_DUE}}
━━━━━━━━━━━━━━━━━━━━━
🙏 Thank you for your payment!

📱 Managed via Collection Book App
👉 Are you a Cable/WiFi Operator? Refer another operator, no subscriber limit:
{{REF_URL}}
```

---

## 3. Trojan Horse Attribution Link Structure

When the operator opens the app for the first time, an anonymous, unique 6-character referral code is derived from their installation hash (or phone number):
* Structure: `https://cbk.sarbaa.com/r/{OPERATOR_CODE}`
* Edge Redirection: The Cloudflare Edge shortener redirects to:
  `https://play.google.com/store/apps/details?id=com.sarbaa.cbk&referrer=utm_source%3Dcbk_edge%26utm_medium%3Dreferral%26utm_campaign%3D{OPERATOR_CODE}`
* Viral Loop Reward: **not implemented.** There is no plan, upgrade, or reward system in the shipped app, so no receipt, page, or listing may promise one. Referral tracking today ends at the click log and the 30-day first-party cookie.
