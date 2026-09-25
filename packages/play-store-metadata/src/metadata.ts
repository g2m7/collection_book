/**
 * Canonical Google Play Store listing text for the Collection Book Android app.
 *
 * This module is the single source of truth for every localized listing. Only
 * features that are actually implemented in the Flutter app may be claimed, and
 * the vocabulary follows the shipped `assets/i18n` catalogs.
 */

export const supportedLocales = [
  "en-IN",
  "hi-IN",
  "mr-IN",
  "bn-IN",
  "ta-IN",
] as const;

export type SupportedLocale = (typeof supportedLocales)[number];

/** Google Play Console field limits, measured in Unicode code points. */
export const listingLimits = {
  title: 30,
  shortDescription: 80,
  fullDescription: 4000,
} as const;

export interface PlayStoreListing {
  readonly locale: SupportedLocale;
  readonly title: string;
  readonly shortDescription: string;
  readonly fullDescription: string;
}

export const metadataFieldNames = [
  "title",
  "shortDescription",
  "fullDescription",
] as const;

export type MetadataFieldName = (typeof metadataFieldNames)[number];

const enListing: PlayStoreListing = {
  locale: "en-IN",
  title: "Collection Book: Cable TV",
  shortDescription:
    "Offline collection and payment register for Cable TV and Internet.",
  fullDescription: `Collection Book is an offline-first collection ledger for Cable TV and Internet operators.

Keep your register in your phone:
- Add subscribers with full name, alias name, area, monthly rent and previous due.
- For Cable TV, store the VC / STB number. For Internet, store the account or card number, plus the login username and the WhatsApp mobile number.
- Record each payment against a subscriber and see who is paid and who is still pending.
- Switch between Cable TV and Internet, or browse customers by area.

It works without internet. Every record is stored locally on your phone, so the app stays usable in areas with weak or no network.

Import your existing register instead of typing it again. The file picker accepts .xlsx, .xls and .csv:
- Book1 collection books and operator active-package or total-subscriber reports are detected automatically.
- Operator portals that export an HTML table are handled too, as long as you save the file with an .xls extension.

Every import shows a preview first, so you can check the detected columns and records before anything is written to your database.

Keep a copy of your data:
- Create a local backup file on your phone whenever you want.
- Share that database file to your own storage, email or a cloud drive you choose.
- Restore from a backup file when you set up a new phone.

Send receipts to your customers:
- Generate a WhatsApp receipt from a payment record.
- The receipt opens in WhatsApp with the message already filled in, or in your browser through wa.me when WhatsApp is not installed, so you can review it and then send it.

Use the app in the language you prefer. The app and the WhatsApp receipts switch instantly between English, Hindi, Marathi, Bengali and Tamil.`,
};

const hiListing: PlayStoreListing = {
  locale: "hi-IN",
  title: "केबल वसूली और भुगतान बही",
  shortDescription:
    "केबल टीवी और इंटरनेट ऑपरेटरों के लिए ऑफ़लाइन संग्रह और भुगतान रजिस्टर।",
  fullDescription: `Collection Book एक ऑफ़लाइन-फर्स्ट संग्रह बही है, जो केबल टीवी और इंटरनेट ऑपरेटरों के लिए बनाई गई है।

अपनी बही फ़ोन में रखें:
- पूरा नाम, उपनाम, क्षेत्र, मासिक किराया और पिछला बकाया दर्ज करके ग्राहक जोड़ें।
- केबल टीवी के लिए वीसी / एसटीबी नंबर दर्ज करें। इंटरनेट के लिए खाता या कार्ड नंबर दर्ज करें, साथ में उपयोगकर्ता नाम और WhatsApp फ़ोन नंबर।
- हर ग्राहक का भुगतान दर्ज करें और देखें कि किसका भुगतान चुकता है और किसका लंबित है।
- केबल टीवी और इंटरनेट के बीच बदलें, या क्षेत्र के हिसाब से ग्राहक देखें।

यह बिना इंटरनेट के चलता है। सारे रिकॉर्ड आपके फ़ोन में ही स्थानीय रूप से सहेजे जाते हैं, इसलिए कम या शून्य नेटवर्क वाले इलाकों में भी इस्तेमाल किया जा सकता है।

पुरानी बही टाइप करने के बजाय आयात करें। फ़ाइल चुनने के लिए .xlsx, .xls और .csv स्वीकार्य हैं:
- Book1 कलेक्शन बुक और ऑपरेटर की एक्टिव-पैकेज या टोटल-ग्राहक रिपोर्ट अपने आप पहचान ली जाती हैं।
- जो ऑपरेटर पोर्टल HTML टेबल एक्सपोर्ट करते हैं, वे भी चलते हैं, बशर्ते आप फ़ाइल को .xls एक्सटेंशन के साथ सेव करें।

हर आयात से पहले पूर्वावलोकन दिखता है, ताकि डेटा लिखने से पहले आप कॉलम और रिकॉर्ड देख सकें।

अपने डेटा की कॉपी रखें:
- जब चाहें फ़ोन में लोकल बैकअप फ़ाइल बनाएँ।
- उस डेटाबेस फ़ाइल को अपने स्टोरेज, ईमेल या अपनी पसंद की क्लाउड ड्राइव में साझा करें।
- नया फ़ोन सेटअप करते समय बैकअप फ़ाइल से पुनर्स्थापित करें।

ग्राहकों को रसीद भेजें:
- भुगतान रिकॉर्ड से WhatsApp रसीद बनाएँ।
- रसीद का संदेश पहले से भरा होता है और WhatsApp में खुलती है; अगर WhatsApp इंस्टॉल नहीं है तो ब्राउज़र में wa.me के ज़रिए खुलती है, जहाँ आप उसे देखकर भेज सकते हैं।

ऐप का इस्तेमाल अपनी पसंद की भाषा में करें। ऐप और WhatsApp रसीदें तुरंत अंग्रेज़ी, हिन्दी, मराठी, बंगाली और तमिल के बीच बदल जाती हैं।`,
};

