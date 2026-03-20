// ─────────────────────────────────────────────────────────────────────────────
// GigCredit — Complete Input Guidelines Data (Steps 1–9, All Fields)
// ─────────────────────────────────────────────────────────────────────────────
// RULE 1: Text inputs → name + short description only (no YouTube, no steps)
// RULE 2: Upload inputs → description + numbered procedure + YouTube title
// RULE 3: Same upload type → one entry (e.g. 6 electricity bills = one card)
// RULE 4: Show ALL inputs (mandatory + optional)
// ─────────────────────────────────────────────────────────────────────────────

enum InputType { text, upload }

class InputGuideline {
  const InputGuideline({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    this.procedure,
    this.youtubeTitle,
    this.youtubeUrl,
    this.mandatory = true,
  });

  final String id;
  final String title;
  final InputType type;
  final String description;

  // Upload only
  final List<String>? procedure;
  final String? youtubeTitle;
  final String? youtubeUrl;
  final bool mandatory;
}

class WorkTypeCategory {
  const WorkTypeCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.inputs,
  });
  final String id;
  final String name;
  final String icon;
  final List<InputGuideline> inputs;
}

class StepGuideline {
  const StepGuideline({
    required this.stepNumber,
    required this.title,
    required this.emoji,
    required this.inputs,
    this.workTypeCategories,
    this.sections,
  });

  final int stepNumber;
  final String title;
  final String emoji;
  final List<InputGuideline> inputs; // top-level inputs
  final List<WorkTypeCategory>? workTypeCategories; // Step-5 only
  final Map<String, List<InputGuideline>>? sections; // Section groups
}

// ─────────────────────────────────────────────────────────────────────────────
// FULL DATA
// ─────────────────────────────────────────────────────────────────────────────

