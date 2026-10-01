{lib}: graph: let
  names = lib.attrNames graph;
  missing = lib.concatMap (name:
    map (dependency: "${name} -> ${dependency}")
    (builtins.filter (dependency: !(builtins.hasAttr dependency graph)) graph.${name}))
  names;
  selfReferences = builtins.filter (name: builtins.elem name graph.${name}) names;
  sorted = lib.toposort (a: b: builtins.elem a graph.${b}) names;
  cycles = selfReferences ++ (sorted.cycle or []);
  valid = missing == [] && cycles == [];
in {
  inherit missing cycles valid;
  # Invalid graphs are reported by module assertions. Keep rendering finite so
  # evaluation reaches those assertions instead of failing inside a traversal.
  closure = roots:
    if valid
    then
      map (node: node.key) (builtins.genericClosure {
        startSet = map (key: {inherit key;}) (builtins.filter (name: builtins.hasAttr name graph) roots);
        operator = node: map (key: {inherit key;}) graph.${node.key};
      })
    else [];
}
