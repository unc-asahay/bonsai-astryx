p = 'src/side_nav.ml'
s = open(p).read()

# the header, top content, footer and footer icons are nodes; the body holds
# items, which are graphs
old_sig = """  ?(header = [])
  ?(top_content = [])
  ?(footer = [])
  ?(footer_icons = [])"""
new_sig = """  ?(header = [])
  ?(top_content = [])
  ?(footer = [])
  ?(footer_icons = [])"""
assert old_sig in s

# combine a list of trees into a tree of a list of nodes
old_helper = """(* The style the column's width is written into."""
new_helper = """(* A list of trees into one tree of a list of nodes. The house's Bonsai has
   no list combinator, so the trees are combined pairwise and read back by
   position. *)
let combine (trees : Vdom.Node.t Bonsai.t list) =
  List.fold trees ~init:(Bonsai.return []) ~f:(fun acc tree ->
    Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
  |> Bonsai.map ~f:List.rev
;;

(* The style the column's width is written into."""
assert old_helper in s
s = s.replace(old_helper, new_helper, 1)

# the parts that hold items are lists of trees
old_parts = """  let width_tree =
    Bonsai.map3 width_state report_width_tree set_width ~f:(fun value report set -> (value, report, set))
  in
  Bonsai.map2 collapsed_tree width_tree
    ~f:(fun
          (collapsed, report_collapsed, set_collapsed)
          (width, report_width, set_width) ->"""
new_parts = """  let width_tree =
    Bonsai.map3 width_state report_width_tree set_width ~f:(fun value report set -> (value, report, set))
  in
  (* The body and the pinned area hold items, which are graphs. *)
  let parts_tree =
    Bonsai.map2 (combine children) (combine top_content) ~f:(fun body top -> (body, top))
  in
  Bonsai.map3 collapsed_tree width_tree parts_tree
    ~f:(fun
          (collapsed, report_collapsed, set_collapsed)
          (width, report_width, set_width)
          (body_nodes, top_nodes) ->"""
assert old_parts in s
s = s.replace(old_parts, new_parts, 1)

old_body = """           @ [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-side-nav__body" ]) children ]"""
new_body = """           @ [ Vdom.Node.div ~attrs:(Attr.class_ [ "astryx-side-nav__body" ]) body_nodes ]"""
assert old_body in s
s = s.replace(old_body, new_body, 1)

old_top = """           @ region "Pinned" top_content"""
new_top = """           @ (if List.is_empty top_nodes then [] else region "Pinned" top_nodes)"""
assert old_top in s
s = s.replace(old_top, new_top, 1)

open(p, 'w').write(s)

# the interface
p = 'src/side_nav.mli'
s = open(p).read()
old_i = """  -> ?top_content:Vdom.Node.t list"""
new_i = """  -> ?top_content:Vdom.Node.t Bonsai.t list"""
assert old_i in s
s = s.replace(old_i, new_i, 1)
old_i2 = """  -> ?children:Vdom.Node.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~children graph] renders the column."""
new_i2 = """  -> ?children:Vdom.Node.t Bonsai.t list
  -> Bonsai.graph
  -> Vdom.Node.t Bonsai.t
(** [view ~children graph] renders the column."""
assert old_i2 in s
s = s.replace(old_i2, new_i2, 1)
open(p, 'w').write(s)
print("ok")