const mrListing: PlayStoreListing = {
  locale: "mr-IN",
  title: "केबल वसुली आणि पेमेंट बही",
  shortDescription:
    "केबल टीव्ही आणि इंटरनेट ऑपरेटरसाठी ऑफलाइन संग्रह आणि पेमेंट नोंदवही.",
  fullDescription: `Collection Book ही केबल टीव्ही आणि इंटरनेट ऑपरेटरांसाठी ऑफलाइन-फर्स्ट संग्रह नोंदवही आहे.

तुमची नोंदवही फोनमध्ये न्या:
- पूर्ण नाव, उपनाव, भाग, मासिक भाडे आणि मागील बाकी नोंदवून ग्राहक जोडा.
- केबल टीव्हीसाठी व्हीसी / एसटीबी क्रमांक नोंदवा. इंटरनेटसाठी खाते किंवा कार्ड क्रमांक नोंदवा, तसेच वापरकर्तानाव आणि WhatsApp फोन क्रमांक.
- प्रत्येक ग्राहकाचे पेमेंट नोंदवा आणि कोणाचे पेमेंट भरले आहे आणि कोणाचे प्रलंबित आहे ते पहा.
- केबल टीव्ही आणि इंटरनेट नोंदी स्वतंत्रपणे पहा किंवा भागानुसार ग्राहक पहा.

हे इंटरनेटशिवाय चालते. सर्व नोंदी फोनमध्येच जागेवर साठवल्या जातात, म्हणून कमी किंवा नसलेल्या नेटवर्क असलेल्या भागातही वापरता येते.

जुनी एक्सेल स्प्रेडशीट नोंदवही टाइप करण्याऐवजी इम्पोर्ट करा. फाइल निवडण्यासाठी .xlsx, .xls आणि .csv स्वीकार्य आहेत:
- Book1 कलेक्शन बुक आणि ऑपरेटरचे एक्टिव्ह-पॅकेज किंवा टोटल-ग्राहक अहवाल आपोआप ओळखले जातात.
- HTML टेबल एक्सपोर्ट करणारे ऑपरेटर पोर्टलही चालतात, जर तुम्ही फाइल .xls एक्स्टेंशनसह सेव केली.

प्रत्येक इम्पोर्टपूर्वी पूर्वदृश्य दाखवते, म्हणून नोंदी लिहिण्यापूर्वी तुम्ही स्तंभ आणि नोंदी तपासू शकता.

तुमच्या डेटाची प्रत ठेवा:
- हवे तेव्हा फोनमध्ये लोकल बॅकअप फाइल तयार करा.
- ती डेटाबेस फाइल तुमच्या साठ्यात, ईमेलमध्ये किंवा तुम्हाला हवी त्या क्लाउड ड्राइव्हमध्ये शेअर करा.
- नवीन फोन सेटअप करताना बॅकअप फाइलमधून पुनर्स्थापित करा.

ग्राहकांना पावती पाठवा:
- पेमेंट नोंदीवरून WhatsApp पावती तयार करा.
- पावतीचा संदेश आधीच भरलेला असतो आणि WhatsApp मध्ये उघडतो; WhatsApp इन्स्टॉल नसल्यास ब्राउझरमध्ये wa.me द्वारे उघडतो, जिथे तुम्ही ती पाहून पाठवू शकता.

ॲप तुमच्या आवडीच्या भाषेत वापरा. ॲप आणि WhatsApp पावती झटपट इंग्रजी, हिन्दी, मराठी, बंगाली आणि तमिळ या भाषांमध्ये बदलतात.`,
};

