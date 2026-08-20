/* global gsap */

(() => {
  const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

  const animateDashboard = () => {
    if (motionQuery.matches || typeof window.gsap === "undefined") return;

    const timeline = window.gsap.timeline({ defaults: { ease: "power1.out", clearProps: "all" } });
    const sidebar = document.querySelector(".sidebar");
    const header = document.querySelector(".page-header");
    const cards = document.querySelectorAll(".metric-card");
    const panels = document.querySelectorAll(".panel");
    const items = document.querySelectorAll(".finance-list article, .card-item");
    const flashes = document.querySelectorAll(".flash");

    if (sidebar) timeline.from(sidebar, { x: -12, opacity: 0, duration: 0.28 });
    if (header) timeline.from(header, { y: 12, opacity: 0, duration: 0.32 }, "-=0.12");
    if (cards.length) timeline.from(cards, { y: 12, opacity: 0, duration: 0.3, stagger: 0.055 }, "-=0.12");
    if (panels.length) timeline.from(panels, { y: 10, opacity: 0, duration: 0.3, stagger: 0.045 }, "-=0.18");
    if (items.length) timeline.from(items, { y: 8, opacity: 0, duration: 0.24, stagger: 0.025 }, "-=0.2");
    if (flashes.length) timeline.from(flashes, { y: -8, opacity: 0, duration: 0.22 }, 0);
  };

  const initBudgetSelector = () => {
    const selector = document.getElementById("budget-category-selector");
    if (!selector) return;

    const activeDot = document.getElementById("budget-active-dot");
    const tagDot = document.getElementById("budget-tag-dot");
    const displayName = document.getElementById("budget-display-name");
    const percentPill = document.getElementById("budget-display-percent-pill");
    const percentNum = document.getElementById("budget-display-percent-num");
    const spentEl = document.getElementById("budget-display-spent");
    const plannedEl = document.getElementById("budget-display-planned");
    const progressEl = document.getElementById("budget-display-progress");
    const badgeEl = document.getElementById("budget-display-badge");
    const remainingEl = document.getElementById("budget-display-remaining");
    const noteEl = document.getElementById("budget-display-note");
    const chips = document.querySelectorAll(".budget-chip");
    const activeDisplay = document.getElementById("budget-active-display");

    const userCurrency = document.querySelector(".workspace-currency")?.textContent?.trim() || "TRY";
    const formatCurrency = (val) => {
      const num = Number(val) || 0;
      return `${num.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${userCurrency}`;
    };

    const updateDisplay = (option) => {
      if (!option) return;
      const name = option.dataset.name;
      const color = option.dataset.color || "#3B82F6";
      const spent = Number(option.dataset.spent) || 0;
      const planned = Number(option.dataset.planned) || 0;
      const remaining = Number(option.dataset.remaining) || 0;
      const percent = Number(option.dataset.percent) || 0;
      const rawPercent = Number(option.dataset.rawPercent) || 0;
      const isOver = option.dataset.isOver === "true";
      const badge = option.dataset.badge;
      const note = option.dataset.note;

      if (activeDot) activeDot.style.backgroundColor = color;
      if (tagDot) tagDot.style.backgroundColor = color;
      if (displayName) displayName.textContent = name;
      if (percentNum) percentNum.textContent = rawPercent;

      if (percentPill) {
        if (isOver) {
          percentPill.classList.add("is-over");
        } else {
          percentPill.classList.remove("is-over");
        }
      }

      if (spentEl) spentEl.textContent = formatCurrency(spent);
      if (plannedEl) plannedEl.textContent = ` / ${formatCurrency(planned)}`;

      if (progressEl) {
        progressEl.style.width = `${Math.min(percent, 100)}%`;
        if (isOver) {
          progressEl.classList.add("is-over");
        } else {
          progressEl.classList.remove("is-over");
        }
      }

      if (badgeEl) {
        badgeEl.textContent = badge;
        badgeEl.className = `badge-pill ${isOver ? "badge-status-defer" : "badge-status-comfortable"}`;
      }

      if (remainingEl) remainingEl.textContent = formatCurrency(Math.abs(remaining));
      if (noteEl) noteEl.textContent = ` ${note}`;

      chips.forEach((chip) => {
        if (chip.dataset.categoryTarget === option.value) {
          chip.classList.add("is-active");
        } else {
          chip.classList.remove("is-active");
        }
      });

      if (typeof window.gsap !== "undefined" && !motionQuery.matches && activeDisplay) {
        window.gsap.fromTo(
          activeDisplay,
          { opacity: 0.82, scale: 0.995 },
          { opacity: 1, scale: 1, duration: 0.22, ease: "power1.out" }
        );
      }
    };

    selector.addEventListener("change", () => {
      const selectedOption = selector.options[selector.selectedIndex];
      updateDisplay(selectedOption);
    });

    chips.forEach((chip) => {
      chip.addEventListener("click", () => {
        const targetVal = chip.dataset.categoryTarget;
        for (let i = 0; i < selector.options.length; i++) {
          if (selector.options[i].value === targetVal) {
            selector.selectedIndex = i;
            updateDisplay(selector.options[i]);
            break;
          }
        }
      });
    });
  };

  const initBudgetCalculator = () => {
    const totalDisplay = document.getElementById("budget-total-planned-display");
    const limitInputs = document.querySelectorAll(".budget-limit-input");
    if (!totalDisplay || !limitInputs.length) return;

    const userCurrency = document.querySelector(".workspace-currency")?.textContent?.trim() || "TRY";
    const formatCurrency = (val) => {
      const num = Number(val) || 0;
      return `${num.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${userCurrency}`;
    };

    const calculateTotal = () => {
      let total = 0;
      limitInputs.forEach((input) => {
        const val = parseFloat(input.value) || 0;
        total += val;
      });
      totalDisplay.value = formatCurrency(total);
    };

    limitInputs.forEach((input) => {
      input.addEventListener("input", calculateTotal);
      input.addEventListener("change", calculateTotal);
    });

    calculateTotal();
  };

  const init = () => {
    animateDashboard();
    initBudgetSelector();
    initBudgetCalculator();
  };

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", () => {
    if (document.readyState !== "loading") {
      init();
    }
  });
})();

