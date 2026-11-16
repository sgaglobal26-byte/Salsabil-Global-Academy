-- Editable public Home Page content, managed by authenticated admins.
create table if not exists public.home_page_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text not null unique check (section_key in (
    'hero','intro','vision','departments','curriculum','activities','why_us',
    'support_transport','admission','faq','contact'
  )),
  title_bn text not null,
  body_bn text not null default '',
  title_en text,
  body_en text,
  sort_order integer not null default 0,
  is_published boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
create index if not exists home_page_sections_public_order_idx
  on public.home_page_sections(is_published, sort_order);
alter table public.home_page_sections enable row level security;
drop policy if exists "home_page_sections_public_read" on public.home_page_sections;
create policy "home_page_sections_public_read" on public.home_page_sections
  for select to anon, authenticated using (is_published = true or public.sga_is_admin());
drop policy if exists "home_page_sections_admin_insert" on public.home_page_sections;
create policy "home_page_sections_admin_insert" on public.home_page_sections
  for insert to authenticated with check (public.sga_is_admin() and updated_by = (select auth.uid()));
drop policy if exists "home_page_sections_admin_update" on public.home_page_sections;
create policy "home_page_sections_admin_update" on public.home_page_sections
  for update to authenticated using (public.sga_is_admin())
  with check (public.sga_is_admin() and updated_by = (select auth.uid()));
drop policy if exists "home_page_sections_admin_delete" on public.home_page_sections;
create policy "home_page_sections_admin_delete" on public.home_page_sections
  for delete to authenticated using (public.sga_is_admin());
grant select on public.home_page_sections to anon, authenticated;
grant insert, update, delete on public.home_page_sections to authenticated;

