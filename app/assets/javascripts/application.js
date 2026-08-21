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

  const init = () => {
    animateDashboard();
    initBudgetSelector();
    initBudgetCalculator();
    initTransactionFilters();
    initPurchaseScenario();
    initQuickAdd();
    initCashFlowChart();
    initCategoryBars();
    initOnboardingWizard();
    registerServiceWorker();
  };

  document.addEventListener("DOMContentLoaded", init);
  document.addEventListener("turbo:load", () => {
    if (document.readyState !== "loading") {
      init();
    }
  });
})();

