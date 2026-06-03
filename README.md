# Balance X

iOS personal finance and accounting app built with SwiftUI. Tracks income and expenses, scans receipts with OCR, supports multiple companies with role-based team access, and syncs across devices via Supabase.

## Stack

**iOS App** — Swift · SwiftUI · Combine · Vision (OCR) · WidgetKit · WatchKit  
**Backend** — Node.js · Express · OpenAI API (receipt parsing)  
**Database / Auth** — Supabase (PostgreSQL · Auth · Storage · Edge Functions)  
**Target** — iOS 17+ · Apple Watch  

## Features

**Transactions** — Log income and expense entries with category, amount, date, and notes. Full CRUD with audit trail per entry.

**Receipt Scanning** — Camera or photo library capture. Vision framework extracts text on-device, then the `receipt-api` backend calls OpenAI to parse merchant, amount, date, and line items from the raw OCR text.

**Multi-Company** — One account can own or belong to multiple companies. Invite team members with `owner`, `accountant`, or `viewer` roles. Per-company data isolation.

**Budgets & Goals** — Monthly budgets per category with progress tracking. Savings goals with target amount and deadline.

**Subscriptions Tracker** — Log recurring subscriptions (SaaS, streaming, etc.) with billing cycle and cost.

**Net Worth** — Track asset and liability accounts separately to see net worth over time.

**Reconciliation** — Mark transactions as reconciled against bank statements.

**Recurring Transactions** — Define repeating income or expense rules that generate entries automatically.

**Reports & Export** — Monthly summary, category breakdown. Export to CSV or PDF via `ExportService`.

**Apple Watch Widget** — BXWatch target for glanceable spending summary on the wrist.

**Home Screen Widget** — BXWidget target for quick balance or recent transactions on the iOS home screen.

**Biometric Lock** — Face ID / Touch ID gate before accessing the app.

**Push Notifications** — Budget alerts and monthly report emails via Supabase Edge Functions.

**Offline Mode** — Local cache for transactions, receipts, and companies. Syncs when back online.

## Project Structure

```
Balance X/
├── Balance X/              # Main iOS app target
│   ├── Balance_XApp.swift  # App entry point, environment setup
│   ├── ContentView.swift   # Root view, auth state routing
│   ├── SupabaseManager.swift # Central ObservableObject — auth, CRUD, sync
│   ├── Models.swift        # All data models (Codable structs)
│   ├── Services.swift      # Business logic layer
│   ├── ReceiptService.swift      # Calls receipt-api OCR backend
│   ├── ReceiptVisionAnalyzer.swift # On-device Vision OCR pre-pass
│   ├── AddExpenseView.swift # Transaction entry UI
│   ├── ExportService.swift # CSV/PDF export
│   └── DesignSystem.swift  # Colors, typography, shared components
├── BXWatch/                # Apple Watch target
├── BXWidget/               # iOS home screen widget target
├── autenticacion/          # Auth flow views
├── receipt-api/            # Node.js backend for OpenAI receipt parsing
│   ├── server.js           # Express server, /scan-receipt endpoint
│   └── .env.example        # Required environment variables
└── supabase_launch_schema.sql  # Full database schema
```

## Setup

### iOS App

1. Open `Balance X.xcodeproj` in Xcode.
2. Copy `Balance X/Info.plist.example` to `Balance X/Info.plist` and fill in your values:

```xml
<key>SUPABASE_URL</key>        <string>https://your-project.supabase.co</string>
<key>SUPABASE_PUBLISHABLE_KEY</key> <string>your_supabase_publishable_key</string>
<key>RECEIPT_OCR_BASE_URL</key><string>https://your-receipt-api.railway.app</string>
```

3. Add `supabase-swift` via Swift Package Manager (File → Add Packages).
4. Run on simulator or device.

### Receipt API

```bash
cd receipt-api
cp .env.example .env   # fill in your keys
npm install
node server.js
```

### Database

Run `supabase_launch_schema.sql` in your Supabase project SQL editor to create all tables, RLS policies, and indexes.

## Notes

`Info.plist` is excluded from this repository (listed in `.gitignore`) because it contains environment-specific configuration. Use the values above as a template. No API keys or secrets are committed here.

---

Built by Homer Palada — CS student at Universidad Católica de Honduras, graduating May 2027.
