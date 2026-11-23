# Admin শিক্ষার্থী তালিকা — ফিল্টার ও CSV Export

**হালনাগাদ:** ২৩ নভেম্বর ২০২৬

## কী যুক্ত হয়েছে
- নাম, Student ID, শিক্ষার্থী/অভিভাবকের মোবাইল, অভিভাবকের নাম, শাখা বা শ্রেণির নাম দিয়ে সার্চ।
- শ্রেণি এবং শিক্ষার্থীর অবস্থা (সক্রিয়, নিষ্ক্রিয়, উত্তীর্ণ, স্থানান্তরিত) অনুযায়ী আলাদা ফিল্টার।
- তালিকায় মোট রেকর্ডের সঙ্গে ফিল্টার করে দেখা রেকর্ডের সংখ্যা।
- **CSV Export** বর্তমান সার্চ ও ফিল্টারের ফলাফলই export করে; অন্য শিক্ষার্থী এতে যোগ হয় না।
- CSV-তে বাংলা header, UTF-8 BOM এবং quote escaping আছে; spreadsheet formula injection-এর সাধারণ শুরু (=, +, -, @) নিরাপদ করার জন্য cell-এ apostrophe যোগ করা হয়।

## ব্যবহার
1. অনুমোদিত Admin account দিয়ে `/admin.html` লগইন করুন।
2. **শিক্ষার্থী** বিভাগ খুলুন।
3. প্রয়োজনে search, class ও status filter ব্যবহার করুন।
4. **CSV Export** চাপুন। ডাউনলোড ফাইলের নাম `sga-students-YYYY-MM-DD.csv`।

## Privacy
Export-এ শিক্ষার্থী ও অভিভাবকের যোগাযোগের তথ্য থাকতে পারে। শুধুমাত্র অনুমোদিত প্রশাসনিক কাজে ব্যবহার করুন; ব্যক্তিগত ডিভাইস/অনিরাপদ cloud-এ সংরক্ষণ বা অননুমোদিত ব্যক্তির সঙ্গে শেয়ার করবেন না। Export browser-এর authenticated Admin page থেকে হয়; কোনো নতুন backend endpoint বা SQL migration লাগে না।

## যাচাই
- Inline Admin script syntax compile check করা হয়েছে।
- Filter control, filter function, CSV button, UTF-8 BOM ও formula guard-এর static checks pass করেছে।
- Supabase live data, browser download, role/RLS এবং mobile layout বাস্তব account দিয়ে যাচাই করা হয়নি; deployment পর manual QA প্রয়োজন।
