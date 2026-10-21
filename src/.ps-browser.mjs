// ---------------------------------------------------------------- PowerSearch (M86)
if (mode === "showcase") {
  const psSection = await page.$("section[data-showcase-component='PowerSearch']");
  check("the PowerSearch section renders", psSection !== null,
    psSection === null ? "not found" : "found");

  if (psSection) {
    const shape = await page.evaluate(() => {
      const roots = [...document.querySelectorAll("[data-astryx-component='PowerSearch']")];
      const empty = roots[0];
      const set = roots[1];
      const input = empty?.querySelector("input[role='combobox']");
      const listbox = empty?.querySelector("[role='listbox']");
      const surface = empty?.querySelector("[popover='auto']");
      return {
        count: roots.length,
        marker: empty?.getAttribute("data-astryx-component") ?? null,
        isCombobox: input?.getAttribute("role") === "combobox",
        expanded: input?.getAttribute("aria-expanded") ?? null,
        hasListbox: listbox !== null,
        listboxHidden: listbox?.hasAttribute("hidden") ?? null,
        surfaceRole: surface?.getAttribute("role") ?? null,
        surfaceLabel: surface?.getAttribute("aria-label") ?? null,
        surfaceOpen: surface?.hasAttribute("open") ?? null,
        setChips: [...(set?.querySelectorAll(".astryx-token__label") ?? [])]
          .map((e) => e.textContent?.trim() ?? ""),
        setHasRemove: set?.querySelector("[aria-label^='Remove']") !== null,
      };
    });
    check("there are four fields, and the first is the empty one",
      shape.count === 4, JSON.stringify({ count: shape.count }));
    check("the field carries the house's component marker",
      shape.marker === "PowerSearch", JSON.stringify({ marker: shape.marker }));
    check("the box is a combobox",
      shape.isCombobox === true, JSON.stringify({ combobox: shape.isCombobox }));
    check("the list of fields is a listbox, closed while the box is empty",
      shape.hasListbox === true && shape.listboxHidden === true,
      JSON.stringify({ hasListbox: shape.hasListbox, hidden: shape.listboxHidden }));
    check("the editor is a popover, and it is not a dialog",
      shape.surfaceRole === null && shape.surfaceLabel === "Filter value",
      JSON.stringify({ role: shape.surfaceRole, label: shape.surfaceLabel }));
    check("the editor is closed until a filter is being edited",
      shape.surfaceOpen === false, JSON.stringify({ open: shape.surfaceOpen }));
    check("the filters that are set are chips that name the field and the value",
      shape.setChips.includes("Status: is Archived") && shape.setChips.includes("Name: is ada"),
      JSON.stringify({ chips: shape.setChips }));
    check("a chip can be taken off", shape.setHasRemove === true,
      JSON.stringify({ remove: shape.setHasRemove }));

    // Typing a field's name opens the list of fields, and choosing one opens
    // the editor for that filter's value.
    const psInput = await page.$("section[data-showcase-component='PowerSearch'] input[role='combobox']");
    await psInput.click();
    await psInput.type("stat", { delay: 25 });
    await page.waitForFunction(() => {
      const listbox = document.querySelector(
        "section[data-showcase-component='PowerSearch'] [role='listbox']");
      return listbox !== null && !listbox.hasAttribute("hidden")
        && listbox.querySelectorAll("[role='option']").length > 0;
    }, null, { timeout: 5000 }).catch(() => {});

    const suggestions = await page.evaluate(() => {
      const listbox = document.querySelector(
        "section[data-showcase-component='PowerSearch'] [role='listbox']");
      return {
        open: listbox !== null && !listbox.hasAttribute("hidden"),
        options: [...(listbox?.querySelectorAll("[role='option']") ?? [])]
          .map((e) => e.textContent?.trim() ?? ""),
        expanded: document.querySelector(
          "section[data-showcase-component='PowerSearch'] input[role='combobox']")
          ?.getAttribute("aria-expanded") ?? null,
      };
    });
    check("typing a field's name opens the list of fields",
      suggestions.open === true && suggestions.options.some((o) => o.includes("Status")),
      JSON.stringify({ open: suggestions.open, options: suggestions.options }));
    check("the combobox says it is expanded while the list is open",
      suggestions.expanded === "true", JSON.stringify({ expanded: suggestions.expanded }));

    const psOption = await page.$(
      "section[data-showcase-component='PowerSearch'] [role='listbox'] [role='option']");
    if (psOption) {
      await psOption.click();
      await page.waitForFunction(() => {
        const surface = document.querySelector(
          "section[data-showcase-component='PowerSearch'] [popover='auto']");
        return surface !== null && surface.hasAttribute("open");
      }, null, { timeout: 5000 }).catch(() => {});
    }

    const editor = await page.evaluate(() => {
      const surface = document.querySelector(
        "section[data-showcase-component='PowerSearch'] [popover='auto']");
      const content = surface?.querySelector(".astryx-popover__content") ?? null;
      return {
        open: surface?.hasAttribute("open") ?? null,
        hasEditor: content?.querySelector(".astryx-power-search__editor") !== null,
        operator: [...(content?.querySelectorAll(
          ".astryx-power-search__editor-operator select option") ?? [])]
          .map((o) => o.textContent?.trim() ?? ""),
        valueSelects: content?.querySelectorAll(".astryx-power-search__editor-value select").length ?? 0,
        buttons: content?.querySelectorAll("button").length ?? 0,
        head: content?.querySelector(".astryx-power-search__editor-head")?.textContent?.trim() ?? null,
      };
    });
    check("choosing a field opens the editor for that filter",
      editor.open === true && editor.hasEditor === true,
      JSON.stringify({ open: editor.open, hasEditor: editor.hasEditor }));
    check("the editor names the field being filtered",
      typeof editor.head === "string" && editor.head.length > 0,
      JSON.stringify({ head: editor.head }));
    check("the editor offers the field's operators",
      editor.operator.includes("is"), JSON.stringify({ operators: editor.operator }));
    check("the editor's value is a choice, for an enum operator",
      editor.valueSelects >= 1, JSON.stringify({ selects: editor.valueSelects }));
  }
}
