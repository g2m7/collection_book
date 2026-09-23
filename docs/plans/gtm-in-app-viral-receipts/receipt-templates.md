# Vernacular WhatsApp Receipt Templates & Trojan Horse Specifications

This document defines the exact formatting templates, field variables, and localized phrase matrices for digital receipts sent through the native Android WhatsApp intent.

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
| `{{REF_URL}}` | Dynamic referral download link | `https://cbk.in/r/RAMESH88` |

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
👉 क्या आप केबल/WiFi ऑपरेटर हैं? 100 कनेक्शन तक फ्री ऐप डाउनलोड करें:
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
👉 आपण केबल/इंटरनेट ऑपरेटर आहात का? १०० ग्राहकांसाठी मोफत अ‍ॅप:
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
👉 আপনি কি কেবল বা ইন্টারনেট অপারেটর? ১০০ গ্রাহক পর্যন্ত ফ্রি অ্যাপ:
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
👉 நீங்கள் கேபிள்/வைஃபை ஆபரேட்டரா? 100 இணைப்புகள் இலவசம்:
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
👉 Are you a Cable/WiFi Operator? Try Free (up to 100 subs):
{{REF_URL}}
```

---

## 3. Trojan Horse Attribution Link Structure

When the operator opens the app for the first time, an anonymous, unique 6-character referral code is derived from their installation hash (or phone number):
* Structure: `https://cbk.in/r/{OPERATOR_CODE}`
* Edge Redirection: The Cloudflare Edge shortener redirects to:
  `https://play.google.com/store/apps/details?id=com.collectionbook.app&referrer=utm_source%3Dtrojan_receipt%26utm_medium%3Dwhatsapp%26utm_campaign%3D{OPERATOR_CODE}`
* Viral Loop Reward: When a referred operator installs and upgrades, the referring operator earns 1 month of free Starter tier extension.