const bnListing: PlayStoreListing = {
  locale: "bn-IN",
  title: "কেবল কালেকশন ও পেমেন্ট খাতা",
  shortDescription:
    "কেবল টিভি ও ইন্টারনেট অপারেটরদের জন্য অফলাইন কালেকশন ও পেমেন্ট খাতা।",
  fullDescription: `Collection Book একটি অফলাইন-ফার্স্ট কালেকশন খাতা, যা কেবল টিভি ও ইন্টারনেট অপারেটরদের জন্য তৈরি হয়েছে।

আপনার খাতা ফোনে রাখুন:
- পূর্ণ নাম, ডাক নাম, এলাকা, মাসিক ভাড়া ও পূর্বের বকেয়া দিয়ে গ্রাহক যোগ করুন।
- কেবল টিভির জন্য ভিসি / এসটিবি নম্বর সংরক্ষণ করুন। ইন্টারনেটের জন্য অ্যাকাউন্ট বা কার্ড নম্বর সংরক্ষণ করুন, সঙ্গে ব্যবহারকারীর নাম ও WhatsApp ফোন নম্বর।
- প্রতিটি গ্রাহকের পেমেন্ট লিখে রাখুন এবং কার পেমেন্ট পরিশোধিত আর কার অপেক্ষমাণ তা দেখুন।
- কেবল টিভি ও ইন্টারনেটের মধ্যে বদলান, অথবা এলাকা অনুযায়ী গ্রাহক দেখুন।

এটি ইন্টারনেট ছাড়াই চলে। সব রেকর্ড আপনার ফোনেই সংরক্ষিত থাকে, তাই নেটওয়ার্ক দুর্বল বা নেই এমন এলাকাতেও ব্যবহার করা যায়।

পুরনো খাতা টাইপ করার বদলে ইমপোর্ট করুন। ফাইল বেছে নিতে .xlsx, .xls এবং .csv নেওয়া হয়:
- Book1 কালেকশন বুক এবং অপারেটরের অ্যাকটিভ-প্যাকেজ বা টোটাল-গ্রাহক রিপোর্ট স্বয়ংক্রিয়ভাবে শনাক্ত হয়।
- যেসব অপারেটর পোর্টাল HTML টেবিল এক্সপোর্ট করে, সেগুলিও কাজ করে, যদি আপনি ফাইলটি .xls এক্সটেনশন দিয়ে সংরক্ষণ করেন।

প্রতিটি ইমপোর্টের আগে প্রিভিউ দেখানো হয়, তাই ডেটা লেখার আগে আপনি কলাম ও রেকর্ড দেখে নিতে পারেন।

আপনার ডেটার একটি কপি রাখুন:
- যখন খুশি ফোনে লোকাল ব্যাকআপ ফাইল তৈরি করুন।
- সেই ডাটাবেজ ফাইলটি নিজের স্টোরেজ, ইমেইল বা নিজের পছন্দের ক্লাউড ড্রাইভে শেয়ার করুন।
- নতুন ফোন সেটআপ করার সময় ব্যাকআপ ফাইল থেকে পুনরুদ্ধার করুন।

গ্রাহকদের রসিদ পাঠান:
- পেমেন্ট রেকর্ড থেকে WhatsApp রসিদ তৈরি করুন।
- রসিদের বার্তা আগেই সাজানো থাকে এবং WhatsApp-এ খোলে; WhatsApp না থাকলে ব্রাউজারে wa.me-এর মাধ্যমে খোলে, যেখানে আপনি দেখে পাঠাতে পারেন।

অ্যাপটি আপনার পছন্দের ভাষায় ব্যবহার করুন। অ্যাপ ও WhatsApp রসিদ সঙ্গে সঙ্গে ইংরেজি, হিন্দি, মারাঠি, বাংলা ও তামিল ভাষায় বদলে যায়।`,
};

