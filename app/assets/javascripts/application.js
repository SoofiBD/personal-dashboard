/* global gsap */

(() => {
  const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

  const animateDashboard = () => {
    if (motionQuery.matches || typeof window.gsap === "undefined") return;

    const timeline = window.gsap.timeline({ defaults: { ease: "power1.out" } });
    const sidebar = document.querySelector(".sidebar");
    const header = document.querySelector(".page-header");
    const cards = document.querySelectorAll(".metric-card");
    const panels = document.querySelectorAll(".panel");
    const items = document.querySelectorAll(".finance-list article");
    const flashes = document.querySelectorAll(".flash");

    if (sidebar) timeline.from(sidebar, { x: -12, autoAlpha: 0, duration: 0.28 });
    if (header) timeline.from(header, { y: 12, autoAlpha: 0, duration: 0.32 }, "-=0.12");
    if (cards.length) timeline.from(cards, { y: 12, autoAlpha: 0, duration: 0.3, stagger: 0.055 }, "-=0.12");
    if (panels.length) timeline.from(panels, { y: 10, autoAlpha: 0, duration: 0.3, stagger: 0.045 }, "-=0.18");
    if (items.length) timeline.from(items, { y: 8, autoAlpha: 0, duration: 0.24, stagger: 0.025 }, "-=0.2");
    if (flashes.length) timeline.from(flashes, { y: -8, autoAlpha: 0, duration: 0.22 }, 0);
  };

  document.addEventListener("DOMContentLoaded", animateDashboard, { once: true });
})();
