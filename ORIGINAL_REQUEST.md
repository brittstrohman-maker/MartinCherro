# Original User Request

## 2026-09-10T01:44:47Z

Build a complete custom Shopify Online Store 2.0 theme for Canitera, a premium dog travel and adventure lifestyle brand (Canis + Itinera), transforming the repository into an editorial, high-converting, accessible storefront.

Working directory: c:\Users\martin\Documents\martin
Integrity mode: development

## Requirements

### R1. Brand Identity, Design System & Theme Settings
- Establish the Canitera visual identity: warm off-white/ivory background (`#FAF8F5`), deep charcoal typography (`#1C1D1D`), muted forest green primary accent (`#2D4030`), warm sand/beige secondary accent (`#D9CBB8`), and restrained darker green.
- Provide Theme Settings (`config/settings_schema.json` & `config/settings_data.json`) allowing customization of color schemes, typography (refined serif / modern sans-serif headings with high-readability body), container widths, subtle border radii, button styles, social links, and free shipping progress bar threshold.
- Implement reusable snippet components: buttons, product cards (hover image swap, sale badges, quick-add), collection cards, icons (search, cart, account, chevron, menu), rating stars, price display, responsive picture/image with lazy-loading, and breadcrumbs.

### R2. Global Header, Announcement Bar, Footer & Ajax Cart Drawer
- Build an announcement bar with customizable messages (e.g., "Adventure starts here — free shipping on orders over €X"), optional dismiss, and Theme Editor controls.
- Implement an editorial sticky header with desktop navigation (Shop, Travel, About, Journal, Contact + mega-menu categories), mobile drawer navigation, live search, account link, and cart badge with subtle scroll transitions and optional transparent hero mode.
- Create a slide-out Ajax cart drawer featuring live quantity updates, item removal, free-shipping threshold progress bar ("You're €X away from free shipping"), dynamic checkout button, and complementary product recommendation slots.
- Construct a 4-column editorial footer (Shop, About, Help, Legal) including newsletter signup, social media icons, payment method badges, and copyright.

### R3. Conversion-Focused Homepage Architecture (16 Configurable Sections)
Construct 16 modular sections with full Shopify Theme Editor block and preset support:
1. Announcement bar
2. Main navigation header
3. Hero / Cover (cinematic lifestyle imagery, "Go Further. Together.", dual CTAs, scroll indicator)
4. Trust / Value strip (minimal icon/text propositions: "Built for the journey", "Thoughtful design", etc.)
5. Featured collection ("Travel better with your best friend" with 4-up desktop / 2-up mobile product cards)
6. Brand story split-image ("Made for the journey" editorial 2-column layout with reversible media)
7. Shop by Adventure collection cards (Road Trips, Weekend Getaways, Beach Days, Outdoor Adventures)
8. Hero product spotlight (featured product with direct variant selector, quantity, add to cart, and shipping notes)
9. Why Canitera (3–4 editorial pillars: Comfort, Safety, Simplicity, Design)
10. Lifestyle full-width image banner ("The best destinations are better together")
11. Social proof / Testimonials (authentic customer review cards/carousel without fabricated data)
12. Community UGC grid (curated lifestyle travel photo gallery with optional links)
13. Journal / Blog preview (3 latest road-trip guides and travel checklists)
14. Journal newsletter signup ("More miles. More memories.")
15. Final CTA banner ("Where will you go next?")
16. Editorial footer

### R4. Complete Specialized Page Templates
- **Product Page (`product.json`)**: Desktop dual-column (media gallery left, sticky purchase form right) + mobile image carousel and sticky bottom ATC bar. Variant pill/swatch picker, dynamic price, accordion tabs (Description, Details, Shipping, Returns, Care), 3–4 Benefit cards, Product Story section with metafield support, 3-step "How It Works" visual guide, and related products.
- **Collection / Shop Page (`collection.json`)**: Breadcrumbs, collection hero, desktop sidebar filters + mobile filter drawer, sort dropdown, and 2-to-4 column responsive product card grid with quick-add.
- **About Page (`page.about.json`)**: Editorial brand manifesto ("Every journey is better together"), brand philosophy pillars (Comfort, Simplicity, Adventure), founder story, and values.
- **Travel Hub (`page.travel.json`)**: Dedicated editorial hub with adventure categories (Road Trips, Beach Days, Mountain Adventures) and interactive essential dog travel checklist.
- **Journal & Article Pages (`blog.json`, `article.json`)**: Editorial magazine layout, featured article highlight, reading time, table of contents, author, date, share buttons, and related products.
- **Customer & Utility Pages**: Polished Contact form with topic selector (`page.contact.json`), searchable FAQ accordion categories (`page.faq.json`), 404 page ("Looks like you've wandered off the trail"), Search page with predictive search support, Password/Coming-Soon page, and styled default policy pages.

### R5. Accessibility, Performance, SEO & Clean Code Quality
- Semantic HTML5, accessible ARIA labels, keyboard focus states, trapped focus on modals/drawers, and `prefers-reduced-motion` compliance.
- Fast performance: native responsive `<picture>` / `image_tag` with `srcset`, lazy loading for below-the-fold assets, zero bloated third-party libraries, and lightweight vanilla JS.
- Valid JSON-LD structured data for Organization, WebSite, Product, BreadcrumbList, and Article.
- Fully compatible with Shopify Online Store 2.0 theme standards and editable via Shopify Theme Customizer.

## Acceptance Criteria

### Theme Architecture & Integrity
- [ ] All templates are valid JSON (`templates/*.json`, `config/settings_schema.json`, `config/settings_data.json`) passing JSON syntax checks.
- [ ] Every section referenced in JSON templates exists in `sections/` with valid schema definitions and default presets.
- [ ] All Liquid snippets referenced with `{% render 'snippet-name' %}` exist in `snippets/`.
- [ ] Theme settings in `config/settings_schema.json` allow store owners to edit colors, typography, header, cart, and social links without writing code.

### Visual & Brand Quality
- [ ] Visual aesthetic matches Canitera's premium outdoor travel direction: warm ivory base, deep charcoal copy, muted forest green, and warm sand accents.
- [ ] Free of childish pet graphics, clip-art paws, cartoon dogs, fake reviews, or dropshipping patterns.
- [ ] Fully responsive on mobile (375px+), tablet, and desktop (1200px+) without horizontal overflow.

### Functional Completeness
- [ ] Product page features sticky purchase box, variant selection, accordion tabs, benefits, how-it-works, and related products.
- [ ] Cart drawer opens via Ajax, updates quantities dynamically, displays free shipping meter, and links to checkout.
- [ ] All 14 custom pages/templates (Homepage, Product, Collection, About, Travel Hub, Blog, Article, Contact, FAQ, 404, Search, Password, Policies) are fully implemented and functional.
- [ ] Verification script (`verify-theme.ps1`) runs without errors and confirms 100% template, section, snippet, and schema integrity.