const List<StepGuideline> gigCreditGuidelines = [

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — BASIC PROFILE
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 1,
    title: 'Basic Profile',
    emoji: '👤',
    inputs: [
      // Personal
      InputGuideline(
        id: 's1_name',
        title: 'Full Name',
        type: InputType.text,
        description: 'Enter your name exactly as printed on Aadhaar or PAN card.',
      ),
      InputGuideline(
        id: 's1_dob',
        title: 'Date of Birth',
        type: InputType.text,
        description: 'Select your correct birth date using the date picker.',
      ),
      InputGuideline(
        id: 's1_mobile',
        title: 'Mobile Number',
        type: InputType.text,
        description: 'Enter your active 10-digit mobile number — used for OTP verification.',
      ),
      InputGuideline(
        id: 's1_current_addr',
        title: 'Current Address',
        type: InputType.text,
        description: 'Enter your current residential address with city and PIN code.',
      ),
      InputGuideline(
        id: 's1_perm_addr',
        title: 'Permanent Address',
        type: InputType.text,
        description: 'Enter your permanent home address. Select "Same as current" if applicable.',
      ),
      InputGuideline(
        id: 's1_state',
        title: 'State of Residence',
        type: InputType.text,
        description: 'Select your state — used for city-wise income comparison and scoring.',
      ),
      // Professional
      InputGuideline(
        id: 's1_work_type',
        title: 'Work Type',
        type: InputType.text,
        description: 'Select your occupation: Platform Worker, Vendor, Tradesperson, or Freelancer. This determines Step-5 documents.',
      ),
      InputGuideline(
        id: 's1_income',
        title: 'Monthly Income',
        type: InputType.text,
        description: 'Enter your approximate average monthly earnings from your primary work.',
      ),
      InputGuideline(
        id: 's1_years',
        title: 'Years in Current Profession',
        type: InputType.text,
        description: 'Enter the total number of years you have been in your current type of work.',
      ),
      InputGuideline(
        id: 's1_dependents',
        title: 'Number of Dependents',
        type: InputType.text,
        description: 'Enter the number of family members financially dependent on you (0 if none).',
      ),
      InputGuideline(
        id: 's1_vehicle',
        title: 'Vehicle Ownership',
        type: InputType.text,
        description: 'Select Yes if you own any vehicle — this makes vehicle insurance mandatory in Step-7.',
      ),
      InputGuideline(
        id: 's1_sec_source',
        title: 'Secondary Income Source',
        type: InputType.text,
        mandatory: false,
        description: 'Describe any additional income source (e.g. part-time delivery, tutoring).',
      ),
      InputGuideline(
        id: 's1_sec_amount',
        title: 'Secondary Income Amount',
        type: InputType.text,
        mandatory: false,
        description: 'Enter the monthly amount earned from your secondary income source.',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — IDENTITY (KYC)
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 2,
    title: 'Identity (KYC)',
    emoji: '🪪',
    inputs: [
      // Text
      InputGuideline(
        id: 's2_aadhaar_num',
        title: 'Aadhaar Number',
        type: InputType.text,
        description: 'Enter your 12-digit Aadhaar number in 4-4-4 format as shown on the card.',
      ),
      InputGuideline(
        id: 's2_pan_num',
        title: 'PAN Number',
        type: InputType.text,
        description: 'Enter your 10-character PAN in ABCDE1234F format — exactly as on the card.',
      ),
      // Uploads
      InputGuideline(
        id: 's2_aadhaar_img',
        title: 'Aadhaar Card (Front & Back)',
        type: InputType.upload,
        description: 'Upload clear images of both sides of your Aadhaar card. Used to verify identity, address, and date of birth.',
        procedure: [
          'Place the Aadhaar card on a flat surface',
          'Capture in good lighting — avoid shadow and glare',
          'Ensure all 4 corners and full text are visible',
          'Upload front side first, then back side',
        ],
        youtubeTitle: 'Basic details + Aadhaar card walkthrough',
        youtubeUrl: 'https://youtu.be/UvEIVaBREsw?si=WhgT6Rpn9EWZV0I9',
      ),
      InputGuideline(
        id: 's2_pan_img',
        title: 'PAN Card Photo',
        type: InputType.upload,
        description: 'Upload a clear photo of your PAN card. PAN number and name must be fully readable.',
        procedure: [
          'Place PAN card on flat surface in bright light',
          'Ensure the PAN number is fully visible',
          'Do not cover any part with fingers',
          'Capture as JPG or PNG',
        ],
        youtubeTitle: 'Basic details + PAN card walkthrough',
        youtubeUrl: 'https://youtu.be/UvEIVaBREsw?si=WhgT6Rpn9EWZV0I9',
      ),
      InputGuideline(
        id: 's2_selfie',
        title: 'Live Selfie',
        type: InputType.upload,
        description: 'Take a live selfie using the in-app camera only — gallery upload is not accepted. Used to match your face with your Aadhaar photo.',
        procedure: [
          'Tap the "Take Selfie" button in the app',
          'Look straight at the camera',
          'Ensure face is well-lit — avoid dark background',
          'Remove glasses, cap, or face covering',
        ],
        youtubeTitle: 'How to take selfie for KYC face verification',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — BANK VERIFICATION
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 3,
    title: 'Bank Verification',
    emoji: '🏦',
    inputs: [
      // Primary Bank — Text
      InputGuideline(
        id: 's3_bank_name',
        title: 'Bank Name',
        type: InputType.text,
        description: 'Enter or select the name of your primary bank from the list.',
      ),
      InputGuideline(
        id: 's3_holder_name',
        title: 'Account Holder Name',
        type: InputType.text,
        description: 'Enter your name exactly as it appears in your bank records.',
      ),
      InputGuideline(
        id: 's3_branch',
        title: 'Branch Name',
        type: InputType.text,
        description: 'Enter your bank branch location (e.g. Anna Nagar Chennai).',
      ),
      InputGuideline(
        id: 's3_ifsc',
        title: 'IFSC Code',
        type: InputType.text,
        description: 'Enter the 11-character IFSC code of your branch — find it on your cheque or passbook.',
      ),
      InputGuideline(
        id: 's3_acc_num',
        title: 'Account Number',
        type: InputType.text,
        description: 'Enter your bank account number carefully including all leading zeros.',
      ),
      InputGuideline(
        id: 's3_micr',
        title: 'MICR Code',
        type: InputType.text,
        mandatory: false,
        description: 'Optional 9-digit code printed at the bottom of your cheque leaf.',
      ),
      // Primary bank statement upload
      InputGuideline(
        id: 's3_statement',
        title: 'Bank Statement — Primary (Last 6 Months)',
        type: InputType.upload,
        description: 'Upload your primary bank statement as a PDF covering the last 6–12 months. Used to analyze income, EMI, and spending patterns.',
        procedure: [
          'Open your bank\'s mobile app',
          'Navigate to Accounts → Statements',
          'Select last 6 months date range',
          'Download as PDF (avoid password-protected PDFs if possible)',
          'Upload the downloaded PDF here',
        ],
        youtubeTitle: 'How to download bank statement PDF from mobile app',
      ),
      // Secondary bank (optional)
      InputGuideline(
        id: 's3_sec_bank',
        title: 'Secondary Bank Name',
        type: InputType.text,
        mandatory: false,
        description: 'If you have a second bank account, enter the bank name here.',
      ),
      InputGuideline(
        id: 's3_sec_acc',
        title: 'Secondary Account Number',
        type: InputType.text,
        mandatory: false,
        description: 'Enter your secondary bank account number if applicable.',
      ),
      InputGuideline(
        id: 's3_sec_statement',
        title: 'Bank Statement — Secondary (Optional)',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload the second bank account statement if you have one. Improves income analysis accuracy.',
        procedure: [
          'Download from your second bank app or net banking',
          'Select last 6 months range',
          'Upload PDF here',
        ],
        youtubeTitle: 'How to download bank statement from net banking',
      ),
      // UPI
      InputGuideline(
        id: 's3_upi_platform',
        title: 'UPI Platform',
        type: InputType.text,
        mandatory: false,
        description: 'Select the UPI app you use most — Google Pay, PhonePe, Paytm, etc.',
      ),
      InputGuideline(
        id: 's3_upi_statement',
        title: 'UPI Transaction Statement (Optional)',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload a UPI transaction export. Improves income and payment analysis beyond bank statement.',
        procedure: [
          'Open Google Pay / PhonePe / Paytm app',
          'Go to Transaction History',
          'Export or download statement as PDF/CSV',
          'Upload here',
        ],
        youtubeTitle: 'How to download UPI statement from Google Pay or PhonePe',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — UTILITY BILLS
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 4,
    title: 'Utility Bills',
    emoji: '💡',
    inputs: [
      // Electricity
      InputGuideline(
        id: 's4_electricity',
        title: 'Electricity Bills (Last 6 Months)',
        type: InputType.upload,
        description: 'Upload 6 months of electricity bills. Used to verify your address and check regular payment behavior.',
        procedure: [
          'Download bills from your DISCOM / electricity board website or app',
          'OR scan/photograph your paper bills clearly',
          'Upload all 6 months in order (oldest to newest)',
          'Each bill must show: consumer number, amount, and due date',
        ],
        youtubeTitle: 'EB bill guidance',
        youtubeUrl: 'https://youtu.be/R4o0ANijOxs?si=zGunB63b3HBdwqM_',
      ),
      // Gas
      InputGuideline(
        id: 's4_gas',
        title: 'Gas / LPG Bills (Last 6 Months)',
        type: InputType.upload,
        description: 'Upload 6 months of LPG cylinder booking receipts or piped gas bills. Confirms consistent household address.',
        procedure: [
          'Open your gas provider app (Indane, HP Gas, Bharat Gas)',
          'Download booking receipts for the last 6 months',
          'OR photograph paper receipts clearly',
          'Consumer number must be same across all months',
        ],
        youtubeTitle: 'Gas bill guidance',
        youtubeUrl: 'https://youtu.be/HZW8S9hKWmY?si=YgCV_gIHt6KGjpaZ',
      ),
      // Mobile
      InputGuideline(
        id: 's4_mobile',
        title: 'Mobile Phone Bills (Last 6 Months)',
        type: InputType.upload,
        description: 'Upload 6 months of postpaid bills or prepaid recharge receipts. Confirms active mobile identity over time.',
        procedure: [
          'Open your operator app (MyJio, MyAirtel, Vi App)',
          'Go to Bills / Recharge History',
          'Download last 6 bills or receipts',
          'Mobile number must be same across all 6 months',
        ],
        youtubeTitle: 'How to download mobile bill from Jio Airtel Vi app',
      ),
      // Rent
      InputGuideline(
        id: 's4_rent',
        title: 'Rent Proof (if renting)',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload proof of rent payment — one of: rental agreement, 6 rent receipts, or leave auto-detection from bank statement.',
        procedure: [
          'Option 1: Upload signed rental agreement PDF',
          'Option 2: Upload rent receipts for last 6 months',
          'Option 3: Leave blank — system auto-detects rent from bank statement',
        ],
        youtubeTitle: 'How to make rent receipt India for landlord tenant',
      ),
      // WiFi
      InputGuideline(
        id: 's4_wifi',
        title: 'WiFi / Internet Bills',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload up to 6 months of internet/broadband bills. Optional but improves your utility score.',
        procedure: [
          'Download from your ISP portal (Airtel, Jio Fiber, ACT, etc.)',
          'OR photograph your physical bill',
          'Upload any available months — minimum 1 required if selecting this',
        ],
        youtubeTitle: 'How to download broadband bill online India',
      ),
      // OTT
      InputGuideline(
        id: 's4_ott',
        title: 'OTT Subscription Proof',
        type: InputType.upload,
        mandatory: false,
        description: 'Screenshot of active subscription to Netflix, Hotstar, Prime, etc. Shows discretionary payment behavior.',
        procedure: [
          'Open your OTT app → Account / Subscription',
          'Take a screenshot showing your active plan and renewal date',
          'Upload here',
        ],
        youtubeTitle: 'How to show OTT subscription proof India',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5 — WORK PROOF (DYNAMIC — 4 CATEGORIES)
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 5,
    title: 'Work Proof',
    emoji: '💼',
    inputs: [], // filled via workTypeCategories
    workTypeCategories: [

      // ── PLATFORM WORKER ──────────────────────────────────────
      WorkTypeCategory(
        id: 'platform',
        name: 'Platform Worker',
        icon: '🛵',
        inputs: [
          InputGuideline(
            id: 's5p_vehicle_num',
            title: 'Vehicle Registration Number',
            type: InputType.text,
            description: 'Enter your vehicle registration as on the RC book (e.g. TN09AB1234).',
          ),
          InputGuideline(
            id: 's5p_rc',
            title: 'RC Book (Registration Certificate)',
            type: InputType.upload,
            description: 'Upload a clear photo of your RC book front page showing vehicle details and owner name.',
            procedure: [
              'Open RC book to the first page',
              'Capture a clear, undamaged photo',
              'Vehicle number and owner name must be fully visible',
            ],
            youtubeTitle: 'RC book and insurance guidance',
            youtubeUrl: 'https://youtu.be/oukaLiYTSZ0?si=PrA8FSoI8-Ot5aad',
          ),
          InputGuideline(
            id: 's5p_dl',
            title: 'Driving Licence (Front & Back)',
            type: InputType.upload,
            description: 'Upload front and back of your driving licence. Name and vehicle class must be visible.',
            procedure: [
              'Photograph DL front side (name, photo, licence number)',
              'Photograph DL back side (authorised vehicle classes)',
              'Licence must be valid — check expiry date',
            ],
            youtubeTitle: 'How to upload driving licence for KYC India',
          ),
          InputGuideline(
            id: 's5p_vehicle_ins',
            title: 'Vehicle Insurance Policy',
            type: InputType.upload,
            description: 'Upload your valid vehicle insurance policy document.',
            procedure: [
              'Download from your insurance provider app or portal',
              'OR upload a photo of the physical policy certificate',
              'Policy must be active and not expired',
            ],
            youtubeTitle: 'Vehicle insurance guidance',
            youtubeUrl: 'https://youtu.be/xZJ5ahda03c?si=iXAFRxlFGplhJsNH',
          ),
          InputGuideline(
            id: 's5p_earnings',
            title: 'Platform Earnings Screenshots (Last 3 Months)',
            type: InputType.upload,
            description: 'Upload 3 monthly earnings screenshots from your delivery/ride platform — Swiggy, Zomato, Ola, Uber, etc.',
            procedure: [
              'Open your gig platform app',
              'Go to Earnings → select monthly view',
              'Take a screenshot showing total earnings, trip count, and your name',
              'Repeat for each of the last 3 months',
            ],
            youtubeTitle: 'How to take earnings screenshot from Swiggy Zomato Uber app',
          ),
        ],
      ),

      // ── VENDOR / SELLER ──────────────────────────────────────
      WorkTypeCategory(
        id: 'vendor',
        name: 'Vendor / Seller',
        icon: '🛒',
        inputs: [
          InputGuideline(
            id: 's5v_svanidhi_id',
            title: 'SVANidhi Application ID',
            type: InputType.text,
            description: 'Enter your PM SVANidhi loan application reference number if enrolled.',
          ),
          InputGuideline(
            id: 's5v_svanidhi_letter',
            title: 'SVANidhi Approval Letter',
            type: InputType.upload,
            description: 'Upload the SVANidhi loan sanction/approval letter from the lending bank or MFI.',
            procedure: [
              'Check pmsvanidhi.mhua.gov.in for status',
              'Download the approval letter PDF',
              'OR upload a photo of the physical letter',
            ],
            youtubeTitle: 'About schemes (SVANidhi context)',
            youtubeUrl: 'https://www.youtube.com/live/yPJ9DI63Uz0?si=_Uk4l7mbC2hO2S_m',
          ),
          InputGuideline(
            id: 's5v_trade_lic',
            title: 'Municipal Trade Licence',
            type: InputType.upload,
            description: 'Upload your trade licence issued by the local municipal corporation. Confirms formal business registration.',
            procedure: [
              'Download from your city corporation portal',
              'OR upload a photo of the physical certificate',
              'Licence must be valid and not expired',
            ],
            youtubeTitle: 'How to get municipal trade licence India',
          ),
          InputGuideline(
            id: 's5v_gst',
            title: 'GST Certificate (Optional)',
            type: InputType.upload,
            mandatory: false,
            description: 'If GST-registered, upload the GST registration certificate.',
            procedure: [
              'Login to gst.gov.in',
              'Download your GST Registration Certificate PDF',
            ],
            youtubeTitle: 'How to download GST registration certificate online',
          ),
          InputGuideline(
            id: 's5v_market',
            title: 'Market / Stall Proof (Optional)',
            type: InputType.upload,
            mandatory: false,
            description: 'Any allotment letter, rent receipt, or photo of your market stall location.',
            procedure: [
              'Upload an allotment letter from municipal authority',
              'OR a rent receipt for your stall space',
              'OR a clear photo of your operating stall',
            ],
            youtubeTitle: 'Street vendor stall proof documents India',
          ),
        ],
      ),

      // ── SKILLED TRADESPERSON ─────────────────────────────────
      WorkTypeCategory(
        id: 'trades',
        name: 'Skilled Tradesperson',
        icon: '🔧',
        inputs: [
          InputGuideline(
            id: 's5t_skill_id',
            title: 'Skill Certificate ID',
            type: InputType.text,
            description: 'Enter your NSDC/NSQF skill certificate ID number printed on your certificate.',
          ),
          InputGuideline(
            id: 's5t_nsdc_cert',
            title: 'NSDC / Skill India Certificate',
            type: InputType.upload,
            description: 'Upload your NSDC or Skill India certificate for your trade (electrician, plumber, carpenter, etc.).',
            procedure: [
              'Download from skillindiadigital.gov.in or NSDC portal',
              'OR upload a clear photo of the physical certificate',
              'Certificate holder name must match Aadhaar',
            ],
            youtubeTitle: 'Skill India / NSDC certificate guidance',
            youtubeUrl: 'https://youtu.be/W4D1ionJoD4?si=Zrg9otPJDSvZgblr',
          ),
          InputGuideline(
            id: 's5t_work_order',
            title: 'Work Order / Completion Letter',
            type: InputType.upload,
            description: 'Upload a signed work order or job completion letter from a client or contractor.',
            procedure: [
              'Photograph the signed work order document',
              'Client name, work value in rupees, and dates must be visible',
              'Can be a recently completed job',
            ],
            youtubeTitle: 'Work order guidance',
            youtubeUrl: 'https://youtu.be/F8rtebHpTIM?si=0qqOiP205I8o5IHw',
          ),
          InputGuideline(
            id: 's5t_exp_cert',
            title: 'Experience Certificate (Optional)',
            type: InputType.upload,
            mandatory: false,
            description: 'Upload any experience or reference certificate from a previous employer or contractor.',
            procedure: [
              'Upload the certificate as a photo or scan',
              'Must include your name and period of work',
            ],
            youtubeTitle: 'Experience certificate format India',
          ),
        ],
      ),

      // ── FREELANCER ───────────────────────────────────────────
      WorkTypeCategory(
        id: 'freelancer',
        name: 'Freelancer',
        icon: '💻',
        inputs: [
          InputGuideline(
            id: 's5f_profile',
            title: 'Freelance Platform Profile Screenshot',
            type: InputType.upload,
            description: 'Screenshot of your profile on Upwork, Fiverr, Freelancer.com, or similar platform showing your name, rating, and earnings.',
            procedure: [
              'Open your freelance platform in a browser or app',
              'Go to your Profile or Dashboard',
              'Screenshot showing: account name, total earnings, member-since date, rating',
              'Upload the screenshot here',
            ],
            youtubeTitle: 'How to take freelancer profile screenshot for verification',
          ),
          InputGuideline(
            id: 's5f_invoice',
            title: 'Client Invoice (Minimum 1)',
            type: InputType.upload,
            description: 'Upload at least 1 invoice issued to a client for a completed project. Amount must match a bank credit.',
            procedure: [
              'Export your invoice as PDF from your billing tool',
              'Invoice must show: client name, amount in rupees, date, and your name',
              'Upload up to 5 invoices for stronger verification',
            ],
            youtubeTitle: 'How to create freelance invoice India for verification',
          ),
          InputGuideline(
            id: 's5f_portfolio',
            title: 'Portfolio Proof (Optional)',
            type: InputType.upload,
            mandatory: false,
            description: 'Screenshots of your work samples, GitHub, Behance, or any portfolio link proving active freelance projects.',
            procedure: [
              'Take screenshots of your portfolio pages',
              'OR upload a PDF of your portfolio',
            ],
            youtubeTitle: 'How to create portfolio for freelancers India',
          ),
          InputGuideline(
            id: 's5f_gst',
            title: 'GST Certificate (Optional)',
            type: InputType.upload,
            mandatory: false,
            description: 'If GST-registered, upload your GST certificate — improves verification strength.',
            procedure: [
              'Login to gst.gov.in',
              'Download your Registration Certificate PDF',
            ],
            youtubeTitle: 'How to download GST certificate online India',
          ),
        ],
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 6 — GOVERNMENT SCHEMES (ALL OPTIONAL)
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 6,
    title: 'Government Schemes',
    emoji: '🏛️',
    inputs: [
      InputGuideline(
        id: 's6_eshram_uan',
        title: 'eShram UAN Number',
        type: InputType.text,
        mandatory: false,
        description: '12-digit Universal Account Number from your eShram registration.',
      ),
      InputGuideline(
        id: 's6_eshram_card',
        title: 'eShram Card',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your eShram registration card showing your name and UAN number. Confirms formal gig worker registration.',
        procedure: [
          'Register free at eshram.gov.in (link Aadhaar)',
          'Download your eShram card from the portal',
          'OR photograph your physical card',
        ],
        youtubeTitle: 'E-SHRAM guidance',
        youtubeUrl: 'https://youtu.be/P2PVvctq8j0?si=b295XMXc-rltHP8Z',
      ),
      InputGuideline(
        id: 's6_pmsym_id',
        title: 'PM-SYM Pension Account Number',
        type: InputType.text,
        mandatory: false,
        description: 'Pension account number under PM Shram Yogi Maandhan scheme.',
      ),
      InputGuideline(
        id: 's6_pmsym_cert',
        title: 'PM-SYM Certificate',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your PM-SYM pension registration certificate. Monthly contributions verified from bank statement.',
        procedure: [
          'Enrol at nearest CSC (Common Service Centre)',
          'Collect the registration certificate',
          'Upload a photo or scan of the certificate',
        ],
        youtubeTitle: 'PM SYM pension scheme registration and certificate India',
      ),
      InputGuideline(
        id: 's6_pmjjby',
        title: 'PMJJBY Life Insurance Certificate',
        type: InputType.upload,
        mandatory: false,
        description: 'Certificate for PM Jeevan Jyoti Bima Yojana — Rs.2 lakh life cover at Rs.436/year.',
        procedure: [
          'Collect the PMJJBY certificate from your bank',
          'OR download from your bank app',
          'Annual auto-debit from bank confirms enrollment',
        ],
        youtubeTitle: 'PMJJBY life insurance certificate download India',
      ),
      InputGuideline(
        id: 's6_mudra_id',
        title: 'PMMY MUDRA Loan Account Number',
        type: InputType.text,
        mandatory: false,
        description: 'Loan account number under PM MUDRA scheme from your lending bank.',
      ),
      InputGuideline(
        id: 's6_mudra_receipt',
        title: 'MUDRA Loan Acknowledgement Receipt',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your MUDRA loan sanction letter or disbursement receipt.',
        procedure: [
          'Collect the sanction letter from your lending bank',
          'Upload the PDF or a clear photo of the letter',
        ],
        youtubeTitle: 'MUDRA loan sanction letter documents India',
      ),
      InputGuideline(
        id: 's6_ppf_acc',
        title: 'PPF Account Number',
        type: InputType.text,
        mandatory: false,
        description: 'Public Provident Fund account number — confirms long-term savings discipline.',
      ),
      InputGuideline(
        id: 's6_ppf_passbook',
        title: 'PPF Passbook (First Page)',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload the first page of your PPF passbook showing account number, bank, and holder name.',
        procedure: [
          'Open your PPF passbook to the first page',
          'Capture a clear photo — account number must be visible',
          'OR download from your bank\'s net banking',
        ],
        youtubeTitle: 'PPF account passbook first page India',
      ),
      InputGuideline(
        id: 's6_svanidhi_id',
        title: 'SVANidhi Application ID',
        type: InputType.text,
        mandatory: false,
        description: 'PM SVANidhi loan reference ID for street vendors.',
      ),
      InputGuideline(
        id: 's6_svanidhi_letter',
        title: 'SVANidhi Approval Letter',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload the SVANidhi loan sanction letter. Loan repayments are verified in your bank statement.',
        procedure: [
          'Check pmsvanidhi.mhua.gov.in',
          'Download the approval/sanction letter',
          'Upload as PDF or photo',
        ],
        youtubeTitle: 'PM SVANidhi loan status check and letter download',
      ),
      InputGuideline(
        id: 's6_udyam',
        title: 'Udyam / MSME Registration Certificate',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your Udyam registration certificate if you are a registered micro-business.',
        procedure: [
          'Login to udyamregistration.gov.in',
          'Download your Udyam Registration Certificate PDF',
        ],
        youtubeTitle: 'MSME / Udyam guidance',
        youtubeUrl: 'https://youtu.be/ZVVp9JD0-2g?si=ZNQdHm9W0v7R_irY',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 7 — INSURANCE
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 7,
    title: 'Insurance',
    emoji: '🛡️',
    inputs: [
      InputGuideline(
        id: 's7_health',
        title: 'Health Insurance Policy',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your active health or medical insurance policy. Shows financial resilience — adds up to 18 score points.',
        procedure: [
          'Download your policy document from the insurer\'s app or portal',
          'OR upload a photo of the physical policy certificate',
          'Policy must be active — check the validity period',
          'Family floater plans are accepted',
        ],
        youtubeTitle: 'Health insurance guidance',
        youtubeUrl: 'https://youtu.be/V9V2JdHdRlU?si=q4o1egm3B5Hkvy4_',
      ),
      InputGuideline(
        id: 's7_vehicle',
        title: 'Vehicle Insurance Policy',
        type: InputType.upload,
        mandatory: false, // mandatory if vehicle=yes, handled by app logic
        description: 'Upload your vehicle insurance policy. MANDATORY if you selected "Yes" for vehicle ownership in Step-1.',
        procedure: [
          'Download from your insurer\'s app or portal',
          'OR photograph the policy certificate or RC Smart Card',
          'Policy must be valid — not expired',
        ],
        youtubeTitle: 'Vehicle insurance guidance',
        youtubeUrl: 'https://youtu.be/xZJ5ahda03c?si=iXAFRxlFGplhJsNH',
      ),
      InputGuideline(
        id: 's7_life',
        title: 'Life Insurance Policy',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your life insurance policy document. Adds financial safety indicators to your credit profile.',
        procedure: [
          'Download policy bond from LIC or private insurer portal',
          'OR upload a photo of the physical policy document',
          'Policy must be in force — not lapsed',
        ],
        youtubeTitle: 'Life insurance guidance',
        youtubeUrl: 'https://youtu.be/hriOoaE0VLY?si=GWEs3_4Fld09yASp',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 8 — ITR & GST
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 8,
    title: 'ITR & GST',
    emoji: '📋',
    inputs: [
      // ITR
      InputGuideline(
        id: 's8_itr_pan',
        title: 'PAN (for ITR)',
        type: InputType.text,
        mandatory: false,
        description: 'Enter your PAN number — pre-filled from Step-2 if already provided.',
      ),
      InputGuideline(
        id: 's8_itr_name',
        title: 'Name as per ITR',
        type: InputType.text,
        mandatory: false,
        description: 'Enter your name exactly as filed on your Income Tax Return.',
      ),
      InputGuideline(
        id: 's8_itr_income',
        title: 'Annual Income (as per ITR)',
        type: InputType.text,
        mandatory: false,
        description: 'Enter your total annual income as declared in your last filed ITR.',
      ),
      InputGuideline(
        id: 's8_itr_doc',
        title: 'ITR Acknowledgment / Form',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your ITR-V acknowledgment PDF from the Income Tax portal. Used for income validation.',
        procedure: [
          'Login to incometax.gov.in',
          'Go to e-File → Income Tax Returns → View Filed Returns',
          'Click on the latest filed return and download ITR-V Acknowledgment',
          'Upload the downloaded PDF here',
        ],
        youtubeTitle: 'ITR guidance',
        youtubeUrl: 'https://youtu.be/ZPNxTjPB3Yw?si=OGY0FLZJ_Wt6DCw5',
      ),
      // GST
      InputGuideline(
        id: 's8_gstin',
        title: 'GSTIN Number',
        type: InputType.text,
        mandatory: false,
        description: 'Enter your 15-character Goods and Services Tax Identification Number.',
      ),
      InputGuideline(
        id: 's8_gst_biz_name',
        title: 'Business Name (as per GST)',
        type: InputType.text,
        mandatory: false,
        description: 'Enter your registered business name as per your GST certificate.',
      ),
      InputGuideline(
        id: 's8_gst_turnover',
        title: 'Annual Turnover (as per GST)',
        type: InputType.text,
        mandatory: false,
        description: 'Enter your annual business turnover as declared in GST returns.',
      ),
      InputGuideline(
        id: 's8_gst_return',
        title: 'GST Registration Certificate / Returns',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload your GST registration certificate or GSTR filing summary. Confirms business income.',
        procedure: [
          'Login to gst.gov.in',
          'Download your GST Registration Certificate from My Profile',
          'OR download GSTR-1/3B acknowledgment from Returns Dashboard',
          'Upload the PDF here',
        ],
        youtubeTitle: 'How to download GST certificate and returns from GST portal India',
      ),
    ],
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 9 — EMI / LOAN BEHAVIOUR
  // ══════════════════════════════════════════════════════════════════════════
  StepGuideline(
    stepNumber: 9,
    title: 'EMI / Loan Behaviour',
    emoji: '💳',
    inputs: [
      InputGuideline(
        id: 's9_lender',
        title: 'Lender Name',
        type: InputType.text,
        description: 'Enter the name of the bank or NBFC you are paying an EMI to (e.g. HDFC Bank, Bajaj Finance).',
      ),
      InputGuideline(
        id: 's9_emi_amount',
        title: 'EMI Amount',
        type: InputType.text,
        description: 'Enter your monthly EMI amount in rupees — the fixed amount debited each month.',
      ),
      InputGuideline(
        id: 's9_prev_debit',
        title: 'Previous Debit Date',
        type: InputType.text,
        description: 'Enter the date of your second-most-recent EMI debit — helps detect payment regularity.',
      ),
      InputGuideline(
        id: 's9_latest_debit',
        title: 'Latest Debit Date',
        type: InputType.text,
        description: 'Enter the date of your most recent EMI payment debit from your bank account.',
      ),
      InputGuideline(
        id: 's9_loan_api',
        title: 'Loan Verification (Optional)',
        type: InputType.text,
        mandatory: false,
        description: 'Optional: enter lender account ID to trigger automated loan repayment verification via API.',
      ),
      InputGuideline(
        id: 's9_loan_doc',
        title: 'Loan Document / EMI Proof (Optional)',
        type: InputType.upload,
        mandatory: false,
        description: 'Upload loan sanction letter, EMI schedule, or repayment proof to strengthen Step-9 verification.',
        procedure: [
          'Open your lender app or portal and download sanction/repayment document',
          'OR upload photo/PDF of your sanction letter or EMI schedule',
          'Ensure lender name, loan account/reference, and amount are visible',
        ],
        youtubeTitle: 'Loan guidance',
        youtubeUrl: 'https://youtu.be/7_CmBxWUA5Y?si=liXgChtIBuA5a8pU',
      ),
    ],
  ),
];
