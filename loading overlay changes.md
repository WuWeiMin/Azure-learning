# Loading Overlay - Change Instructions

## Change 1: HTML — Add overlay div and spinner animation

**File:** `_/html/PaymentReconciliationDialog.html`

**Where:** Inside `<body>`, paste this block **before** the `<div class="title-bar">` line.

```html
<div id="loadingOverlay" style="
    display: none;
    position: fixed;
    top: 0; left: 0;
    width: 100%; height: 100%;
    background: rgba(0,0,0,0.4);
    z-index: 9999;
    justify-content: center;
    align-items: center;
">
    <div style="
        background: #ffffff;
        padding: 32px 48px;
        border-radius: 4px;
        text-align: center;
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    ">
        <div id="loadingSpinner" style="
            width: 40px; height: 40px;
            border: 4px solid #f0f0f0;
            border-top: 4px solid #b03050;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin: 0 auto 16px auto;
        "></div>
        <div style="color: #333333; font-size: 14px; font-weight: bold;">
            Loading, please wait...
        </div>
    </div>
</div>

<style>
@keyframes spin {
    0%   { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}
</style>
```

---

## Change 2: JS — Add showLoading and hideLoading functions

**File:** `_/js/PaymentReconciliationLogic.js`

**Where:** Inside the `(function () {` block, paste these two functions
**before** the `function onSearch()` line.

```javascript
function showLoading() {
    var overlay = document.getElementById("loadingOverlay");
    overlay.style.display = "flex";
}

function hideLoading() {
    var overlay = document.getElementById("loadingOverlay");
    overlay.style.display = "none";
}
```

---

## Change 3: JS — Update onSearch() to show and hide the overlay

**File:** `_/js/PaymentReconciliationLogic.js`

**Where:** Replace the entire `function onSearch() { ... }` block with the version below.

Key points:
- `showLoading()` is called immediately when Search is clicked
- All data processing is wrapped inside `setTimeout(..., 50)`
- The 50ms delay gives the browser time to render the overlay before
  the heavy processing starts — without this delay the overlay would
  never appear because JS is single-threaded
- `hideLoading()` is called after rendering is complete

```javascript
function onSearch() {
    showLoading();

    setTimeout(function () {
        var portfolio = document.getElementById("ddPortfolio").value;
        var fromDate = document.getElementById("dpFromDate").value;
        var toDate = document.getElementById("dpToDate").value;

        var allData = [].concat.apply([], Array(1700).fill(PaymentReconciliationMockData || []));

        var filtered = allData.filter(function (rec) {
            var matchPortfolio = !portfolio || rec["Portfolio"] === portfolio;
            var recDate = rec["Transaction Date"] ? rec["Transaction Date"].replace(/\//g, "-") : null;
            var matchFrom = !fromDate || (recDate && recDate >= fromDate);
            var matchTo = !toDate || (recDate && recDate <= toDate);
            return matchPortfolio && matchFrom && matchTo;
        });

        currentResults = filtered;
        renderResults(filtered);
        document.getElementById("btnExport").disabled = filtered.length === 0;

        hideLoading();
    }, 50);
}
```

---

## Summary of files changed

| File | What changed |
|---|---|
| `_/html/PaymentReconciliationDialog.html` | Added overlay div + spinner CSS animation |
| `_/js/PaymentReconciliationLogic.js` | Added showLoading / hideLoading functions |
| `_/js/PaymentReconciliationLogic.js` | Replaced onSearch() with overlay-aware version |
