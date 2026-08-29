(() => {
  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-print]");
    if (!target) {
      return;
    }
    event.preventDefault();
    window.print();
  });
})();
