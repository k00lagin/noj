# noj.c3 (not jinja)

Noj is a tool written in C3-language. It applies transformations to text-based templates. It aims to implement a small subset of Jinja's features.

## How to run it

Create a C3 program, import `noj` module, and call `noj::transform` function.

```C3
// examples.c3
import noj;

fn void main() {
    noj::transform("./templates/markdown.md.noj", "markdown.md");
    noj::transform("./templates/index.html.noj", "index.html");
}
```

```sh
c3c compile-run examples.c3 noj.c3
```

## Template's syntax

Noj currently supports only three types of tags:

* statements (`{% forach (index, person : persons) { %}`);

* expressions (`{{ person.fullName }}`)
* comments (`{# This will not be in the result text #}`).

Statements are used to control the flow: loops, conditions, etc., and to create helper variables or functions. Expressions are used to display data. Comments stay in your `.noj` template, and not affect result text.
