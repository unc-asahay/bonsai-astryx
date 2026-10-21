rt = "test/rt_test.ml"
s = open(rt).read()

if "side_nav_component" in s:
    print("rt already")
else:
    block = '''
(* ---------------------------------------------------------------- SideNav *)
(* The side navigation: a column of items, with a heading, a group under a
   title, and the column that collapses to an icon rail and is resized with
   a separator. *)
let side_nav_component graph =
  let items =
    [ Astryx.Side_nav.item ~id:"rt-side-nav-item" ~label:"Home" ~icon:"menu" graph
    ; Astryx.Side_nav.item
        ~id:"rt-side-nav-item-selected"
        ~label:"Search"
        ~icon:"search"
        ~selected_icon:"funnel"
        ~is_selected:true
        graph
    ; Astryx.Side_nav.item
        ~id:"rt-side-nav-item-disabled"
        ~label:"Reports"
        ~icon:"copy"
        ~is_disabled:true
        graph
    ]
  in
  let trees =
    [ Astryx.Side_nav.heading
        ~id:"rt-side-nav-heading"
        ~heading:"A product"
        ~superheading:"Acme"
        ~subheading:"The workspace"
        graph
    ; Astryx.Side_nav.section
        ~id:"rt-side-nav-section"
        ~title:"Workspace"
        ~subtitle:"Three places"
        ~children:items
        graph
    ; Astryx.Side_nav.view
        ~id:"rt-side-nav"
        ~is_collapsible:true
        ~is_resizable:true
        ~default_width:240.
        ~min_width:180.
        ~max_width:400.
        ~children:items
        graph
    ]
  in
  let nodes =
    List.fold trees ~init:(Bonsai.return []) ~f:(fun acc node ->
      Bonsai.both acc node |> Bonsai.map ~f:(fun (acc, node) -> node :: acc))
    |> Bonsai.map ~f:List.rev
  in
  Bonsai.map
    ~f:(fun nodes -> Vdom.Node.div ~attrs:[ Vdom.Attr.id "side-nav-all" ] nodes)
    nodes
;;

let () =
  let handle =
    Bonsai_web_test.Handle.create
      (Bonsai_web_test.Result_spec.vdom Fn.id)
      side_nav_component
  in
  mount "side-nav-all" (Bonsai_web_test.Handle.last_result handle)
'''
    s = s.rstrip("\n") + "\n" + block
    open(rt, "w").write(s)
    print("rt_test case added")

# the jsdom case
p = "test/run.mjs"
s = open(p).read()
if 'data-case="side-nav-all"' in s:
    print("jsdom already")
else:
    block2 = '''
  // ---------------------------------------------------------------- SideNav
  const snHost = document.querySelector('[data-case="side-nav-all"]');
  const snColumns = [...(snHost?.querySelectorAll("[data-astryx-component='SideNav']") ?? [])];
  const snColumn = snColumns[0];
  const snItems = [...(snHost?.querySelectorAll("[data-astryx-component='SideNavItem']") ?? [])];

  check("the column carries the house's component marker",
    snColumn?.getAttribute("data-astryx-component") === "SideNav",
    JSON.stringify({ component: snColumn?.getAttribute("data-astryx-component") }));

  check("the column is a navigation landmark",
    snColumn?.tagName?.toLowerCase() === "nav",
    JSON.stringify({ tag: snColumn?.tagName }));

  check("the column has a body, and a heading group",
    snColumn?.querySelector(".astryx-side-nav__body") !== null
      && snHost?.querySelector("[data-astryx-component='SideNavHeading']") !== null,
    JSON.stringify({ body: snColumn?.querySelector(".astryx-side-nav__body") !== null }));

  check("the group of items carries its title",
    snHost?.querySelector(".astryx-side-nav__section-title")?.textContent?.trim() === "Workspace",
    JSON.stringify({ title: snHost?.querySelector(".astryx-side-nav__section-title")?.textContent }));

  check("every item is rendered, with its label",
    snItems.length === 3 && snItems.some((i) => i.textContent?.includes("Search")),
    JSON.stringify({ items: snItems.length }));

  check("the selected item and the disabled item are marked",
    snHost?.querySelector(".astryx-side-nav__item--selected") !== null
      && snHost?.querySelector(".astryx-side-nav__item--disabled") !== null,
    JSON.stringify({}));

  check("the column is collapsible, and says so",
    snColumn?.getAttribute("data-astryx-collapsed") === "false"
      && snColumn?.querySelector(".astryx-side-nav__collapse") !== null,
    JSON.stringify({ collapsed: snColumn?.getAttribute("data-astryx-collapsed") }));

  check("the column carries a separator with the value",
    snColumn?.getAttribute("data-astryx-resizable") === "true"
      && (snColumn?.querySelector("[role='separator']")?.getAttribute("aria-valuenow") ?? "") === "240",
    JSON.stringify({ value: snColumn?.querySelector("[role='separator']")?.getAttribute("aria-valuenow") }));

'''
    anchor = '\n  // ----------------------------------------------------------------'
    idx = s.rfind(anchor)
    assert idx > 0, "MISS anchor"
    s = s[:idx] + "\n" + block2 + s[idx:]
    open(p, "w").write(s)
    print("jsdom case added")
