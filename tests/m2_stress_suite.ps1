 = 0
 = 0

function Assert-Test {
    param(
        [string],
        [bool],
        [string]
    )
    if () {
        Write-Host  [PASS]  -ForegroundColor Green
        ++
    } else {
        Write-Host  [FAIL] :  -ForegroundColor Red
        ++
    }
}

Write-Host === RUNNING ADVERSARIAL STRESS SUITE FOR MILESTONE 2 === -ForegroundColor Cyan

# 1. Inspect cart-drawer.liquid content
 = snippets\cart-drawer.liquid
 = Get-Content -Path  -Raw -Encoding UTF8

Assert-Test -Name Cart Drawer File Exists -Condition (Test-Path ) -FailMsg File missing
Assert-Test -Name Division-by-Zero Guard in Liquid -Condition ( -match 'threshold[a-zA-Z0-9_]*\s*>\s*0') -FailMsg No threshold > 0 guard
Assert-Test -Name ARIA Dialog Container in Drawer -Condition ( -match 'role=dialog' -and  -match 'aria-modal=true') -FailMsg Missing role=dialog or aria-modal=true
Assert-Test -Name Free Shipping Meter Track Role -Condition ( -match 'role=progressbar') -FailMsg Missing role=progressbar
Assert-Test -Name Free Shipping Aria-valuenow Present -Condition ( -match 'aria-valuenow=') -FailMsg Missing aria-valuenow
Assert-Test -Name Free Shipping Aria-valuemin and valuemax -Condition ( -match 'aria-valuemin=0' -and  -match 'aria-valuemax=100') -FailMsg Missing min/max
Assert-Test -Name Upsell Container Exists -Condition ( -match 'cart-drawer__upsell') -FailMsg Missing cart-drawer__upsell
Assert-Test -Name Upsell Quick Add Button Exists -Condition ( -match 'data-quick-add') -FailMsg Missing data-quick-add
Assert-Test -Name Upsell Quick Add Loading Spinner Exists -Condition ( -match 'loading__spinner') -FailMsg Missing loading spinner
Assert-Test -Name Upsell Fallback Placeholder Exists -Condition ( -match 'Canitera Seatbelt Restraint') -FailMsg Missing fallback placeholder

# 2. Inspect cart-drawer.js
 = assets\cart-drawer.js
 = Get-Content -Path  -Raw -Encoding UTF8

