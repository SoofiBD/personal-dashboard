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

  const initTransactionFilters = () => {
    const frame = document.getElementById("transactions_frame");
    if (!frame) return;
    const form = frame.querySelector("form.transaction-filters");
    if (!form) return;

    const hasTurbo = typeof window.Turbo !== "undefined";
    let debounceTimer;

    const fetchUpdate = () => {
      const url = new URL(form.action, window.location.origin);
      const data = new FormData(form);
      url.search = new URLSearchParams(data).toString();

      fetch(url.toString(), { headers: { "X-Requested-With": "XMLHttpRequest" } })
        .then((resp) => resp.text())
        .then((html) => {
          const doc = new DOMParser().parseFromString(html, "text/html");
          const newFrame = doc.getElementById("transactions_frame");
          if (newFrame) {
            frame.innerHTML = newFrame.innerHTML;
            initTransactionFilters();
          }
          history.replaceState(null, "", url.toString());
        })
        .catch(() => {
          window.location.href = url.toString();
        });
    };

    const trigger = () => {
      if (hasTurbo) {
        form.requestSubmit();
      } else {
        fetchUpdate();
      }
    };

    form.addEventListener("submit", (event) => {
      if (!hasTurbo) {
        event.preventDefault();
        fetchUpdate();
      }
    });

    const textInput = form.querySelector('input[name="q"]');
    if (textInput) {
      textInput.addEventListener("input", () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(trigger, 350);
      });
    }

    form.querySelectorAll("select, input[type='date'], input[type='checkbox']").forEach((el) => {
      el.addEventListener("change", trigger);
    });
  };

  const initQuickAdd = () => {
    const quickAdd = document.querySelector("[data-quick-add]");
    if (!quickAdd || quickAdd.dataset.initialized === "true") return;
    quickAdd.dataset.initialized = "true";

    const sheet = quickAdd.querySelector("[data-quick-add-sheet]") || document.getElementById("quick-add-sheet");
    const backdrop = quickAdd.querySelector(".quick-add-backdrop");
    const trigger = quickAdd.querySelector("[data-quick-add-open]");
    const closeButtons = quickAdd.querySelectorAll("[data-quick-add-close]");
    const amount = quickAdd.querySelector("[data-quick-add-amount]");
    const kindInput = quickAdd.querySelector("[data-quick-add-kind]");
    const categoryInput = quickAdd.querySelector("[data-quick-add-category]");
    const typeButtons = quickAdd.querySelectorAll("[data-quick-add-type]");
    const categoryButtons = quickAdd.querySelectorAll("[data-quick-add-category]");
    const swipeViewport = quickAdd.querySelector("[data-quick-add-swipe]");
    let lastFocused;

    if (!sheet || !backdrop || !trigger) return;

    const visibleCategories = () => Array.from(categoryButtons).filter((button) => !button.hidden);

    const selectCategory = (button) => {
      if (!button || button.hidden) return;
      categoryButtons.forEach((item) => {
        const selected = item === button;
        item.classList.toggle("is-selected", selected);
        item.setAttribute("aria-checked", selected ? "true" : "false");
      });
      categoryInput.value = button.dataset.quickAddCategory;
      button.scrollIntoView({ behavior: motionQuery.matches ? "auto" : "smooth", inline: "center", block: "nearest" });
    };

    const selectType = (kind) => {
      kindInput.value = kind;
      typeButtons.forEach((button) => {
        const selected = button.dataset.quickAddType === kind;
        button.classList.toggle("is-selected", selected);
        button.setAttribute("aria-pressed", selected ? "true" : "false");
      });
      categoryButtons.forEach((button) => {
        button.hidden = button.dataset.quickAddCategoryKind !== kind;
      });
      selectCategory(visibleCategories()[0]);
    };

    const open = () => {
      lastFocused = document.activeElement;
      backdrop.hidden = false;
      sheet.hidden = false;
      requestAnimationFrame(() => quickAdd.classList.add("is-open"));
      document.body.classList.add("quick-add-open");
      window.setTimeout(() => amount?.focus(), motionQuery.matches ? 0 : 180);
    };

    const close = () => {
      quickAdd.classList.remove("is-open");
      document.body.classList.remove("quick-add-open");
      window.setTimeout(() => {
        backdrop.hidden = true;
        sheet.hidden = true;
        lastFocused?.focus();
      }, motionQuery.matches ? 0 : 180);
    };

    trigger.addEventListener("click", open);
    closeButtons.forEach((button) => button.addEventListener("click", close));
    typeButtons.forEach((button) => button.addEventListener("click", () => selectType(button.dataset.quickAddType)));
    categoryButtons.forEach((button) => button.addEventListener("click", () => selectCategory(button)));

    sheet.addEventListener("keydown", (event) => {
      if (event.key === "Escape") close();
      if (event.key !== "Tab") return;
      const focusable = Array.from(sheet.querySelectorAll("button:not([disabled]), input, select, summary")).filter((element) => !element.hidden && element.offsetParent !== null);
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    });

    if (swipeViewport) {
      let startX = 0;
      swipeViewport.addEventListener("touchstart", (event) => { startX = event.touches[0].clientX; }, { passive: true });
      swipeViewport.addEventListener("touchend", (event) => {
        const distance = event.changedTouches[0].clientX - startX;
        if (Math.abs(distance) < 36) return;
        const options = visibleCategories();
        const currentIndex = options.findIndex((button) => button.classList.contains("is-selected"));
        selectCategory(options[Math.max(0, Math.min(options.length - 1, currentIndex + (distance < 0 ? 1 : -1)))]);
      }, { passive: true });
    }

    selectType("expense");
  };

  const registerServiceWorker = () => {
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("/service-worker.js").catch(() => {});
  };

  const initPurchaseScenario = () => {
    const root = document.getElementById("purchase-assessment");
    if (!root) return;

    const monthlyFreeCash = parseFloat(root.dataset.monthlyFreeCash) || 0;
    const availableCash = parseFloat(root.dataset.availableCash) || 0;
    const monthlyExpenses = parseFloat(root.dataset.monthlyExpenses) || 0;
    const savingsGoalApplied = parseFloat(root.dataset.savingsGoalApplied) || 0;

    const fmt = (val) => {
      const num = Number(val) || 0;
      const userCurrency = document.querySelector(".workspace-currency")?.textContent?.trim() || "TRY";
      return `${num.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${userCurrency}`;
    };

    const statusFor = (down, monthly, affectsGoal) => {
      const mfc = monthlyFreeCash - monthly;
      const buffer = availableCash - down - monthlyExpenses;
      if (mfc < 0 || buffer < 0) return "defer";
      if (monthly > 0 || affectsGoal) return "plan";
      return "comfortable";
    };

    const statusLabel = (s) => {
      const map = {
        comfortable: root.dataset.labelComfortable || "Comfortable",
        plan: root.dataset.labelPlan || "Plan",
        defer: root.dataset.labelDefer || "Defer"
      };
      return map[s];
    };

    const computeScenario = (card) => {
      const key = card.dataset.scenario;
      const months = parseInt(card.dataset.months, 10) || 0;
      const price = parseFloat(root.querySelector('[data-scenario-input="price"]').value) || 0;
      const baseDown = parseFloat(root.querySelector('[data-scenario-input="down_payment"]').value) || 0;

      let down, monthly, affectsGoal = false;
      if (key === "cash") {
        down = price;
        monthly = 0;
      } else if (key === "savings_goal") {
        const remainingAfterGoal = Math.max(price - savingsGoalApplied, 0);
        down = Math.min(baseDown, remainingAfterGoal);
        monthly = (remainingAfterGoal - down) / 12.0;
        affectsGoal = true;
      } else if (months > 0) {
        down = baseDown;
        monthly = (price - baseDown) / months;
      } else {
        down = baseDown;
        monthly = 0;
      }

      const status = statusFor(down, monthly, affectsGoal);
      const mfcAfter = monthlyFreeCash - monthly;
      const buffer = availableCash - down - monthlyExpenses;

      card.classList.remove("status-comfortable", "status-plan", "status-defer");
      card.classList.add(`status-${status}`);

      const setField = (name, value, isNegative) => {
        const el = card.querySelector(`[data-field="${name}"]`);
        if (!el) return;
        el.textContent = fmt(value);
        if (isNegative !== undefined) {
          el.classList.toggle("value-negative", isNegative);
          el.classList.toggle("value-positive", !isNegative);
        }
      };

      setField("monthly_cost", monthly);
      setField("down_payment", down);
      setField("safety_buffer", buffer, buffer < 0);
      setField("monthly_free_cash_after", mfcAfter, mfcAfter < 0);

      const badge = card.querySelector(".scenario-status");
      if (badge) {
        badge.textContent = statusLabel(status);
        badge.className = `badge-pill ${status === "comfortable" ? "badge-status-comfortable" : status === "plan" ? "badge-status-plan" : "badge-status-defer"} scenario-status`;
      }
    };

    const recalc = () => {
      root.querySelectorAll(".scenario-card").forEach(computeScenario);
    };

    root.querySelectorAll(".scenario-input").forEach((input) => {
      input.addEventListener("input", recalc);
    });

    recalc();
  };

  const init = () => {
    animateDashboard();
    initBudgetSelector();
    initBudgetCalculator();
    initTransactionFilters();
    initPurchaseScenario();
    initQuickAdd();
    registerServiceWorker();
  };

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", () => {
    if (document.readyState !== "loading") {
      init();
    }
  });
})();