-- Preload the institution information supplied by the academy. Admins can edit it later.
insert into public.home_page_sections
(section_key,title_bn,body_bn,sort_order,is_published)
values
('hero','প্রতিষ্ঠানের স্লোগান ও পরিচিতি',E'শিক্ষা হোক আধুনিক, জীবন হোক ইসলামিক।\nকুরআনের আলোয় শৈশব, আধুনিক জ্ঞানে ভবিষ্যৎ।',0,true),
('intro','আমাদের কথা',E'সম্মানিত অভিভাবকবৃন্দ\nআসসালামু আলাইকুম ওয়া রাহমাতুল্লাহ।\n\nএকটি শিশু জন্মগতভাবে নিষ্পাপ। পরিবার তার প্রথম শিক্ষালয়, আর একটি আদর্শ শিক্ষা প্রতিষ্ঠান তার জ্ঞান, চরিত্র ও ব্যক্তিত্ব গঠনের অন্যতম প্রধান ভিত্তি।\n\nসালসাবিল গ্লোবাল একাডেমির লক্ষ্য শুধু ভালো ফলাফল অর্জন নয়; বরং কুরআন-সুন্নাহর আলোকে জ্ঞানী, নৈতিক, দায়িত্বশীল, মানবিক ও আল্লাহভীরু প্রজন্ম গড়ে তোলা।\n\nআমরা বিশ্বাস করি, ধর্মীয় মূল্যবোধ ও আধুনিক জ্ঞান একে অপরের পরিপূরক। তাই ইসলামি আদর্শের সঙ্গে আধুনিক শিক্ষার সমন্বয়ে আমাদের শিক্ষা কার্যক্রম পরিচালিত হবে।\n\nকুরআনের আলোয় শৈশব, আধুনিক জ্ঞানে ভবিষ্যৎ।',1,true),
('vision','আমাদের লক্ষ্য ও উদ্দেশ্য',E'কুরআন-সুন্নাহর আলোকে শিক্ষার্থীর মেধা ও প্রতিভার বিকাশ।\nতালীম-তারবিয়াত ও আদব-আখলাকের মাধ্যমে উত্তম চরিত্র গঠন।\nআধুনিক জ্ঞান ও প্রযুক্তির সঙ্গে শিক্ষার্থীদের পরিচিত করা।\nসঠিক চিন্তা, নৈতিক দৃঢ়তা ও দায়িত্ববোধ তৈরি করা।\nপরিবার, সমাজ ও দেশের কল্যাণে ভূমিকা রাখার উপযোগী করে গড়ে তোলা।\nদুনিয়া ও আখিরাতের কল্যাণমুখী জীবনধারায় অভ্যস্ত করা।',2,true),
('departments','আমাদের বিভাগসমূহ',E'আদর্শ মক্তব বিভাগ: শিশু, প্রাক-প্রাথমিক ও ১ম শ্রেণি।\nআদর্শ নাজেরা বিভাগ: ২য় ও ৩য় শ্রেণি।\nসাধারণ শিক্ষা বিভাগ: শিশু থেকে ৮ম শ্রেণি পর্যন্ত।\nপর্যায়ক্রমে বিজ্ঞান, মানবিক ও সাধারণ বিভাগ।',3,true),
('curriculum','আমাদের পাঠ্যক্রম',E'বাংলা, English ও Arabic শিক্ষার ব্যবস্থা।\nবিশুদ্ধ কুরআন তিলাওয়াত শিক্ষা; নাজেরা ও হিফজের উপযোগী কুরআন শিক্ষা।\nসরকারি কারিকুলামের সঙ্গে সমন্বিত পাঠদান।\nPhonics English, Spoken English ও Arabic Speaking।\nFocus Mathematics এবং সুন্দর হাতের লেখার বিশেষ প্রশিক্ষণ।\nনিয়মিত Class Test ও মূল্যায়ন; ত্রৈমাসিক, অর্ধবার্ষিক ও বার্ষিক পরীক্ষা।',4,true),
('activities','সহশিক্ষা কার্যক্রম',E'কিরাত, হামদ-নাত, বক্তৃতা, কুইজ, বিতর্ক, বিজ্ঞান ও সৃজনশীল কার্যক্রম, শিক্ষা সফর, বৃক্ষরোপণ, সমাজসেবা, পুরস্কার ও সম্মাননা।',5,true),
('why_us','কেন সালসাবিল গ্লোবাল একাডেমি?',E'ইসলামি মূল্যবোধভিত্তিক আধুনিক শিক্ষা।\nযোগ্য, অভিজ্ঞ ও নিবেদিতপ্রাণ শিক্ষক-শিক্ষিকার মাধ্যমে পাঠদানের প্রত্যয়।\nজাহাঙ্গীরনগর বিশ্ববিদ্যালয়, ইসলামি বিশ্ববিদ্যালয় ও অন্যান্য পাবলিক বিশ্ববিদ্যালয়ের প্রাক্তন শিক্ষার্থীদের সম্পৃক্ততার উদ্যোগ।\nমাল্টিমিডিয়া ক্লাস ও আধুনিক প্রযুক্তির ব্যবহার।\nদুর্বল শিক্ষার্থীদের জন্য প্রয়োজন অনুযায়ী বিশেষ সহায়ক ক্লাস।\nমেধাবী শিক্ষার্থীদের উৎসাহিত করতে বৃত্তির ব্যবস্থা।\nCCTV ক্যামেরার মাধ্যমে নিরাপত্তা ব্যবস্থা।\nপরিচ্ছন্ন ও স্বাস্থ্যসম্মত ক্যাম্পাস।\nনিয়মিত অভিভাবক-শিক্ষক যোগাযোগ ও শিক্ষার্থীর অগ্রগতি সম্পর্কে অবহিতকরণ।',6,true),
('support_transport','বিশেষ সহায়তা ও পরিবহন',E'স্কুল/মাদরাসা থেকে আগত শিক্ষার্থীদের জন্য আরবি, ইংরেজি ও গণিতে প্রয়োজন অনুযায়ী বিশেষ সহায়ক ক্লাস।\nদুর্বলতা নির্ণয় → বিশেষ সহায়ক ক্লাস → নিজ শ্রেণির উপযোগী করে গড়ে তোলা।\n\nনিজস্ব পরিবহন ব্যবস্থা: সকালে শিক্ষার্থীদের বাসার কাছ থেকে সংগ্রহ এবং ক্লাস শেষে বিকেলে নিরাপদে বাসায় পৌঁছে দেওয়ার ব্যবস্থা।',7,true),
('admission','ভর্তি সংক্রান্ত তথ্য ও ড্রেস কোড',E'ভর্তি শুরু: ১ নভেম্বর ২০২৬।\nক্লাস শুরু: ২ জানুয়ারি ২০২৭।\nপ্রতিদিন অফিস চলাকালীন ভর্তি কার্যক্রম পরিচালিত হবে।\n\nপ্রয়োজনীয় কাগজপত্র: জন্ম নিবন্ধনের ফটোকপি; শিক্ষার্থীর ২ কপি পাসপোর্ট সাইজ ছবি; পিতা-মাতার NID-এর ফটোকপি; পিতা-মাতার ১ কপি করে পাসপোর্ট সাইজ ছবি; অভিভাবকের মোবাইল নম্বর।\n\nড্রেস কোড—ছেলে: সাদা টুপি ও হালকা বাদামি পাঞ্জাবি-পায়জামা। মেয়ে: সাদা হিজাব ও হালকা বাদামি বোরকা। জুতা: সাদা কেডস।',8,true),
('faq','অভিভাবকদের সাধারণ জিজ্ঞাসা',E'প্রশ্ন: স্কুল থেকে সরাসরি এখানে ভর্তি হতে পারবে?\nউত্তর: হ্যাঁ, আমাদের শিক্ষা ব্যবস্থা সাধারণ শিক্ষা ব্যবস্থার সমন্বয়ে তৈরি।\n\nপ্রশ্ন: কেন স্কুল থেকে আপনাদের কাছে দিবো?\nউত্তর: এখানে আপনার সন্তান সহিহ-শুদ্ধ কোরআন তিলাওয়াতের পাশাপাশি বাংলা ও ইংরেজি শিখবে।\n\nপ্রশ্ন: স্কুলের রেজিস্ট্রেশন দিয়ে কি সালসাবিল গ্লোবাল একাডেমিতে ভর্তি হতে পারবে?\nউত্তর: ভর্তি বা স্থানান্তরের ক্ষেত্রে প্রযোজ্য নিয়ম ও কাগজপত্র অফিসে যাচাই করে নিন।',9,true),
('contact','ঠিকানা ও যোগাযোগ',E'সালসাবিল গ্লোবাল একাডেমি।\nক্যাডেট কলেজ (পুরাতন গেটের বিপরীত পাশে), মির্জাপুর, টাঙ্গাইল, বাংলাদেশ।\nমোবাইল: ০১৮০৫৮৩৯৮১৪, ০১৮০৫৮৩৯৮১৫, ০১৮০৫৮৩৯৮১৬।\nস্লোগান: শিক্ষা হোক আধুনিক, জীবন হোক ইসলামিক।',10,true)
on conflict (section_key) do nothing;
