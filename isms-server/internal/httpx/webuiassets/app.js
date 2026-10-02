(() => {
  const storagePrefix = "isms-split:";

  document.querySelectorAll(".split[data-split]").forEach((split) => {
    const handle = split.querySelector(":scope > .split-handle");
    if (!handle) {
      return;
    }
    const rows = split.dataset.split === "rows";
    const fallback = Number(split.dataset.splitDefault || (rows ? 55 : 42));
    let current = fallback;
    let stored = NaN;
    try {
      stored = Number(localStorage.getItem(storagePrefix + (split.dataset.splitId || "")));
    } catch {
      stored = NaN;
    }
    if (split.dataset.splitId && Number.isFinite(stored) && stored > 0) {
      current = stored;
    }

    const clamp = (value) => Math.min(78, Math.max(18, value));

    const apply = (value) => {
      current = clamp(value);
      split.style.setProperty("--split", current + "%");
      handle.setAttribute("aria-valuenow", String(Math.round(current)));
    };

    const persist = () => {
      if (!split.dataset.splitId) {
        return;
      }
      try {
        localStorage.setItem(storagePrefix + split.dataset.splitId, String(Math.round(current)));
      } catch {
        /* private mode */
      }
    };

    apply(current);
    handle.setAttribute("aria-valuemin", "18");
    handle.setAttribute("aria-valuemax", "78");

    const fromPointer = (event) => {
      const rect = split.getBoundingClientRect();
      if (rows) {
        return ((event.clientY - rect.top) / rect.height) * 100;
      }
      return ((event.clientX - rect.left) / rect.width) * 100;
    };

    handle.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) {
        return;
      }
      event.preventDefault();
      handle.setPointerCapture(event.pointerId);
      split.classList.add("is-dragging");
      document.body.classList.add("is-split-drag");
      document.body.style.cursor = rows ? "row-resize" : "col-resize";

      const move = (ev) => apply(fromPointer(ev));
      const end = (ev) => {
        if (ev.type === "pointerup") {
          apply(fromPointer(ev));
        }
        persist();
        split.classList.remove("is-dragging");
        document.body.classList.remove("is-split-drag");
        document.body.style.cursor = "";
        handle.removeEventListener("pointermove", move);
        handle.removeEventListener("pointerup", end);
        handle.removeEventListener("pointercancel", end);
      };
      handle.addEventListener("pointermove", move);
      handle.addEventListener("pointerup", end);
      handle.addEventListener("pointercancel", end);
    });

    handle.addEventListener("keydown", (event) => {
      const step = event.shiftKey ? 8 : 2;
      let next = current;
      if (!rows && event.key === "ArrowLeft") next -= step;
      else if (!rows && event.key === "ArrowRight") next += step;
      else if (rows && event.key === "ArrowUp") next -= step;
      else if (rows && event.key === "ArrowDown") next += step;
      else if (event.key === "Home") next = 18;
      else if (event.key === "End") next = 78;
      else return;
      event.preventDefault();
      apply(next);
      persist();
    });

    handle.addEventListener("dblclick", () => {
      apply(fallback);
      persist();
    });
  });

  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-print]");
    if (!target) {
      return;
    }
    event.preventDefault();
    window.print();
  });
})();
