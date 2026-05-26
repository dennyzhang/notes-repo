# fbcode Coding Conventions

Quick reference for coding conventions when completing diffs in fbcode.

## Python

### File Header

All new Python files must include:

```python
# (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
# pyre-strict
```

### Type Hints

Use modern syntax (PEP 604+):

```python
# Use | instead of Union/Optional
def get_user(user_id: int) -> User | None: ...

# Use built-in types instead of typing.List, typing.Dict
def process(items: list[str], mapping: dict[str, int]) -> tuple[str, ...]: ...

# Use none_throws() for Optional narrowing
from pyre_extensions import none_throws
value = none_throws(optional_dict)["key"]
```

### Imports

- Group: stdlib, third-party, Meta-internal
- Use absolute imports
- Remove unused imports (lint will catch)

## C++

- Use `folly::F14Map` instead of `std::unordered_map`
- Use `folly::Synchronized<T>` for lock-protected objects
- Use `fmt` for string formatting

```cpp
// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
```

## General Rules

- Follow line length limits enforced by `arc lint`
- Never edit files with `@generated` tag or in `third-party/`
- Every source file must be part of a Buck target — add new files to the appropriate `srcs` list
- Tests live at `$(dirname F)/test(s)/FTest.ext` for file `F.ext`
