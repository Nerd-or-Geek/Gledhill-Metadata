document.addEventListener("DOMContentLoaded", () => {
  const yearEl = document.getElementById("year");
  if (yearEl) {
    yearEl.textContent = String(new Date().getFullYear());
  }

  initScrollReveal();
  initNavSpy();
  initGallery();
});

function initScrollReveal() {
  const revealTargets = document.querySelectorAll("[data-reveal]");
  if (!revealTargets.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.15, rootMargin: "0px 0px -40px 0px" }
  );

  revealTargets.forEach((target) => observer.observe(target));
}

function initNavSpy() {
  const navLinks = document.querySelectorAll(".nav a[href^='#']");
  if (!navLinks.length) return;

  const sections = Array.from(navLinks)
    .map((link) => {
      const href = link.getAttribute("href");
      if (!href) return null;
      return document.querySelector(href);
    })
    .filter(Boolean);

  if (!sections.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        navLinks.forEach((link) => {
          const href = link.getAttribute("href");
          link.classList.toggle("active", href === `#${entry.target.id}`);
        });
      });
    },
    { threshold: 0.35 }
  );

  sections.forEach((section) => observer.observe(section));
}

function initGallery() {
  const galleryRoot = document.querySelector("[data-gallery]");
  if (!galleryRoot) return;

  const slides = Array.from(galleryRoot.querySelectorAll("[data-gallery-slide]"));
  const dotsRoot = galleryRoot.querySelector("[data-gallery-dots]");
  const prevBtn = document.querySelector("[data-gallery-prev]");
  const nextBtn = document.querySelector("[data-gallery-next]");

  if (!slides.length || !dotsRoot) return;

  let currentIndex = slides.findIndex((slide) => slide.classList.contains("is-active"));
  if (currentIndex < 0) currentIndex = 0;

  const dots = slides.map((_, index) => {
    const dot = document.createElement("button");
    dot.type = "button";
    dot.className = "gallery-dot";
    dot.setAttribute("aria-label", `Go to screenshot ${index + 1}`);
    dot.addEventListener("click", () => goToSlide(index));
    dotsRoot.appendChild(dot);
    return dot;
  });

  function render() {
    slides.forEach((slide, index) => {
      slide.classList.toggle("is-active", index === currentIndex);
    });

    dots.forEach((dot, index) => {
      dot.classList.toggle("is-active", index === currentIndex);
    });
  }

  function goToSlide(index) {
    currentIndex = (index + slides.length) % slides.length;
    render();
  }

  if (prevBtn) {
    prevBtn.addEventListener("click", () => goToSlide(currentIndex - 1));
  }

  if (nextBtn) {
    nextBtn.addEventListener("click", () => goToSlide(currentIndex + 1));
  }

  let autoplayId = window.setInterval(() => {
    goToSlide(currentIndex + 1);
  }, 5500);

  galleryRoot.addEventListener("mouseenter", () => {
    window.clearInterval(autoplayId);
  });

  galleryRoot.addEventListener("mouseleave", () => {
    autoplayId = window.setInterval(() => {
      goToSlide(currentIndex + 1);
    }, 5500);
  });

  render();
}