const taListing: PlayStoreListing = {
  locale: "ta-IN",
  title: "கேபிள் டிவி வசூல் பதிவேடு",
  shortDescription:
    "கேபிள் டிவி மற்றும் இண்டர்நெட் ஆபரேட்டர்களுக்கான ஆஃப்லைன் வசூல் பதிவேடு.",
  fullDescription: `Collection Book என்பது கேபிள் டிவி மற்றும் இண்டர்நெட் ஆபரேட்டர்களுக்கான ஆஃப்லைன்-முதல் வசூல் பதிவேடு.

உங்கள் பதிவேட்டைத் தொலைபேசியிலேயே வையுங்கள்:
- முழுப் பெயர், புனைப் பெயர், பகுதி, மாத வாடகை மற்றும் முந்தைய பாக்கி ஆகியவற்றுடன் வாடிக்கையாளர்களைச் சேர்க்கவும்.
- கேபிள் டிவிக்கு விசி / எஸ்டிபி எண்ணைச் சேமிக்கவும். இண்டர்நெட்டிற்கு கணக்கு அல்லது அட்டை எண்ணைச் சேமிப்பதோடு, பயனர் பெயரையும் WhatsApp தொலைபேசி எண்ணையும் சேமிக்கவும்.
- ஒவ்வொரு வாடிக்கையாளரின் கட்டணத்தையும் பதிவு செய்து, யார் செலுத்திவிட்டார் மற்றும் யார் நிலுவையில் இருக்கிறார் என்பதைப் பாருங்கள்.
- கேபிள் டிவி மற்றும் இண்டர்நெட் இடையே மாறவும், அல்லது பகுதி வாரியாக வாடிக்கையாளர்களைப் பார்க்கவும்.

இண்டர்நெட் இல்லாமலே இது இயங்குகிறது. அனைத்துப் பதிவுகளும் உங்கள் தொலைபேசியிலேயே சேமிக்கப்படுகின்றன, எனவே நெட்வர்க் மிகவும் பலவீனமான அல்லது இல்லாத பகுதிகளிலும் பயன்படுத்தலாம்.

பழைய பதிவேட்டைத் தட்டச்சு செய்யாமல் இறக்குமதி செய்யுங்கள். கோப்பைத் தேர்ந்தெடுக்க .xlsx, .xls மற்றும் .csv ஆகியவை ஏற்கப்படுகின்றன:
- Book1 கலெக்ஷன் புக் மற்றும் ஆபரேட்டரின் செயல்படும் தொகுதி அல்லது மொத்த வாடிக்கையாளர் அறிக்கை தானியங்கியாக அடையாளம் கண்டறியப்படுகின்றன.
- HTML அட்டவணையை ஏற்றுமதி செய்யும் ஆபரேட்டர் போர்டல்களும் இயங்கும், கோப்பை .xls நீட்சியுடன் சேமித்தால் மட்டும்.

ஒவ்வொரு இறக்குமதிக்கும் முன்பு முன்னோட்டம் காட்டப்படுகிறது, எனவே தரவை எழுதுவதற்கு முன் நெடுவரிசைகளையும் பதிவுகளையும் பார்த்துக் கொள்ளலாம்.

உங்கள் தரவின் ஒரு நகலை வையுங்கள்:
- வேண்டும்போது தொலைபேசியில் உள்ளூர் காப்புப்பிரதி கோப்பை உருவாக்குங்கள்.
- அந்தத் தரவுத்தளக் கோப்பை உங்கள் சேமிப்பு, மின்னஞ்சல் அல்லது விரும்பும் மேகச் சேமிப்பில் பகிருங்கள்.
- புதிய தொலைபேசி செட்அப் செய்யும்போது காப்புப்பிரதி கோப்பிலிருந்து மீட்டமைக்கவும்.

வாடிக்கையாளர்களுக்கு ரசீது அனுப்புங்கள்:
- கட்டண பதிவிலிருந்து WhatsApp ரசீதை உருவாக்குங்கள்.
- ரசீதில் செய்தி ஏற்கெனவே நிரப்பப்பட்டு WhatsApp-இல் திறக்கிறது; WhatsApp நிறுவப்படவில்லை என்றால் உலாவியில் wa.me வழியாகத் திறக்கிறது, அங்கு நீங்கள் பார்த்து அனுப்பலாம்.

செயலியை உங்களுக்குத் தெரிந்த மொழியில் பயன்படுத்துங்கள். செயலியும் WhatsApp ரசீதுகளும் உடனடியாக ஆங்கிலம், இந்தி, மராத்தி, வங்காளம் மற்றும் தமிழ் மொழிகளுக்கு இடையே மாறுகின்றன.`,
};

export const playStoreListings: readonly PlayStoreListing[] = [
  enListing,
  hiListing,
  mrListing,
  bnListing,
  taListing,
];