Assert-Test -Name Cart Drawer JS File Exists -Condition (Test-Path ) -FailMsg File missing
Assert-Test -Name Event Delegation for Quick Add -Condition ( -match closest\('\[data-quick-add\]'\)) -FailMsg Missing event delegation
Assert-Test -Name Quick Add Debounce / aria-disabled guard -Condition ( -match aria-disabled) -FailMsg Missing aria-disabled check
Assert-Test -Name Section Rendering API requests cart-drawer -Condition ( -match 'cart-drawer') -FailMsg Missing cart-drawer in sections to render
Assert-Test -Name Section Rendering API requests cart-icon-bubble -Condition ( -match 'cart-icon-bubble') -FailMsg Missing cart-icon-bubble in sections to render
Assert-Test -Name Focus Trap Called on transitionend -Condition ( -match trapFocus\() -FailMsg Missing trapFocus
Assert-Test -Name Focus Restored on close -Condition ( -match removeTrapFocus\() -FailMsg Missing removeTrapFocus
Assert-Test -Name PubSub event publish on upsell add -Condition ( -match PUB_SUB_EVENTS\.cartUpdate) -FailMsg Missing pubsub publish

# 3. Inspect cart.js
 = assets\cart.js
 = Get-Content -Path  -Raw -Encoding UTF8
Assert-Test -Name Cart.js Updates Free Shipping Meter -Condition ( -match \.cart-drawer__free-shipping) -FailMsg Missing free shipping selector in onCartUpdate
Assert-Test -Name Cart.js Updates Upsell Slot -Condition ( -match \.cart-drawer__upsell) -FailMsg Missing upsell selector in onCartUpdate

# 4. Inspect CSS for Drawer, Meter & Upsells
 = assets\base.css
 = Get-Content -Path  -Raw -Encoding UTF8
Assert-Test -Name Free Shipping Bar CSS Present -Condition ( -match \.free-shipping-meter__bar) -FailMsg Missing meter bar CSS
Assert-Test -Name Upsell Card CSS Present -Condition ( -match \.cart-drawer__upsell-card) -FailMsg Missing upsell card CSS
Assert-Test -Name Upsell Button Hover State Present -Condition ( -match \.cart-drawer__upsell-btn:hover) -FailMsg Missing hover state
Assert-Test -Name Prefers Reduced Motion Handles Meter -Condition ( -match \.free-shipping-meter__bar -and  -match prefers-reduced-motion) -FailMsg Missing reduced motion
Assert-Test -Name Empty Drawer Hides Meter -Condition ( -match cart-drawer\.is-empty \.cart-drawer__free-shipping) -FailMsg Empty drawer doesn't hide meter
Assert-Test -Name Empty Drawer Hides Upsell -Condition ( -match cart-drawer\.is-empty \.cart-drawer__upsell) -FailMsg Empty drawer doesn't hide upsell

# 5. Math Simulator for Liquid Free Shipping Logic
function Simulate-Liquid-Math([double], [double]) {
     = [Math]::Round( * 100)
     = [Math]::Round( * 100)
    if ( -gt 0) {
        if ( -ge ) {
             = True
             = 100
             = 0
        } else {
             = False
             = [Math]::Round(( * 100.0) / , 1)
            if ( -gt 100) {  = 100 }
            if ( -lt 0) {  = 0 }
             =  - 
        }
    } else {
         = True
         = 100
         = 0
    }
    return @{ Unlocked = ; Progress = ; Remaining =  }
}

# Edge test 1: €0 threshold
 = Simulate-Liquid-Math -Threshold 0 -Total 25.50
Assert-Test -Name Math Edge: €0 threshold immediately unlocks -Condition (.Unlocked -eq True -and .Progress -eq 100) -FailMsg €0 did not unlock

# Edge test 2: €0 threshold with €0 spend
 = Simulate-Liquid-Math -Threshold 0 -Total 0
Assert-Test -Name Math Edge: €0 threshold + €0 spend immediately unlocks -Condition (.Unlocked -eq True -and .Progress -eq 100) -FailMsg €0 threshold + €0 spend failed

# Edge test 3: Negative threshold guard
 = Simulate-Liquid-Math -Threshold -10 -Total 50
Assert-Test -Name Math Edge: Negative threshold handled safely -Condition (.Unlocked -eq True -and .Progress -eq 100) -FailMsg Negative threshold failed

# Edge test 4: Exact threshold
 = Simulate-Liquid-Math -Threshold 75 -Total 75
Assert-Test -Name Math Edge: Exact threshold (€75 on €75) unlocks -Condition (.Unlocked -eq True -and .Progress -eq 100 -and .Remaining -eq 0) -FailMsg Exact spend failed

# Edge test 5: 1 cent away
 = Simulate-Liquid-Math -Threshold 75 -Total 74.99
Assert-Test -Name Math Edge: 1 cent away (€74.99 on €75) remaining is 1 cent -Condition (.Unlocked -eq False -and .Remaining -eq 1) -FailMsg 1 cent away failed

# Edge test 6: Exceeding threshold (€150 on €75)
 = Simulate-Liquid-Math -Threshold 75 -Total 150
Assert-Test -Name Math Edge: Exceeding threshold clamped to 100% -Condition (.Unlocked -eq True -and .Progress -eq 100 -and .Remaining -eq 0) -FailMsg Exceeding spend failed

Write-Host "
Write-Host Total Tests:  | Passed:  | Failed:  -ForegroundColor Red
if ( -gt 0) { exit 1 } else { exit 0 }
