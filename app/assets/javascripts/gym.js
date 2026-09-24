/* global gsap, Chart */
/* Personal Gym module — loaded only on gym pages via content_for(:module_js). */

(() => {
  const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

  const initTimer = () => {
    const timer = document.querySelector("[data-gym-timer]");
    if (!timer || timer.dataset.gymTimerBound) return;
    timer.dataset.gymTimerBound = "true";

    const started = new Date(timer.dataset.startedAt).getTime();
    if (isNaN(started)) return;

    const render = () => {
      const seconds = Math.max(0, Math.floor((Date.now() - started) / 1000));
      const m = Math.floor(seconds / 60);
      const s = seconds % 60;
      timer.textContent = `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    };

    render();
    setInterval(render, 1000);
  };

  const initVolumeChart = () => {
    const canvas = document.getElementById("gym-volume-chart");
    if (!canvas || typeof window.Chart === "undefined") return;
    if (window.Chart.getChart(canvas)) return;

    const dataEl = document.querySelector("[data-gym-volume-data]");
    if (!dataEl) return;

    let rows;
    try {
      rows = JSON.parse(dataEl.textContent);
    } catch (e) {
      return;
    }
    if (!Array.isArray(rows) || !rows.length) return;

    const reduceMotion = motionQuery.matches;

    new window.Chart(canvas, {
      type: "bar",
      data: {
        labels: rows.map((row) => row.label),
        datasets: [
          {
            label: canvas.dataset.labelVolume || "Tonaj",
            data: rows.map((row) => Number(row.tonnage) || 0),
            backgroundColor: "rgba(16, 185, 129, 0.85)",
            hoverBackgroundColor: "#10B981",
            borderColor: "#10B981",
            borderRadius: 6,
            maxBarThickness: 34
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: reduceMotion ? false : { duration: 600, easing: "easeOutQuart" },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.92)",
            titleColor: "#E2E8F0",
            bodyColor: "#CBD5E1",
            padding: 12,
            cornerRadius: 8,
            callbacks: { label: (ctx) => `${ctx.parsed.y} kg` }
          }
        },
        scales: {
          x: { grid: { color: "rgba(148, 163, 184, 0.12)" }, ticks: { color: "#94A3B8" } },
          y: { beginAtZero: true, grid: { color: "rgba(148, 163, 184, 0.12)" }, ticks: { color: "#94A3B8" } }
        }
      }
    });
  };

  const initStatAnimations = () => {
    if (motionQuery.matches || typeof window.gsap === "undefined") return;

    const cards = document.querySelectorAll(".gym-stat");
    if (cards.length) {
      window.gsap.fromTo(cards, { y: 12, autoAlpha: 0 }, { y: 0, autoAlpha: 1, duration: 0.28, stagger: 0.03 });
    }

    const trendBars = document.querySelectorAll(".gym-trend span");
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

  const init = () => {
    initTimer();
    initVolumeChart();
    initStatAnimations();
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
