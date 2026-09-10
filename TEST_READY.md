# Canitera Shopify Theme Test Suite Status (`TEST_READY.md`)

**Date**: 2026-09-10  
**Status**: TEST SUITE READY & ACTIVE  
**Runner File**: `.\verify-theme.ps1` (Project Workspace Root)  
**Compatibility**: Windows PowerShell 5.1 & PowerShell Core (7+)  

---

## 1. Quick Start / Test Runner Commands

### Standard Full Suite Run
```powershell
powershell -ExecutionPolicy Bypass -File .\verify-theme.ps1
```

### Verbose / Detailed Diagnostic Mode
```powershell
powershell -ExecutionPolicy Bypass -File .\verify-theme.ps1 -Detailed
```

### Filtered Execution by Tier
```powershell
# Tier 1: Feature Coverage (25 tests)
powershell -ExecutionPolicy Bypass -File .\verify-theme.ps1 -Tier 1

# Tier 2: Boundary & Corner Cases (8 tests)
powershell -ExecutionPolicy Bypass -File .\verify-theme.ps1 -Tier 2

# Tier 3: Cross-Feature Combinations (4 tests)
powershell -ExecutionPolicy Bypass -File .\verify-theme.ps1 -Tier 3

# Tier 4: Real-World Scenarios (4 tests)
powershell -ExecutionPolicy Bypass -File .\verify-theme.ps1 -Tier 4
```

### Exit Code Standard
- `0`: All tests passed. Storefront integrity verified. Production ready.
- `1`: One or more tests failed. Fails CI/CD pipeline and pinpoints missing files/settings.

---

## 2. Test Coverage & Architecture Summary

The verification suite comprises **41 automated tests** structured across a 4-tier testing hierarchy:

| Tier | Category | Tests | Description & Verification Scope |
|------|----------|:-----:|---------------------------------|
| **Tier 1** | **Feature Coverage** | **25** | **5 Core Features (>=5 tests per feature)**:<br>• **JSON Templates** (5 tests): Syntax, root structure (`sections` & `order`), order referential integrity, block integrity, type declarations.<br>• **Section Existence** (5 tests): Homepage sections, header group, footer group, specialized templates, zero orphan section types.<br>• **Snippet Existence** (5 tests): Layout renders, section renders, nested snippet renders, legacy includes, Canitera core snippets (`rating-stars`, `breadcrumbs`, `responsive-image`, `sticky-atc`, `cart-drawer`).<br>• **Section Schemas** (5 tests): JSON schema parsing, non-empty `name`, preset structure, preset block type referential integrity, Canitera modular presets.<br>• **Settings Configuration** (5 tests): `settings_schema.json` syntax, `settings_data.json` syntax, required categories, `free_shipping_threshold` schema definition, active Canitera settings. |
| **Tier 2** | **Boundary & Corner Cases** | **8** | • Empty order array handling (`"order": []`)<br>• Free shipping division-by-zero protection at €0 threshold<br>• Free shipping spend below threshold (€50 on €75)<br>• Free shipping spend exact threshold (€75 on €75)<br>• Free shipping spend above threshold (€100 on €75, clamped)<br>• Long strings layout blowout protection (word-break & text-overflow in CSS)<br>• Missing image alt attributes detection (all `<img>` tags validated)<br>• HTML escaping audit (`\| escape`, `\| json` in Liquid). |
| **Tier 3** | **Cross-Feature Combinations** | **4** | • Header transparent mode + Hero cover full-bleed overlay<br>• Cart drawer modal + Free shipping meter + Upsell recommendations<br>• Collection filter drawer + Product grid quick-add card integration<br>• Breadcrumbs visual component + Schema.org `BreadcrumbList` JSON-LD structured data. |
| **Tier 4** | **Real-World Scenarios** | **4** | • Complete 16-section homepage architecture verification<br>• 14 specialized page templates integrity and JSON validation<br>• Accessibility semantic checks (WCAG 2.1 AA: HTML5 landmarks, skip link, `:focus-visible`, `prefers-reduced-motion`)<br>• SEO structured data validation (`Organization`, `WebSite`, `Product`, `Article` JSON-LD). |
| **TOTAL**| | **41** | **Comprehensive Full Storefront Theme Verification** |

---

## 3. Initial Baseline Metrics (Repository State Before Milestones)

Running `verify-theme.ps1` against the baseline repository establishes initial verification metrics:

```
================================================================================
  VERIFICATION SUITE SUMMARY REPORT
================================================================================
  Tier 1                              : 21 passed,  4 failed (Total 25)
  Tier 2                              :  7 passed,  1 failed (Total  8)
  Tier 3                              :  1 passed,  3 failed (Total  4)
  Tier 4                              :  2 passed,  2 failed (Total  4)
--------------------------------------------------------------------------------
  OVERALL RESULTS: 31 PASSED, 10 FAILED across 41 tests in ~5.5 seconds.
================================================================================
```

### Baseline Failures & Assigned Milestone Roadmap

The 10 baseline failures directly trace to planned milestone implementations in `PROJECT.md`:

| Test ID | Test Name | Milestone | What Is Needed to Pass |
|---------|-----------|:---------:|------------------------|
| **`T1.3.5`** | Canitera Core Snippets Existence | **M1** | Create `rating-stars.liquid`, `breadcrumbs.liquid`, `responsive-image.liquid`, `sticky-atc.liquid` in `snippets/` |
| **`T1.5.4`** | Free Shipping Threshold Setting in Schema | **M1** | Add `free_shipping_threshold` setting definition to `config/settings_schema.json` |
| **`T1.5.5`** | Canitera Active Settings Configuration | **M1** | Configure `cart_type: "drawer"` and `free_shipping_threshold: 75` in `config/settings_data.json` |
| **`T3.4`** | Breadcrumbs + BreadcrumbList JSON-LD | **M1** | Implement Schema.org `BreadcrumbList` JSON-LD in `snippets/breadcrumbs.liquid` |
| **`T2.2`** | Free Shipping Division-by-Zero Guard | **M2** | Include `if threshold_cents > 0` guard in `snippets/cart-drawer.liquid` |
| **`T3.1`** | Header Transparent Mode + Hero Cover | **M2** | Add transparent header support in `sections/header.liquid` and create `sections/hero-cover.liquid` |
| **`T3.2`** | Cart Drawer + Shipping Meter + Upsells | **M2** | Add free shipping progress meter and upsell recommendations slot to `snippets/cart-drawer.liquid` |
| **`T1.4.5`** | Modular Sections Presets Presence | **M3** | Add presets to the 11 modular Canitera sections in `sections/` |
| **`T4.1`** | 16-Section Homepage Architecture | **M3** | Build all 16 modular sections and configure `templates/index.json` |
| **`T4.2`** | 14 Specialized Page Templates Integrity | **M4** | Create `page.about.json`, `page.travel.json`, `page.faq.json` in `templates/` |

---

## 4. Verification Workflow for Milestone Agents

As each milestone agent completes implementation:
1. Run `powershell -ExecutionPolicy Bypass -File .\verify-theme.ps1`
2. Verify that tests assigned to your milestone transition from `[FAIL]` to `[PASS]`.
3. Ensure no regressions occur in previously passing tests.
4. When all milestones (M1–M4) are complete, `verify-theme.ps1` exits with **code 0 (41 PASSED, 0 FAILED)**.
