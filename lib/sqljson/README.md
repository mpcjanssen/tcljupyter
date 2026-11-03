# sqljson

A small Tcl package for reading and building JSON, implemented on top of the
JSON functions of SQLite (an in-memory database). It requires the `sqlite3`
package.

```tcl
package require sqljson
```

All commands are subcommands of the `sqljson` ensemble. Builders (`str`,
`num`, `bool`, `null`, `object`, `array`, `template`) return JSON text; they
never guess types, so you must say explicitly whether a value is a string, a
number, etc.

## Reading

### `sqljson decode json`

Converts JSON text to a Tcl value: objects become dicts, arrays become lists,
`true`/`false` become `true`/`false`, `null` becomes an empty string. An empty
input returns an empty string.

```tcl
sqljson decode {{"a":[1,2],"b":{"c":"x"}}}   ;# a {1 2} b {c x}
```

### `sqljson get json path`

Extracts the value at `path`. Scalars are returned as plain Tcl values; objects
and arrays are returned as JSON text.

The leading `$` is implicit: use `a.b[0]` or `[2]`, and an empty path for the
whole document. A path containing `[` must be braced in Tcl scripts.

```tcl
sqljson get $msg header.msg_type
sqljson get $list {[2]}
sqljson get $msg ""
```

## Modifying

### `sqljson jset varname path value`

Sets (creates or replaces) the value at `path` in the JSON text held in the
variable `varname`, using SQLite `json_set`, and returns the new JSON. A missing
or empty variable is treated as `{}`. `value` must already be valid JSON,
otherwise a `SQLJSON INVALID` error is raised. It is named `jset` so that it
does not collide with Tcl's `set`.

```tcl
set session {}
sqljson jset session user.name [sqljson str Ann]
sqljson jset session user.age  [sqljson num 42]
```

## Building values

| Command | Result |
|---------|--------|
| `sqljson str s` | JSON string, correctly escaped (always a string, even for `12`) |
| `sqljson num n` | JSON number; error `SQLJSON NUMBER` if `n` is not a valid JSON number |
| `sqljson bool b` | `true` or `false` from any Tcl boolean |
| `sqljson null` | `null` |
| `sqljson object ?key value ...?` | JSON object; each value must already be JSON text |
| `sqljson array ?value ...?` | JSON array; each element must already be JSON text |

```tcl
sqljson object name [sqljson str Ann] tags [sqljson array [sqljson str a] 1]
;# {"name":"Ann","tags":["a",1]}
```

Results are validated; invalid JSON raises a `SQLJSON INVALID` error.

## Templates

### `sqljson template text`

Writes JSON as plain text and fills in values from the caller's variables.
Every `{{~type:varname}}` is replaced by the JSON encoding of the variable
`varname` (looked up in the calling scope). The result is validated and
minified.

| Placeholder | Variable holds | Inserted as |
|-------------|----------------|-------------|
| `{{~str:v}}` | any text | JSON string |
| `{{~num:v}}` | a number | JSON number |
| `{{~bool:v}}` | a Tcl boolean | `true` / `false` |
| `{{~null}}` | (no variable) | `null` |
| `{{~object:v}}` | a dict whose values are JSON text | JSON object |
| `{{~array:v}}` | a list whose elements are JSON text | JSON array |
| `{{~json:v}}` | JSON text | inserted as is |

```tcl
set name Ann
set age 42
set tags [list [sqljson str a] [sqljson str b]]
sqljson template {
    {
        "name": {{~str:name}},
        "age": {{~num:age}},
        "tags": {{~array:tags}},
        "extra": {{~null}},
        "meta": {}
    }
}
;# {"name":"Ann","age":42,"tags":["a","b"],"extra":null,"meta":{}}
```

Notes:

- Compute expressions into variables before the call; only plain variable
  names are supported.
- Because the template is brace-quoted, an empty object is written `{}`; a
  doubled `{{}}` is not a placeholder.
- An unknown type or a missing variable name raises a `SQLJSON TEMPLATE` error.

## Errors

| `errorcode` | Cause |
|-------------|-------|
| `SQLJSON INVALID` | the resulting or supplied text is not valid JSON |
| `SQLJSON NUMBER` | `num` was given something that is not a JSON number |
| `SQLJSON TEMPLATE` | unknown template type, or a placeholder without a variable name |

## Gotchas

- SQLite turns Tcl integers into JSON numbers. For text fields that must stay
  strings (e.g. Jupyter notebook text), always use `str` / `{{~str:...}}`.
- `get` returns scalars unquoted; use `decode` when you need structure.
