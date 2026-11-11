.version = 3
| .bindings = [.bindings[]
    | select(((.condition.title // "") | startswith("gcp grant until "))
        and ((.condition.title | ltrimstr("gcp grant until ")) < $now) | not)]
  + [{role: $role, members: [$member], condition: {
      title: ("gcp grant until " + $until),
      expression: ("request.time < timestamp(\"" + $until + "\")")}}]
