(* PowerSearch — the search field that also takes structured filters.

   The examples show the field on its own, the field with filters already
   set (so the chips are visible), the field with a count of results in
   its end lane, and the field read only. *)

open! Core
open! Bonsai_web

module Power_search = Astryx.Power_search

open Prelude

(* A small configuration: a few fields, each with the operators that
   compare it. The kind of an operator is what decides its editor. *)
let config : Power_search.config =
  { name = "People"
  ; fields =
      [ { key = "name"
        ; label = "Name"
        ; operators =
            [ { key = "is"
              ; label = "is"
              ; value =
                  Power_search.String
                    { search_source = None
                    ; is_arbitrary_string_allowed = true
                    }
              }
            ; { key = "contains"
              ; label = "contains"
              ; value =
                  Power_search.String
                    { search_source = None
                    ; is_arbitrary_string_allowed = true
                    }
              }
            ]
        ; default_operator = Some "is"
        ; group = Some "Who"
        ; description = Some "The name on the profile"
        ; typeahead_aliases = [ "full name" ]
        ; typeahead_min_query_length = None
        ; is_value_match_allowed = true
        }
      ; { key = "status"
        ; label = "Status"
        ; operators =
            [ { key = "is"
              ; label = "is"
              ; value =
                  Power_search.Enum
                    [ { value = "active"; label = "Active" }
                    ; { value = "archived"; label = "Archived" }
                    ; { value = "pending"; label = "Pending" }
                    ]
              }
            ]
        ; default_operator = Some "is"
        ; group = Some "Who"
        ; description = None
        ; typeahead_aliases = []
        ; typeahead_min_query_length = None
        ; is_value_match_allowed = true
        }
      ; { key = "team"
        ; label = "Team"
        ; operators =
            [ { key = "in"
              ; label = "in"
              ; value =
                  Power_search.Enum_list
                    [ { value = "design"; label = "Design" }
                    ; { value = "engineering"; label = "Engineering" }
                    ; { value = "support"; label = "Support" }
                    ]
              }
            ]
        ; default_operator = Some "in"
        ; group = Some "Who"
        ; description = None
        ; typeahead_aliases = []
        ; typeahead_min_query_length = None
        ; is_value_match_allowed = true
        }
      ; { key = "joined"
        ; label = "Joined"
        ; operators =
            [ { key = "is"
              ; label = "is"
              ; value = Power_search.Date_absolute { is_date_only = true }
              }
            ; { key = "in the last"
              ; label = "in the last"
              ; value =
                  Power_search.Date_relative
                    { is_past_allowed = true
                    ; is_future_allowed = false
                    }
              }
            ]
        ; default_operator = Some "is"
        ; group = Some "When"
        ; description = None
        ; typeahead_aliases = []
        ; typeahead_min_query_length = None
        ; is_value_match_allowed = true
        }
      ; { key = "archived"
        ; label = "Archived"
        ; operators =
            [ { key = "is"
              ; label = "is"
              ; value = Power_search.Empty
              }
            ]
        ; default_operator = Some "is"
        ; group = Some "Who"
        ; description = Some "Whether the record is archived"
        ; typeahead_aliases = []
        ; typeahead_min_query_length = None
        ; is_value_match_allowed = true
        }
      ]
  ; content_search_field_key = Some "name"
  }

(* The filters the example starts with: one that has a value, one that is a
   list, and one that has no value at all. *)
let starting_filters : Power_search.filter list =
  [ { field = "status"
    ; operator = "is"
    ; value = Power_search.Value_enum "archived"
    ; is_read_only = false
    }
  ; { field = "team"
    ; operator = "in"
    ; value = Power_search.Value_enum_list [ "design"; "support" ]
    ; is_read_only = false
    }
  ; { field = "archived"
    ; operator = "is"
    ; value = Power_search.Value_empty
    ; is_read_only = false
    }
  ]

let demo (graph : Bonsai.graph) : Vdom.Node.t Bonsai.t =
  (* The field is controlled: the application holds the filters and hands
     them over, and every change is reported to it. *)
  let filters, set_filters =
    Bonsai.state' ([] : Power_search.filter list) graph
  in
  let on_change =
    Bonsai.map set_filters ~f:(fun set_filters ->
        fun (filters : Power_search.filter list) _change_type _index ->
          set_filters (fun _ -> filters))
  in
  let plain =
    Power_search.view
      ~id:"showcase-power-search"
      ~config
      ~filters
      ~on_change
      graph
  in
  (* A second field with its own state, so the chips are already there. *)
  let with_filters, set_with_filters =
    Bonsai.state' starting_filters graph
  in
  let with_filters_change =
    Bonsai.map set_with_filters ~f:(fun set_with_filters ->
        fun (filters : Power_search.filter list) _change_type _index ->
          set_with_filters (fun _ -> filters))
  in
  let with_filters =
    Power_search.view
      ~id:"showcase-power-search-with-filters"
      ~config
      ~filters:with_filters
      ~on_change:with_filters_change
      graph
  in
  let with_count =
    Power_search.view
      ~id:"showcase-power-search-with-count"
      ~config
      ~filters
      ~on_change
      ~result_count:"12 results"
      graph
  in
  let read_only =
    Power_search.view
      ~id:"showcase-power-search-read-only"
      ~config
      ~filters
      ~on_change
      ~is_read_only:true
      graph
  in
  (* A small field carrying a status, and a menu of its own width. These are
     upstream's own knobs, passed through to the house field. *)
  let small_with_status =
    Power_search.view
      ~id:"showcase-power-search-small"
      ~config
      ~filters
      ~on_change
      ~size:Power_search.Sm
      ~status:
        { Astryx.Input_types.type_ = Astryx.Input_types.Warning
        ; message = Some "Two filters cannot both hold."
        }
      ~status_variant:Attached
      ~menu_width:320
      graph
  in
  let examples =
    [ ("the field on its own", plain)
    ; ("the field with filters already set", with_filters)
    ; ("the field with a count of results", with_count)
    ; ("the field read only", read_only)
    ; ("the field small, with a status", small_with_status)
    ]
  in
  let rendered =
    List.map
      ~f:(fun (label, tree) -> Bonsai.map tree ~f:(fun node -> ex label node))
      examples
  in
  let all =
    List.fold rendered ~init:(Bonsai.return []) ~f:(fun acc tree ->
      Bonsai.both acc tree |> Bonsai.map ~f:(fun (acc, tree) -> tree :: acc))
    |> Bonsai.map ~f:List.rev
  in
  Bonsai.map all ~f:(fun examples ->
      section
        ~id:"power-search"
        ~title:"PowerSearch"
        ~note:
          "A search field that also takes structured filters: type a field's name, choose it, and the value's editor opens."
        examples)
;;
