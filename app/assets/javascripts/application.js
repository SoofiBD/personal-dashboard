/* global gsap */

(() => {
  const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

  const animateDashboard = () => {
    if (motionQuery.matches || typeof window.gsap === "undefined") return;

    const timeline = window.gsap.timeline({ defaults: { ease: "power2.out" } });
    const launcher = document.querySelector(".module-launcher");
    const sidebar = document.querySelector(".sidebar");
    const header = document.querySelector(".page-header");
    const cards = document.querySelectorAll(".metric-card, .kinetic-card");
    const panels = document.querySelectorAll(".panel");
    const flashes = document.querySelectorAll(".flash");

    if (launcher) {
      timeline.fromTo(launcher, { y: 14, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: 0.42 });
    }
    if (sidebar) timeline.fromTo(sidebar, { x: -12, autoAlpha: 0 }, { x: 0, autoAlpha: 1, duration: 0.28 }, "-=0.18");
    if (header) timeline.fromTo(header, { y: 10, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: 0.28 }, "-=0.14");
    if (cards.length) timeline.fromTo(cards, { y: 12, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: 0.28, stagger: 0.03 }, "-=0.12");
    if (panels.length) timeline.fromTo(panels, { y: 10, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: 0.26, stagger: 0.025 }, "-=0.14");
    if (flashes.length) timeline.fromTo(flashes, { y: -8, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: 0.2 }, 0);
  };

  const initLiveCounters = () => {
    if (motionQuery.matches || typeof window.gsap === "undefined") return;

    const userCurrency = document.querySelector(".workspace-currency")?.textContent?.trim() || "TRY";
    const targets = document.querySelectorAll(".metric-card strong, .summary-metric-val");

    targets.forEach((el) => {
      if (el.dataset.counterBound) return;
      el.dataset.counterBound = "true";

      const rawText = el.textContent.trim();
      const isNegative = rawText.includes("-") || el.classList.contains("value-negative");
      const isPositive = rawText.includes("+") || el.classList.contains("value-positive");

      const match = rawText.replace(/[^0-9,.-]/g, "").replace(/\./g, "").replace(",", ".");
      const numValue = parseFloat(match);
      if (isNaN(numValue) || numValue === 0) return;

      const obj = { val: 0 };
      const prefix = isPositive && rawText.startsWith("+") ? "+" : (isNegative && rawText.startsWith("-") ? "-" : "");

      window.gsap.to(obj, {
        val: numValue,
        duration: 0.8,
        ease: "power2.out",
        onUpdate: () => {
          const formatted = obj.val.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
          el.textContent = `${prefix}${formatted} ${userCurrency}`;
        }
      });
    });
  };

  const initHealthScoreGauge = () => {
    const gauge = document.querySelector(".health-gauge");
    if (!gauge || motionQuery.matches || typeof window.gsap === "undefined") return;

    const score = parseFloat(getComputedStyle(gauge).getPropertyValue("--score")) || 0;
    const strong = gauge.querySelector("strong");

    const obj = { s: 0 };
    window.gsap.to(obj, {
      s: score,
      duration: 0.9,
      ease: "power2.out",
      onUpdate: () => {
        const current = Math.round(obj.s);
        gauge.style.setProperty("--score", current);
        if (strong) strong.textContent = current;
      }
    });

    const trendBars = document.querySelectorAll(".health-trend span");
    if (trendBars.length) {
      window.gsap.from(trendBars, {
        scaleY: 0,
        transformOrigin: "bottom",
        duration: 0.6,
        stagger: 0.05,
        ease: "back.out(1.4)"
      });
    }
  };

  const initProgressBarAnimations = () => {
    if (motionQuery.matches || typeof window.gsap === "undefined") return;

    const bars = document.querySelectorAll(".progress-bar, .progress-fill, .debt-progress-fill");
    bars.forEach((bar) => {
      const targetWidth = bar.style.width || "0%";
      if (targetWidth === "0%") return;
      window.gsap.fromTo(bar, { width: "0%" }, { width: targetWidth, duration: 0.7, ease: "power2.out" });
    });
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

  const initCategorySuggestion = () => {
    const note = document.querySelector("[data-category-suggestion-target='note']");
    const select = document.querySelector("[data-category-suggestion-target='select']");
    if (!note || !select) return;
    let timer;
    note.addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(async () => { if (note.value.trim().length < 2) return; const response = await fetch(`${note.dataset.categorySuggestionUrl}?note=${encodeURIComponent(note.value)}`); const data = await response.json(); if (data.category_id) select.value = data.category_id; }, 250); });
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

  const formatChartCurrency = (val) => {
    const num = Number(val) || 0;
    const userCurrency = document.querySelector(".workspace-currency")?.textContent?.trim() || "TRY";
    return `${num.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${userCurrency}`;
  };

  const initCashFlowChart = () => {
    const canvas = document.getElementById("cashflow-chart");
    if (!canvas || typeof window.Chart === "undefined") return;

    const dataEl = document.getElementById("cashflow-chart-data");
    if (!dataEl) return;

    let rows;
    try {
      rows = JSON.parse(dataEl.textContent);
    } catch (e) {
      return;
    }
    if (!Array.isArray(rows) || !rows.length) return;

    const labels = rows.map((r) => r.label);
    const income = rows.map((r) => Number(r.income) || 0);
    const expenses = rows.map((r) => Number(r.expenses) || 0);
    const net = income.map((v, i) => v - expenses[i]);

    const labelIncome = canvas.dataset.labelIncome || "Gelir";
    const labelExpense = canvas.dataset.labelExpense || "Gider";
    const labelNet = canvas.dataset.labelNet || "Net";

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    new window.Chart(canvas, {
      data: {
        labels,
        datasets: [
          {
            type: "bar",
            label: labelIncome,
            data: income,
            backgroundColor: "rgba(16, 185, 129, 0.85)",
            hoverBackgroundColor: "#10B981",
            borderColor: "#10B981",
            borderRadius: 6,
            maxBarThickness: 34,
          },
          {
            type: "bar",
            label: labelExpense,
            data: expenses,
            backgroundColor: "rgba(59, 130, 246, 0.85)",
            hoverBackgroundColor: "#3B82F6",
            borderColor: "#3B82F6",
            borderRadius: 6,
            maxBarThickness: 34,
          },
          {
            type: "line",
            label: labelNet,
            data: net,
            borderColor: "#F59E0B",
            backgroundColor: "#F59E0B",
            borderWidth: 2,
            tension: 0.35,
            pointRadius: 3,
            pointHoverRadius: 5,
            fill: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: reduceMotion ? false : { duration: 800, easing: "easeOutQuart" },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: "#94A3B8", usePointStyle: true, boxWidth: 8, padding: 16 },
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.92)",
            titleColor: "#E2E8F0",
            bodyColor: "#CBD5E1",
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              label: (ctx) => `${ctx.dataset.label}: ${formatChartCurrency(ctx.parsed.y)}`,
            },
          },
        },
        scales: {
          x: {
            grid: { color: "rgba(148, 163, 184, 0.12)" },
            ticks: { color: "#94A3B8" },
          },
          y: {
            beginAtZero: true,
            grid: { color: "rgba(148, 163, 184, 0.12)" },
            ticks: {
              color: "#94A3B8",
              callback: (value) => formatChartCurrency(value),
            },
          },
        },
      },
    });
  };

  const initSpendingReport = () => {
    const canvas = document.getElementById("spending-donut-chart");
    const dataEl = document.getElementById("spending-report-data");
    if (!canvas || !dataEl || typeof window.Chart === "undefined") return;

    let categories;
    try {
      categories = JSON.parse(dataEl.textContent);
    } catch (e) {
      return;
    }
    if (!Array.isArray(categories) || !categories.length) return;

    const title = document.getElementById("subcategory-title");
    const description = document.getElementById("subcategory-description");
    const content = document.getElementById("subcategory-content");
    const legend = document.getElementById("spending-chart-legend");
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    const formatCurrency = (value) => formatChartCurrency(value);
    const categoryById = (id) => categories.find((category) => String(category.id) === String(id));
    const selectCategory = (id) => {
      const category = categoryById(id);
      if (!category || !title || !description || !content) return;

      document.querySelectorAll("[data-spending-category-id]").forEach((button) => {
        const selected = String(button.dataset.spendingCategoryId) === String(category.id);
        button.classList.toggle("is-selected", selected);
        button.setAttribute("aria-pressed", String(selected));
      });

      title.textContent = category.name;
      content.replaceChildren();
      if (!category.children || !category.children.length) {
        description.textContent = "Bu kategoride seçili dönemde alt kategori harcaması bulunmuyor.";
        content.className = "subcategory-empty";
        content.textContent = "Harcama doğrudan ana kategoriye kaydedilmiş olabilir.";
        return;
      }

      description.textContent = "Seçili dönemdeki alt kategori harcamaları";
      content.className = "subcategory-list";
      category.children.forEach((child) => {
        const row = document.createElement("div");
        row.className = "subcategory-row";
        const label = document.createElement("span");
        label.className = "subcategory-name";
        const dot = document.createElement("span");
        dot.className = "category-color-dot";
        dot.style.backgroundColor = child.color;
        const name = document.createElement("span");
        name.textContent = child.name;
        label.append(dot, name);
        const amount = document.createElement("strong");
        amount.textContent = formatCurrency(child.amount);
        row.append(label, amount);
        content.append(row);
      });
    };

    if (legend) {
      categories.forEach((category) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "spending-legend-item";
        button.dataset.spendingCategoryId = category.id;
        button.setAttribute("aria-pressed", "false");
        const dot = document.createElement("span");
        dot.className = "category-color-dot";
        dot.style.backgroundColor = category.color;
        const label = document.createElement("span");
        label.textContent = `${category.name} · ${formatCurrency(category.current)}`;
        button.append(dot, label);
        button.addEventListener("click", () => selectCategory(category.id));
        legend.append(button);
      });
    }

    document.querySelectorAll(".top-category-button[data-spending-category-id]").forEach((button) => {
      button.addEventListener("click", () => selectCategory(button.dataset.spendingCategoryId));
    });

    new window.Chart(canvas, {
      type: "doughnut",
      data: {
        labels: categories.map((category) => category.name),
        datasets: [{ data: categories.map((category) => Number(category.current) || 0), backgroundColor: categories.map((category) => category.color), borderColor: "transparent", borderWidth: 3, hoverOffset: 8 }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: reduceMotion ? false : { duration: 500, easing: "easeOutQuart" },
        plugins: {
          legend: { display: false },
          tooltip: { backgroundColor: "rgba(15, 23, 42, 0.95)", titleColor: "#F8FAFC", bodyColor: "#CBD5E1", padding: 12, cornerRadius: 8, callbacks: { label: (ctx) => `${ctx.label}: ${formatCurrency(ctx.parsed)}` } },
        },
        onClick: (_event, elements) => { if (elements.length) selectCategory(categories[elements[0].index].id); },
      },
    });
  };

  const initCashFlowForecast = () => {
    const canvas = document.getElementById("cash-flow-forecast-chart");
    const dataEl = document.getElementById("cash-flow-forecast-data");
    if (!canvas || !dataEl || typeof window.Chart === "undefined") return;

    let rows;
    try {
      rows = JSON.parse(dataEl.textContent);
    } catch (e) {
      return;
    }
    if (!Array.isArray(rows) || !rows.length) return;

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const currentBalance = Number(canvas.dataset.startingBalance) || 0;
    const labels = ["Bugün", ...rows.map((row) => row.label)];

    new window.Chart(canvas, {
      type: "line",
      data: {
        labels,
        datasets: [
          { label: "Mevcut bakiye", data: [currentBalance, ...rows.map(() => null)], borderColor: "#3B82F6", backgroundColor: "#3B82F6", borderWidth: 3, pointRadius: 4, pointHoverRadius: 6, spanGaps: false },
          { label: "Tahmini bakiye", data: [currentBalance, ...rows.map((row) => Number(row.balance) || 0)], borderColor: "#F59E0B", backgroundColor: "rgba(245, 158, 11, 0.12)", borderWidth: 3, borderDash: [7, 5], pointRadius: 3, pointHoverRadius: 6, fill: true, tension: 0.25 },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: reduceMotion ? false : { duration: 600, easing: "easeOutQuart" },
        interaction: { mode: "index", intersect: false },
        plugins: { legend: { position: "bottom", labels: { color: "#94A3B8", usePointStyle: true, boxWidth: 8, padding: 16 } }, tooltip: { backgroundColor: "rgba(15, 23, 42, 0.95)", titleColor: "#F8FAFC", bodyColor: "#CBD5E1", padding: 12, cornerRadius: 8, callbacks: { label: (ctx) => `${ctx.dataset.label}: ${formatChartCurrency(ctx.parsed.y)}` } } },
        scales: { x: { grid: { color: "rgba(148, 163, 184, 0.12)" }, ticks: { color: "#94A3B8" } }, y: { grid: { color: "rgba(148, 163, 184, 0.12)" }, ticks: { color: "#94A3B8", callback: (value) => formatChartCurrency(value) } } },
      },
    });
  };

  const initOnboardingWizard = () => {
    const wizardForm = document.getElementById("onboarding-form");
    if (!wizardForm) return;

    let currentStep = 1;
    const totalSteps = 5;

    const stepTabs = document.querySelectorAll(".stepper-step");
    const stepSections = document.querySelectorAll(".wizard-step");
    const progressBar = document.getElementById("stepper-progress-bar");

    const currencyRadios = document.querySelectorAll(".currency-radio");
    const currencyAdornments = document.querySelectorAll("#income-currency-adornment, .budget-currency-adornment, .goal-currency-adornment");
    const incomeInput = document.getElementById("onboarding-income");

    const budgetSummaryIncome = document.getElementById("budget-summary-income");
    const budgetSummaryExpense = document.getElementById("budget-summary-expense");
    const budgetSummaryRemaining = document.getElementById("budget-summary-remaining");
    const allocationInputs = document.querySelectorAll(".allocation-input");

    const goalTarget = document.getElementById("goal-target");
    const goalStarting = document.getElementById("goal-starting");
    const goalMonthly = document.getElementById("goal-monthly");
    const goalEstimatedMonths = document.getElementById("goal-estimated-months");
    const goalEstimateBox = document.getElementById("goal-estimate-box");

    let currentCurrency = document.querySelector(".currency-radio:checked")?.value || "TRY";

    const formatCurrency = (val) => {
      const num = Number(val) || 0;
      return `${num.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${currentCurrency}`;
    };

    const updateStep = (step) => {
      currentStep = Math.max(1, Math.min(totalSteps, step));

      if (progressBar) {
        progressBar.style.width = `${(currentStep / totalSteps) * 100}%`;
      }

      stepTabs.forEach((tab) => {
        const tabStep = parseInt(tab.dataset.step, 10);
        tab.classList.toggle("is-active", tabStep === currentStep);
        tab.classList.toggle("is-completed", tabStep < currentStep);
      });

      stepSections.forEach((section) => {
        const sectionStep = parseInt(section.dataset.stepIndex, 10);
        section.classList.toggle("is-active", sectionStep === currentStep);
      });

      if (currentStep === 4) {
        updateBudgetCalculations();
      } else if (currentStep === 5) {
        updateGoalEstimate();
      }

      window.scrollTo({ top: 0, behavior: "smooth" });
    };

    currencyRadios.forEach((radio) => {
      radio.addEventListener("change", (e) => {
        currentCurrency = e.target.value;
        document.querySelectorAll(".currency-card").forEach((card) => {
          card.classList.toggle("is-selected", card.querySelector(".currency-radio")?.checked);
        });
        currencyAdornments.forEach((adorn) => {
          adorn.textContent = currentCurrency;
        });
        updateBudgetCalculations();
      });
    });

    wizardForm.querySelectorAll(".next-step-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        const next = parseInt(btn.dataset.nextStep, 10);
        updateStep(next);
      });
    });

    wizardForm.querySelectorAll(".prev-step-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        const prev = parseInt(btn.dataset.prevStep, 10);
        updateStep(prev);
      });
    });

    wizardForm.querySelectorAll(".skip-step-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        const skipTo = parseInt(btn.dataset.skipStep, 10);
        updateStep(skipTo);
      });
    });

    stepTabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        const step = parseInt(tab.dataset.step, 10);
        updateStep(step);
      });
    });

    const addAccountBtn = document.getElementById("add-account-row-btn");
    const accountsList = document.getElementById("accounts-builder-list");

    const bindRemoveAccountButtons = () => {
      document.querySelectorAll(".remove-account-btn").forEach((btn) => {
        btn.onclick = () => {
          const row = btn.closest(".account-builder-row");
          if (row && accountsList && accountsList.querySelectorAll(".account-builder-row").length > 1) {
            row.remove();
          }
        };
      });
    };

    if (addAccountBtn && accountsList) {
      addAccountBtn.addEventListener("click", () => {
        const row = document.createElement("div");
        row.className = "account-builder-row";
        row.innerHTML = `
          <div class="account-row-field">
            <label class="field-mini-label">Hesap Adı</label>
            <input type="text" name="accounts[][name]" class="form-control" placeholder="Hesap Adı">
          </div>
          <div class="account-row-field">
            <label class="field-mini-label">Hesap Türü</label>
            <select name="accounts[][kind]" class="form-control">
              <option value="cash">Nakit / Cüzdan</option>
              <option value="bank" selected>Banka Hesabı</option>
              <option value="card">Kredi Kartı</option>
              <option value="savings">Birikim Hesabı</option>
            </select>
          </div>
          <div class="account-row-field">
            <label class="field-mini-label">Açılış Bakiyesi</label>
            <input type="number" name="accounts[][opening_balance]" class="form-control" value="0" step="0.01" placeholder="0.00">
          </div>
          <button type="button" class="action-btn remove-account-btn" title="Kaldır">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon"><path d="M3 6h18"></path><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"></path><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"></path></svg>
          </button>
        `;
        accountsList.appendChild(row);
        bindRemoveAccountButtons();
      });
    }
    bindRemoveAccountButtons();

    document.querySelectorAll(".category-toggle-card").forEach((card) => {
      const checkbox = card.querySelector(".category-toggle-checkbox");
      card.addEventListener("click", (e) => {
        if (e.target !== checkbox) {
          checkbox.checked = !checkbox.checked;
        }
        card.classList.toggle("is-enabled", checkbox.checked);

        const catName = card.dataset.categoryName;
        const budgetCard = document.querySelector(`.budget-allocation-card[data-category="${catName}"]`);
        if (budgetCard) {
          budgetCard.style.display = checkbox.checked ? "" : "none";
        }
        updateBudgetCalculations();
      });
    });

    const updateBudgetCalculations = () => {
      const income = parseFloat(incomeInput?.value) || 0;
      let totalExpense = 0;

      allocationInputs.forEach((input) => {
        const card = input.closest(".budget-allocation-card");
        if (!card || card.style.display !== "none") {
          totalExpense += parseFloat(input.value) || 0;
        }
      });

      const remaining = income - totalExpense;

      if (budgetSummaryIncome) budgetSummaryIncome.textContent = formatCurrency(income);
      if (budgetSummaryExpense) budgetSummaryExpense.textContent = formatCurrency(totalExpense);
      if (budgetSummaryRemaining) {
        budgetSummaryRemaining.textContent = formatCurrency(remaining);
        budgetSummaryRemaining.className = `summary-metric-val ${remaining >= 0 ? "value-positive" : "value-negative"}`;
      }
    };

    if (incomeInput) {
      incomeInput.addEventListener("input", updateBudgetCalculations);
    }
    allocationInputs.forEach((input) => {
      input.addEventListener("input", updateBudgetCalculations);
    });

    const updateGoalEstimate = () => {
      const target = parseFloat(goalTarget?.value) || 0;
      const starting = parseFloat(goalStarting?.value) || 0;
      const monthly = parseFloat(goalMonthly?.value) || 0;
      const needed = Math.max(0, target - starting);

      if (monthly > 0 && needed > 0) {
        const months = Math.ceil(needed / monthly);
        if (goalEstimatedMonths) goalEstimatedMonths.textContent = `~${months} ay`;
        if (goalEstimateBox) goalEstimateBox.style.display = "";
      } else {
        if (goalEstimateBox) goalEstimateBox.style.display = "none";
      }
    };

    [goalTarget, goalStarting, goalMonthly].forEach((el) => {
      el?.addEventListener("input", updateGoalEstimate);
    });

    const skipGoalBtn = document.getElementById("skip-goal-and-submit-btn");
    if (skipGoalBtn) {
      skipGoalBtn.addEventListener("click", () => {
        if (goalTarget) goalTarget.value = "0";
        const goalNameInput = document.getElementById("goal-name");
        if (goalNameInput) goalNameInput.value = "";
        wizardForm.submit();
      });
    }

    updateStep(1);
  };

  const initDocumentWorkspace = () => {
    document.querySelectorAll("[data-document-workspace]").forEach((workspace) => {
      if (workspace.dataset.documentWorkspaceBound) return;
      workspace.dataset.documentWorkspaceBound = "true";

      const editor = workspace.querySelector("[data-markdown-editor]");
      const preview = workspace.querySelector("[data-markdown-preview]");
      const feedback = workspace.querySelector("[data-workspace-feedback]");
      const copyButton = workspace.querySelector("[data-copy-markdown]");
      const saveButton = workspace.querySelector("[data-save-markdown]");
      const zipMarkdown = workspace.querySelector("[data-zip-markdown]");
      const htmlMarkdown = workspace.querySelector("[data-html-markdown]");
      const lineNumbers = workspace.querySelector("[data-markdown-line-numbers]");
      const findInput = workspace.querySelector("[data-markdown-find]");
      const replaceInput = workspace.querySelector("[data-markdown-replace]");
      const findFeedback = workspace.querySelector("[data-find-feedback]");
      const formatUnwrapBtn = workspace.querySelector("[data-format-unwrap]");
      const toggleWrapBtn = workspace.querySelector("[data-toggle-wrap]");
      const statusLines = workspace.querySelector("[data-status-lines]");
      const statusWords = workspace.querySelector("[data-status-words]");
      const statusChars = workspace.querySelector("[data-status-chars]");
      const viewModeBtns = workspace.querySelectorAll("[data-view-mode]");
      let assets = {};

      try {
        assets = JSON.parse(workspace.dataset.documentAssets || "{}");
      } catch (_error) {
        assets = {};
      }

      const escapeHtml = (value) => (value || "").replace(/[&<>'"]/g, (character) => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"}[character]));

      // Parse inline markdown elements
      const parseInline = (text) => {
        let out = escapeHtml(text);
        // Images: ![alt](images/filename)
        out = out.replace(/!\[([^\]]*)\]\(images\/([a-zA-Z0-9._-]+)\)/g, (_match, alt, filename) => {
          const src = assets[filename];
          return src
            ? `<figure class="markdown-figure"><img src="${escapeHtml(src)}" alt="${alt}" loading="lazy"><figcaption>${alt || filename}</figcaption></figure>`
            : `<figure class="markdown-figure is-placeholder"><figcaption>🖼️ ${alt || filename}</figcaption></figure>`;
        });
        // Links: [text](url)
        out = out.replace(/\[([^\]]+)\]\(((?:https?:\/\/|\/)[^\s)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
        // Inline code: `code`
        out = out.replace(/`([^`]+)`/g, '<code>$1</code>');
        // Highlights: ==text==
        out = out.replace(/==([^=]+)==/g, '<mark class="markdown-highlight">$1</mark>');
        // Underlines: <u>text</u> (unescape previously escaped <u>)
        out = out.replace(/&lt;u&gt;(.*?)&lt;\/u&gt;/gi, '<u class="markdown-underline">$1</u>');
        // Strikethrough: ~~text~~
        out = out.replace(/~~([^~]+)~~/g, '<del>$1</del>');
        // Bold: **text** or __text__
        out = out.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
        out = out.replace(/__([^_]+)__/g, '<strong>$1</strong>');
        // Italic: *text* or _text_
        out = out.replace(/(^|[^\*])\*([^*]+)\*([^\*]|$)/g, '$1<em>$2</em>$3');
        out = out.replace(/(^|[^_])_([^_]+)_([^_]|$)/g, '$1<em>$2</em>$3');
        return out;
      };

      // Full document Markdown Parser to clean HTML
      const parseMarkdownToHtml = (markdownText) => {
        if (!markdownText || !markdownText.trim()) {
          return '<div class="markdown-empty-state"><p>Önizlenecek Markdown içeriği yok.</p></div>';
        }

        let content = markdownText.replace(/\r\n/g, "\n");
        let htmlChunks = [];

        // 1. Extract YAML Frontmatter if present
        const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---\n*/);
        if (frontmatterMatch) {
          const metaLines = frontmatterMatch[1].split("\n").filter((l) => l.trim() && !l.trim().startsWith("#"));
          const metaItems = metaLines.map((line) => {
            const splitIdx = line.indexOf(":");
            if (splitIdx === -1) return `<span>${escapeHtml(line)}</span>`;
            const key = line.slice(0, splitIdx).trim();
            const val = line.slice(splitIdx + 1).trim().replace(/^["']|["']$/g, "");
            return `<div class="frontmatter-item"><dt>${escapeHtml(key)}:</dt><dd>${escapeHtml(val)}</dd></div>`;
          }).join("");
          htmlChunks.push(`<div class="markdown-frontmatter-card"><div class="frontmatter-badge">METADATA</div><dl class="frontmatter-list">${metaItems}</dl></div>`);
          content = content.slice(frontmatterMatch[0].length);
        }

        // 2. Split content into logical blocks separated by blank lines
        const rawBlocks = content.split(/\n\s*\n+/);

        for (let block of rawBlocks) {
          block = block.trim();
          if (!block) continue;

          // A. Fenced Code Block
          if (block.startsWith("```")) {
            const codeLines = block.split("\n");
            const lang = codeLines[0].replace(/^```/, "").trim();
            const code = codeLines.slice(1, codeLines[codeLines.length - 1].startsWith("```") ? -1 : undefined).join("\n");
            htmlChunks.push(`<pre class="markdown-code-block" data-lang="${escapeHtml(lang)}"><code>${escapeHtml(code)}</code></pre>`);
            continue;
          }

          // B. Horizontal Rule
          if (/^(?:---|\*\*\*|___)$/.test(block)) {
            htmlChunks.push('<hr class="markdown-divider">');
            continue;
          }

          // C. GFM Table
          if (block.startsWith("|") && block.includes("\n|")) {
            const tableLines = block.split("\n").filter((l) => l.trim().startsWith("|"));
            if (tableLines.length >= 2) {
              const parseRow = (rowStr) => rowStr.split("|").slice(1, -1).map((c) => c.trim());
              const headerCells = parseRow(tableLines[0]);
              const isDelimiter = tableLines[1].replace(/[\s|:-]/g, "").length === 0;
              const dataRows = isDelimiter ? tableLines.slice(2) : tableLines.slice(1);

              let tableHtml = '<div class="table-responsive"><table class="markdown-rendered-table"><thead><tr>';
              headerCells.forEach((c) => {
                tableHtml += `<th>${parseInline(c)}</th>`;
              });
              tableHtml += '</tr></thead><tbody>';
              dataRows.forEach((r) => {
                const cells = parseRow(r);
                tableHtml += '<tr>';
                for (let i = 0; i < headerCells.length; i++) {
                  tableHtml += `<td>${parseInline(cells[i] || "")}</td>`;
                }
                tableHtml += '</tr>';
              });
              tableHtml += '</tbody></table></div>';
              htmlChunks.push(tableHtml);
              continue;
            }
          }

          // D. Blockquotes
          if (block.startsWith(">")) {
            const quoteLines = block.split("\n").map((l) => l.replace(/^>\s?/, "").trim()).filter(Boolean);
            const quoteText = quoteLines.join(" ");
            htmlChunks.push(`<blockquote class="markdown-quote"><p>${parseInline(quoteText)}</p></blockquote>`);
            continue;
          }

          // E. Headings
          const headingMatch = block.match(/^(#{1,6})\s+(.+)$/);
          if (headingMatch && !block.includes("\n")) {
            const level = headingMatch[1].length;
            const headingText = headingMatch[2].trim();
            htmlChunks.push(`<h${level} class="markdown-heading markdown-h${level}">${parseInline(headingText)}</h${level}>`);
            continue;
          }

          // F. Standalone Image
          const standaloneImg = block.match(/^!\[([^\]]*)\]\(images\/([a-zA-Z0-9._-]+)\)$/);
          if (standaloneImg) {
            const alt = standaloneImg[1];
            const filename = standaloneImg[2];
            const src = assets[filename];
            htmlChunks.push(src
              ? `<figure class="markdown-figure"><img src="${escapeHtml(src)}" alt="${escapeHtml(alt)}" loading="lazy"><figcaption>${escapeHtml(alt || filename)}</figcaption></figure>`
              : `<figure class="markdown-figure is-placeholder"><figcaption>🖼️ ${escapeHtml(alt || filename)}</figcaption></figure>`
            );
            continue;
          }

          // G. Unordered List or Ordered List
          const lines = block.split("\n");
          const isUl = lines.some((l) => /^\s*[-*+]\s+/.test(l));
          const isOl = lines.some((l) => /^\s*\d+\.\s+/.test(l));

          if (isUl || isOl) {
            const tag = isOl ? "ol" : "ul";
            let listHtml = `<${tag} class="markdown-list">`;
            let currentItem = "";

            lines.forEach((l) => {
              const bulletMatch = l.match(/^\s*(?:[-*+]|\d+\.)\s+(.+)$/);
              if (bulletMatch) {
                if (currentItem) listHtml += `<li>${parseInline(currentItem)}</li>`;
                currentItem = bulletMatch[1];
              } else if (currentItem) {
                currentItem += " " + l.trim();
              } else {
                currentItem = l.trim();
              }
            });
            if (currentItem) listHtml += `<li>${parseInline(currentItem)}</li>`;
            listHtml += `</${tag}>`;
            htmlChunks.push(listHtml);
            continue;
          }

          // H. Standard Paragraph (Merge soft breaks into smooth paragraph text)
          const paragraphParts = [];
          for (let l of lines) {
            const lineStr = l.trim();
            if (!lineStr) continue;
            // Heading embedded in a block
            const subHead = lineStr.match(/^(#{1,6})\s+(.+)$/);
            if (subHead) {
              if (paragraphParts.length) {
                htmlChunks.push(`<p class="markdown-p">${parseInline(paragraphParts.join(" "))}</p>`);
                paragraphParts.length = 0;
              }
              htmlChunks.push(`<h${subHead[1].length} class="markdown-heading markdown-h${subHead[1].length}">${parseInline(subHead[2])}</h${subHead[1].length}>`);
            } else {
              paragraphParts.push(lineStr);
            }
          }
          if (paragraphParts.length) {
            htmlChunks.push(`<p class="markdown-p">${parseInline(paragraphParts.join(" "))}</p>`);
          }
        }

        return htmlChunks.join("") || '<div class="markdown-empty-state"><p>Önizlenecek Markdown içeriği yok.</p></div>';
      };

      // Client-side unwrap and heal tool
      const unwrapText = (raw) => {
        let text = raw.replace(/\r\n/g, "\n");
        // Heal hyphenated words
        text = text.replace(/(\b[a-zA-ZğüşıöçĞÜŞİÖÇ]+)-\n[ \t]*([a-zA-ZğüşıöçĞÜŞİÖÇ]+)/g, "$1$2");

        const rawBlocks = text.split(/\n\s*\n+/);
        const processedBlocks = [];

        for (let block of rawBlocks) {
          block = block.trim();
          if (!block) continue;

          // Preserve code blocks, tables, frontmatter
          if (block.startsWith("```") || block.startsWith("|") || block.startsWith("---")) {
            processedBlocks.push(block);
            continue;
          }

          const lines = block.split("\n");
          // Lists
          if (lines.some((l) => /^\s*([-*+]|\d+\.)\s+/.test(l))) {
            const listItems = [];
            lines.forEach((l) => {
              const stripped = l.trim();
              if (/^([-*+]|\d+\.)\s+/.test(stripped)) {
                listItems.push(stripped);
              } else if (listItems.length) {
                listItems[listItems.length - 1] += " " + stripped;
              } else {
                listItems.push(stripped);
              }
            });
            processedBlocks.push(listItems.join("\n"));
            continue;
          }

          // Blockquotes
          if (lines.every((l) => l.trim().startsWith(">") || !l.trim())) {
            const quoteContent = lines.map((l) => l.replace(/^>\s?/, "").trim()).filter(Boolean).join(" ");
            processedBlocks.push(`> ${quoteContent}`);
            continue;
          }

          // Paragraphs: unwrap soft line breaks into continuous lines
          const pLines = [];
          for (let l of lines) {
            const stripped = l.trim();
            if (!stripped) continue;
            if (/^#{1,6}\s+/.test(stripped)) {
              if (pLines.length) {
                processedBlocks.push(pLines.join(" "));
                pLines.length = 0;
              }
              processedBlocks.push(stripped);
            } else {
              pLines.push(stripped);
            }
          }
          if (pLines.length) {
            processedBlocks.push(pLines.join(" "));
          }
        }

        return processedBlocks.join("\n\n");
      };

      const updateStats = () => {
        const val = editor.value || "";
        const lines = val.length ? val.split("\n").length : 0;
        const words = val.trim().length ? val.trim().split(/\s+/).length : 0;
        const chars = val.length;

        if (statusLines) statusLines.textContent = `${lines} satır`;
        if (statusWords) statusWords.textContent = `${words} kelime`;
        if (statusChars) statusChars.textContent = `${chars} karakter`;
      };

      const render = () => {
        preview.innerHTML = parseMarkdownToHtml(editor.value);
        if (zipMarkdown) zipMarkdown.value = editor.value;
        if (htmlMarkdown) htmlMarkdown.value = editor.value;

        if (lineNumbers) {
          const count = editor.value.split("\n").length;
          lineNumbers.textContent = Array.from({length: count}, (_, i) => i + 1).join("\n");
        }
        updateStats();
      };

      editor.addEventListener("input", render);
      editor.addEventListener("scroll", () => {
        if (lineNumbers) lineNumbers.scrollTop = editor.scrollTop;
      });

      // View Mode Switcher
      viewModeBtns.forEach((btn) => {
        btn.addEventListener("click", () => {
          const mode = btn.dataset.viewMode;
          workspace.classList.remove("workspace-view--split", "workspace-view--editor", "workspace-view--preview");
          workspace.classList.add(`workspace-view--${mode}`);
          viewModeBtns.forEach((b) => b.classList.toggle("is-active", b === btn));
          try {
            localStorage.setItem("pdf_workspace_view_mode", mode);
          } catch (_e) {}
        });
      });

      // Restore saved view mode preference
      try {
        const savedMode = localStorage.getItem("pdf_workspace_view_mode");
        if (savedMode && ["split", "editor", "preview"].includes(savedMode)) {
          const targetBtn = workspace.querySelector(`[data-view-mode="${savedMode}"]`);
          if (targetBtn) targetBtn.click();
        }
      } catch (_e) {}

      // One-click paragraph formatting / unwrapping
      if (formatUnwrapBtn) {
        formatUnwrapBtn.addEventListener("click", () => {
          const original = editor.value;
          const unwrapped = unwrapText(original);
          if (original === unwrapped) {
            feedback.textContent = "Paragraflar ve satırlar zaten düzgün formatlanmış.";
          } else {
            editor.value = unwrapped;
            render();
            feedback.textContent = "Kırılmış satır sonları birleştirildi ve paragraflar düzenlendi. Kalıcı yapmak için Kaydet'e tıklayın.";
          }
        });
      }

      // Toggle Word Wrap
      if (toggleWrapBtn) {
        toggleWrapBtn.addEventListener("click", () => {
          editor.classList.toggle("is-no-wrap");
          toggleWrapBtn.classList.toggle("is-active", !editor.classList.contains("is-no-wrap"));
        });
      }

      // Syntax formatting buttons
      workspace.querySelectorAll("[data-insert-syntax]").forEach((btn) => {
        btn.addEventListener("click", () => {
          const syntax = btn.dataset.insertSyntax;
          const start = editor.selectionStart;
          const end = editor.selectionEnd;
          const selected = editor.value.substring(start, end);
          let before = "";
          let after = "";
          let placeholder = "";

          switch (syntax) {
            case "bold":
              before = "**";
              after = "**";
              placeholder = "kalın metin";
              break;
            case "italic":
              before = "*";
              after = "*";
              placeholder = "italik metin";
              break;
            case "heading":
              before = "## ";
              placeholder = "Başlık";
              break;
            case "link":
              before = "[";
              after = "](https://example.com)";
              placeholder = "bağlantı metni";
              break;
            case "quote":
              before = "> ";
              placeholder = "Alıntı metni";
              break;
            case "list":
              before = "- ";
              placeholder = "Liste öğesi";
              break;
            case "code":
              before = "```\n";
              after = "\n```";
              placeholder = "kod buraya";
              break;
            case "table":
              before = "\n| Başlık 1 | Başlık 2 |\n|---|---|\n| Değer 1 | Değer 2 |\n";
              break;
          }

          const insertText = selected || placeholder;
          editor.setRangeText(`${before}${insertText}${after}`, start, end, "select");
          render();
          editor.focus();
        });
      });

      // Find and Replace
      const findNext = () => {
        const query = findInput?.value || "";
        if (!query) {
          if (findFeedback) findFeedback.textContent = "Aranacak metni yazın.";
          findInput?.focus();
          return false;
        }
        const index = editor.value.indexOf(query, editor.selectionEnd);
        const matchAt = index === -1 ? editor.value.indexOf(query) : index;
        if (matchAt === -1) {
          if (findFeedback) findFeedback.textContent = "Eşleşme bulunamadı.";
          return false;
        }
        editor.focus();
        editor.setSelectionRange(matchAt, matchAt + query.length);
        if (findFeedback) findFeedback.textContent = index === -1 ? "Başa dönüldü." : "Eşleşme seçildi.";
        return true;
      };

      workspace.querySelector("[data-find-next]")?.addEventListener("click", findNext);
      workspace.querySelector("[data-replace-next]")?.addEventListener("click", () => {
        const query = findInput?.value || "";
        const selectedText = editor.value.slice(editor.selectionStart, editor.selectionEnd);
        if (selectedText !== query && !findNext()) return;
        editor.setRangeText(replaceInput?.value || "", editor.selectionStart, editor.selectionEnd, "select");
        render();
        if (findFeedback) findFeedback.textContent = "Bir eşleşme değiştirildi.";
      });

      workspace.querySelector("[data-replace-all]")?.addEventListener("click", () => {
        const query = findInput?.value || "";
        if (!query) return findNext();
        const matches = editor.value.split(query).length - 1;
        if (!matches) {
          if (findFeedback) findFeedback.textContent = "Eşleşme bulunamadı.";
          return;
        }
        editor.value = editor.value.split(query).join(replaceInput?.value || "");
        render();
        if (findFeedback) findFeedback.textContent = `${matches} eşleşme değiştirildi.`;
      });

      workspace.addEventListener("keydown", (event) => {
        if (!(event.metaKey || event.ctrlKey)) return;
        if (event.key.toLowerCase() === "f") {
          event.preventDefault();
          findInput?.focus();
        } else if (event.key.toLowerCase() === "g") {
          event.preventDefault();
          findNext();
        } else if (event.key.toLowerCase() === "b") {
          event.preventDefault();
          workspace.querySelector('[data-insert-syntax="bold"]')?.click();
        } else if (event.key.toLowerCase() === "i") {
          event.preventDefault();
          workspace.querySelector('[data-insert-syntax="italic"]')?.click();
        } else if (event.key.toLowerCase() === "s") {
          event.preventDefault();
          saveButton?.click();
        }
      });

      // Insert image from gallery
      workspace.querySelectorAll("[data-insert-image]").forEach((button) => {
        button.addEventListener("click", () => {
          const markdown = `![${button.dataset.imageAlt}](images/${button.dataset.imageFilename})`;
          const start = editor.selectionStart;
          const end = editor.selectionEnd;
          const prefix = editor.value.slice(0, start);
          const suffix = editor.value.slice(end);
          const leadingBreak = prefix && !prefix.endsWith("\n") ? "\n\n" : "";
          const trailingBreak = suffix && !suffix.startsWith("\n") ? "\n\n" : "";
          editor.value = `${prefix}${leadingBreak}${markdown}${trailingBreak}${suffix}`;
          const cursor = (prefix + leadingBreak + markdown).length;
          editor.focus();
          editor.setSelectionRange(cursor, cursor);
          render();
          feedback.textContent = "Görsel Markdown’a eklendi. Değişikliği kalıcı yapmak için kaydedin.";
        });
      });

      copyButton?.addEventListener("click", async () => {
        try {
          await navigator.clipboard.writeText(editor.value);
          feedback.textContent = "Markdown panoya kopyalandı.";
        } catch (_error) {
          feedback.textContent = "Kopyalama başarısız oldu; Markdown alanından elle kopyalayabilirsiniz.";
        }
      });

      saveButton?.addEventListener("click", async () => {
        const originalLabel = saveButton.innerHTML;
        saveButton.disabled = true;
        saveButton.innerHTML = `<svg class="btn-icon animate-spin" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10"/></svg><span>Kaydediliyor…</span>`;
        feedback.textContent = "Markdown değişiklikleri kaydediliyor.";
        try {
          const response = await fetch(saveButton.dataset.saveUrl, {
            method: "PATCH",
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
              "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
            },
            body: JSON.stringify({document_conversion: {markdown_content: editor.value}})
          });
          const result = await response.json();
          if (!response.ok) throw new Error(result.error || "Kaydetme başarısız oldu.");
          feedback.textContent = "Markdown değişiklikleri kaydedildi.";
        } catch (error) {
          feedback.textContent = error.message || "Kaydetme başarısız oldu; tekrar deneyin.";
        } finally {
          saveButton.disabled = false;
          saveButton.innerHTML = originalLabel;
        }
      });

      render();
    });
  };

  const initDocumentConversionPolling = () => {
    const processing = document.querySelector("[data-document-conversion-processing]");
    if (!processing || processing.dataset.pollingBound) return;
    processing.dataset.pollingBound = "true";
    window.setTimeout(() => window.location.reload(), 5000);
  };

  const initModuleSwitcher = () => {
    const switcher = document.querySelector("[data-module-switcher]");
    if (!switcher || switcher.dataset.moduleSwitcherBound) return;
    switcher.dataset.moduleSwitcherBound = "true";

    const trigger = switcher.querySelector("[data-module-switch-toggle]");
    const dropdown = switcher.querySelector("[data-module-dropdown-menu]");
    if (!trigger || !dropdown) return;

    const toggle = (open) => {
      const isExpanded = open !== undefined ? open : dropdown.hidden;
      dropdown.hidden = !isExpanded;
      trigger.setAttribute("aria-expanded", String(isExpanded));
      trigger.classList.toggle("is-active", isExpanded);
    };

    trigger.addEventListener("click", (e) => {
      e.stopPropagation();
      toggle();
    });

    document.addEventListener("click", (e) => {
      if (!switcher.contains(e.target)) {
        toggle(false);
      }
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && !dropdown.hidden) {
        toggle(false);
        trigger.focus();
      }
    });
  };

  const init = () => {
    document.querySelectorAll("[data-auto-submit]").forEach((element) => {
      if (element.dataset.autoSubmitBound) return;
      element.dataset.autoSubmitBound = "true";
      element.addEventListener("change", () => element.form?.requestSubmit());
    });
    animateDashboard();
    initModuleSwitcher();
    initLiveCounters();
    initHealthScoreGauge();
    initBudgetSelector();
    initBudgetCalculator();
    initTransactionFilters();
    initCategorySuggestion();
    initPurchaseScenario();
    initQuickAdd();
    initCashFlowChart();
    initSpendingReport();
    initCashFlowForecast();
    initOnboardingWizard();
    initDocumentWorkspace();
    initDocumentConversionPolling();
    registerServiceWorker();
  };

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", () => {
    if (document.readyState !== "loading") {
      init();
    }
  });
})();
